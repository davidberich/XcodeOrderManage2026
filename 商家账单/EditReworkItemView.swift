// EditReworkItemView.swift

import SwiftUI
import PhotosUI

struct EditReworkItemView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // 核心修改 1: 从 @Binding 改为 @State。
    // 这意味着此视图现在自己管理“返工项”的数据，而不是依赖外部。
    @State private var reworkItem: ReworkItem
    
    // 核心修改 2: 统一的回调闭包。
    // 无论是创建还是编辑，保存时都会调用这个闭包。
    var onSave: (ReworkItem) -> Void

    // 本地状态（保持不变）
    @State private var newlyLoadedImages: [IdentifiableUIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var imageToPreview: UIImage?
    @State private var isPreviewingImage = false

    @FocusState private var focusedField: FocusableField?
    enum FocusableField: Hashable {
        case productName, color, leather, otherReason, quantity(String)
    }
    
    private let allSizes = (33...42).map { "\($0)码" }
    private let columns = [GridItem(.adaptive(minimum: 70))]
    private let imageGridColumns = [GridItem(.adaptive(minimum: 100))]

    private var isFormValid: Bool {
        !reworkItem.reasons.isEmpty &&
        (!reworkItem.reasons.contains(.other) || (reworkItem.reasons.contains(.other) && !(reworkItem.otherReasonDetail?.isEmpty ?? true))) &&
        !reworkItem.reworkedItem.productName.isEmpty &&
        !reworkItem.reworkedItem.sizeQuantities.filter({ $0.value > 0 }).isEmpty
    }
    
    // MARK: - Initializers
    
    // 核心修改 3: 新的、用于“创建”的初始化方法
    init(originalItem: OrderItem, onSave: @escaping (ReworkItem) -> Void) {
        let newItem = ReworkItem(date: .now, originalOrderItemID: originalItem.id, reasons: [], otherReasonDetail: nil, reworkedItem: originalItem)
        // 初始化内部的 @State 变量
        _reworkItem = State(initialValue: newItem)
        self.onSave = onSave
    }
    
    // 核心修改 4: 新的、用于“编辑”的初始化方法
    init(reworkItemToEdit: ReworkItem, onSave: @escaping (ReworkItem) -> Void) {
        // 初始化内部的 @State 变量
        _reworkItem = State(initialValue: reworkItemToEdit)
        self.onSave = onSave
    }

    // MARK: - Body
    // Body部分的代码不需要改变，因为它现在会绑定到内部的 @State reworkItem
    var body: some View {
        NavigationView {
            Form {
                reworkInfoSection
                reworkReasonSection
                productSpecSection
                sizeSelectionSection
                if !reworkItem.reworkedItem.sizeQuantities.filter({$0.value > 0}).isEmpty {
                    sizeQuantitySection
                }
                imageManagementSection
            }
            .navigationTitle("编辑重做订单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { mainToolbar }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in Task { await loadNewImages(from: newItems) } }
        .sheet(isPresented: $isPreviewingImage) {
            if let image = imageToPreview { FullScreenImageViewer(image: image) {} }
        }
    }
    
    // MARK: - 辅助视图 (无需修改)
    
    private var reworkInfoSection: some View {
        Section(header: Text("重做信息").font(.headline)) {
            DatePicker("重做日期", selection: $reworkItem.date, displayedComponents: .date)
        }
    }
    
    private var reworkReasonSection: some View {
        Section(header: Text("重做原因*").font(.headline)) {
            ForEach(ReworkReason.allCases) { reason in
                Button(action: { toggleReasonSelection(reason) }) {
                    HStack {
                        Text(reason.displayTitle).foregroundColor(.primary)
                        Spacer()
                        if reworkItem.reasons.contains(reason) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                        } else {
                            Image(systemName: "circle").foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            if reworkItem.reasons.contains(.other) {
                TextField("请填写其他原因", text: $reworkItem.otherReasonDetail.toNonOptional())
                    .focused($focusedField, equals: .otherReason)
            }
        }
    }
    
    private var productSpecSection: some View {
        Section(header: Text("商品规格*").font(.headline)) {
            TextField("商品名称", text: $reworkItem.reworkedItem.productName).focused($focusedField, equals: .productName)
            TextField("颜色", text: $reworkItem.reworkedItem.color).focused($focusedField, equals: .color)
            TextField("皮料", text: $reworkItem.reworkedItem.leather).focused($focusedField, equals: .leather)
        }
    }
    
    private var sizeSelectionSection: some View {
        Section(header: Text("选择尺码*").font(.headline)) {
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(allSizes, id: \.self) { size in
                    Button(action: { toggleSizeSelection(size) }) {
                        Text(size).font(.headline)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 50)
                            .background(reworkItem.reworkedItem.sizeQuantities[size, default: 0] > 0 ? Color.accentColor : Color.gray.opacity(0.2))
                            .foregroundColor(reworkItem.reworkedItem.sizeQuantities[size, default: 0] > 0 ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }.buttonStyle(.plain)
        }
    }
    
    private var sizeQuantitySection: some View {
        Section(header: Text("已选尺码和数量").font(.headline)) {
            ForEach(reworkItem.reworkedItem.sizeQuantities.keys.sorted(), id: \.self) { size in
                 HStack {
                    Text("\(size) 数量:")
                    TextField("", text: quantityBinding(for: size))
                        .keyboardType(.numberPad).focused($focusedField, equals: .quantity(size))
                        .frame(width: 50).foregroundColor(.accentColor).fontWeight(.medium)
                    Spacer()
                    Stepper("", value: stepperBinding(for: size), in: 0...999)
                }
            }
        }
    }
    
    private var imageManagementSection: some View {
        Section(header: imageSectionHeader()) {
            if reworkItem.reworkedItem.productImageIdentifiers.isEmpty && newlyLoadedImages.isEmpty {
                 imagePlaceholderView()
            } else {
                LazyVGrid(columns: imageGridColumns, spacing: 10) {
                    ForEach(reworkItem.reworkedItem.productImageIdentifiers, id: \.self) { identifier in
                        if let uiImage = ImageStore.shared.loadImage(withIdentifier: identifier) {
                            imageThumbnailView(displayImage: uiImage, onTapAction: { showPreview(for: uiImage) }, onDeleteAction: { deleteExistingImage(identifier: identifier) })
                        }
                    }
                    ForEach(newlyLoadedImages) { wrappedImage in
                        imageThumbnailView(displayImage: wrappedImage.image, onTapAction: { showPreview(for: wrappedImage.image) }, onDeleteAction: { newlyLoadedImages.removeAll(where: { $0.id == wrappedImage.id }) })
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) { Button("取消") { presentationMode.wrappedValue.dismiss() } }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("保存") { saveReworkItem() }.disabled(!isFormValid)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("完成") { focusedField = nil }
        }
    }
    
    private func imageSectionHeader() -> some View {
        HStack {
            Text("商品图片").font(.headline)
            Spacer()
            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                Label("添加图片", systemImage: "plus.circle.fill")
            }.buttonStyle(.borderless)
        }
    }
    
    @ViewBuilder private func imagePlaceholderView() -> some View {
        PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 50))
                Text("添加商品图片").font(.headline)
            }
            .foregroundColor(.secondary).frame(maxWidth: .infinity).frame(height: 150)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 12).stroke(style: StrokeStyle(lineWidth: 2, dash: [8])).foregroundColor(Color.gray.opacity(0.5))
            )
        }.buttonStyle(.plain)
    }
    
    @ViewBuilder private func imageThumbnailView(displayImage: UIImage, onTapAction: @escaping () -> Void, onDeleteAction: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: displayImage)
                .resizable().scaledToFill().frame(width: 100, height: 100).cornerRadius(8)
                .onTapGesture(perform: onTapAction).shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            Button(action: onDeleteAction) {
                Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red).shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }.buttonStyle(.plain).offset(x: 8, y: -8)
        }.frame(width: 100, height: 100)
    }
    
    // MARK: - Logic Functions
    
    private func saveReworkItem() {
        let newIdentifiers = newlyLoadedImages.compactMap { ImageStore.shared.saveImage($0.image) }
        reworkItem.reworkedItem.productImageIdentifiers.append(contentsOf: newIdentifiers)
        
        if !reworkItem.reasons.contains(.other) {
            reworkItem.otherReasonDetail = nil
        }
        
        // 核心修改 5: 无论创建还是编辑，都调用统一的 onSave 闭包
        onSave(reworkItem)
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func toggleReasonSelection(_ reason: ReworkReason) {
        if reworkItem.reasons.contains(reason) {
            reworkItem.reasons.remove(reason)
        } else {
            reworkItem.reasons.insert(reason)
        }
    }
    
    private func toggleSizeSelection(_ size: String) {
        if reworkItem.reworkedItem.sizeQuantities[size] != nil {
            reworkItem.reworkedItem.sizeQuantities[size] = nil
        } else {
            reworkItem.reworkedItem.sizeQuantities[size] = 1
        }
    }
    
    private func quantityBinding(for size: String) -> Binding<String> {
        Binding<String>(
            get: {
                let quantity = self.reworkItem.reworkedItem.sizeQuantities[size, default: 0]
                return quantity > 0 ? String(quantity) : ""
            },
            set: { newStringValue in
                if newStringValue.isEmpty { self.reworkItem.reworkedItem.sizeQuantities[size] = 0 }
                else if let newIntValue = Int(newStringValue) { self.reworkItem.reworkedItem.sizeQuantities[size] = newIntValue }
            }
        )
    }
    
    private func stepperBinding(for size: String) -> Binding<Int> {
        Binding<Int>(
            get: { self.reworkItem.reworkedItem.sizeQuantities[size, default: 0] },
            set: { newValue in
                if newValue <= 0 { self.reworkItem.reworkedItem.sizeQuantities[size] = nil }
                else { self.reworkItem.reworkedItem.sizeQuantities[size] = newValue }
            }
        )
    }
    
    private func loadNewImages(from items: [PhotosPickerItem]) async {
        var loaded: [IdentifiableUIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                loaded.append(IdentifiableUIImage(image: uiImage))
            }
        }
        await MainActor.run {
            self.newlyLoadedImages.append(contentsOf: loaded)
            self.selectedPhotoItems.removeAll()
        }
    }
    
    private func deleteExistingImage(identifier: String) {
        reworkItem.reworkedItem.productImageIdentifiers.removeAll { $0 == identifier }
    }
    
    private func showPreview(for image: UIImage) {
        self.imageToPreview = image
        self.isPreviewingImage = true
    }
}
