// AddOrderItemView.swift

import SwiftUI
import PhotosUI

// 这是一个独立的编辑/添加弹窗，用于在订单详情页修改数据
struct AddOrderItemView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var item: OrderItem
    var onSave: (OrderItem) -> Void

    // 本地状态
    @State private var existingImageIdentifiers: [String]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var newlyLoadedImages: [IdentifiableUIImage] = []
    @State private var imageToPreview: UIImage?
    @State private var isPreviewingImage = false
    
    enum FocusableField: Hashable {
        case productName, color, leather, quantity(String)
    }
    @FocusState private var focusedField: FocusableField?

    private let allSizes = (33...42).map { "\($0)码" }
    private let columns = [GridItem(.adaptive(minimum: 70))]
    private let imageGridColumns = [GridItem(.adaptive(minimum: 100))]
    
    private var isFormValid: Bool {
        !item.productName.isEmpty && !item.color.isEmpty && !item.leather.isEmpty &&
        !item.sizeQuantities.filter { $0.value > 0 }.isEmpty
    }

    init(item: Binding<OrderItem>, onSave: @escaping (OrderItem) -> Void) {
        self._item = item
        self.onSave = onSave
        _existingImageIdentifiers = State(initialValue: item.wrappedValue.productImageIdentifiers)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("商品规格")) {
                    TextField("商品名称*", text: $item.productName).focused($focusedField, equals: .productName)
                    TextField("颜色*", text: $item.color).focused($focusedField, equals: .color)
                    TextField("皮料*", text: $item.leather).focused($focusedField, equals: .leather)
                }

                Section(header: Text("选择尺码")) {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(allSizes, id: \.self) { size in
                            Button(action: { toggleSizeSelection(size) }) {
                                Text(size).font(.headline)
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 50)
                                    .background(item.sizeQuantities[size, default: 0] > 0 ? Color.accentColor : Color.gray.opacity(0.2))
                                    .foregroundColor(item.sizeQuantities[size, default: 0] > 0 ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }.buttonStyle(.plain)
                }
                
                if !item.sizeQuantities.filter({$0.value > 0}).isEmpty {
                    Section(header: Text("数量调整")) {
                        ForEach(item.sizeQuantities.keys.sorted(), id: \.self) { size in
                             HStack {
                                Text("\(size):")
                                TextField("", text: quantityBinding(for: size))
                                    .keyboardType(.numberPad)
                                    .focused($focusedField, equals: .quantity(size))
                                    .frame(width: 50)
                                    .foregroundColor(.accentColor)
                                Spacer()
                                Stepper("", value: stepperBinding(for: size), in: 0...999)
                            }
                        }
                    }
                }
                
                Section(header: imageSectionHeader()) {
                    LazyVGrid(columns: imageGridColumns, spacing: 10) {
                        ForEach(existingImageIdentifiers, id: \.self) { id in
                            if let uiImage = ImageStore.shared.loadImage(withIdentifier: id) {
                                imageThumbnailView(image: uiImage, onDelete: { deleteExistingImage(identifier: id) })
                            }
                        }
                        ForEach(newlyLoadedImages) { wrapped in
                            imageThumbnailView(image: wrapped.image, onDelete: { newlyLoadedImages.removeAll(where: { $0.id == wrapped.id }) })
                        }
                    }.padding(.vertical, 5)
                }
            }
            .navigationTitle("编辑商品")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("保存", action: saveAndDismiss).disabled(!isFormValid) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { focusedField = nil } }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in Task { await loadNewImages(from: newItems) } }
            .sheet(isPresented: $isPreviewingImage) { if let img = imageToPreview { FullScreenImageViewer(image: img) {} } }
        }
    }
    
    @ViewBuilder
    private func imageThumbnailView(image: UIImage, onDelete: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable().scaledToFill().frame(width: 100, height: 100)
                .cornerRadius(8).onTapGesture { self.imageToPreview = image; self.isPreviewingImage = true }
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.white, .red)
            }.buttonStyle(.plain).offset(x: 8, y: -8)
        }.frame(width: 100, height: 100)
    }
    
    private func imageSectionHeader() -> some View {
        HStack {
            Text("商品图片"); Spacer()
            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) {
                Label("添加图片", systemImage: "plus.circle.fill")
            }
        }
    }

    private func saveAndDismiss() {
        item.unitPrice = 0.0
        item.sizeQuantities = item.sizeQuantities.filter { $0.value > 0 }
        let newIdentifiers = newlyLoadedImages.compactMap { ImageStore.shared.saveImage($0.image) }
        let idsToDelete = Set(item.productImageIdentifiers).subtracting(existingImageIdentifiers)
        ImageStore.shared.deleteImages(withIdentifiers: Array(idsToDelete))
        item.productImageIdentifiers = self.existingImageIdentifiers + newIdentifiers
        onSave(item)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func deleteExistingImage(identifier: String) { existingImageIdentifiers.removeAll { $0 == identifier } }
    private func loadNewImages(from items: [PhotosPickerItem]) async {
        var loaded: [IdentifiableUIImage] = []
        for item in items { if let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) { loaded.append(IdentifiableUIImage(image: uiImage)) } }
        await MainActor.run { self.newlyLoadedImages.append(contentsOf: loaded); self.selectedPhotoItems.removeAll() }
    }
    private func toggleSizeSelection(_ size: String) { if item.sizeQuantities[size] != nil { item.sizeQuantities[size] = nil } else { item.sizeQuantities[size] = 1 } }
    private func quantityBinding(for size: String) -> Binding<String> { Binding<String>(get: { let q = self.item.sizeQuantities[size, default: 0]; return q > 0 ? String(q) : "" }, set: { str in if str.isEmpty { self.item.sizeQuantities[size] = 0 } else if let val = Int(str) { self.item.sizeQuantities[size] = val } }) }
    private func stepperBinding(for size: String) -> Binding<Int> { Binding<Int>(get: { self.item.sizeQuantities[size, default: 0] }, set: { val in if val <= 0 { self.item.sizeQuantities[size] = nil } else { self.item.sizeQuantities[size] = val } }) }
}
