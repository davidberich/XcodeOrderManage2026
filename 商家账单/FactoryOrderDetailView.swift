// FactoryOrderDetailView.swift

import SwiftUI
import PhotosUI

struct FactoryOrderDetailView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    let order: Order
    @Binding var item: OrderItem
    
    @State private var textContent: String
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    @State private var imageIdToDelete: String?
    @State private var showingDeleteConfirm = false
    
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @FocusState private var isTextEditorFocused: Bool
    
    init(order: Order, item: Binding<OrderItem>) {
        self.order = order
        self._item = item
        _textContent = State(initialValue: item.wrappedValue.factoryOrderText ?? Self.generateInitialText(for: order, item: item.wrappedValue))
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    imageStackSection
                    Divider()
                    TextEditor(text: $textContent)
                        .padding()
                        .font(.body)
                        .focused($isTextEditorFocused)
                        .frame(minHeight: 250)
                }
            }
            if isLoading {
                ProgressView("正在生成图片...")
                    .padding(25)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
                    .shadow(radius: 10)
            }
        }
        .navigationTitle("工厂订单详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(alignment: .center, spacing: 12) {
                    Button(action: generateAndSaveImage) { Image(systemName: "square.and.arrow.down") }
                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) { Image(systemName: "plus") }
                }
                .font(.headline)
                .foregroundColor(.accentColor)
            }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { isTextEditorFocused = false } }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in Task { await loadImages(from: newItems) } }
        .alert("确认删除", isPresented: $showingDeleteConfirm, presenting: imageIdToDelete) { id in
            Button("删除", role: .destructive) { deleteImage(imageId: id) }
        } message: { _ in Text("你确定要删除这张图片吗？此操作无法撤销。") }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("好的", role: .cancel) {}
        } message: { Text(alertMessage) }
        .onDisappear(perform: saveChanges)
    }
    
    @ViewBuilder
    private var imageStackSection: some View {
        VStack(spacing: 4) {
            if item.productImageIdentifiers.isEmpty {
                ZStack {
                    Rectangle().fill(Color(.systemGray6)).frame(height: 200)
                    Text("暂无图片，请点击右上角添加").foregroundColor(.secondary)
                }
            } else {
                ForEach(item.productImageIdentifiers, id: \.self) { imageId in
                    if let uiImage = ImageStore.shared.loadImage(withIdentifier: imageId) {
                        Image(uiImage: uiImage).resizable().scaledToFit()
                            .contextMenu {
                                Button(role: .destructive) {
                                    self.imageIdToDelete = imageId
                                    self.showingDeleteConfirm = true
                                } label: { Label("删除图片", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }
    
    private func generateAndSaveImage() {
        saveChanges()
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let imagesToProcess = self.item.productImageIdentifiers.compactMap { ImageStore.shared.loadImage(withIdentifier: $0) }
            let textToProcess = self.textContent
            
            guard let finalImage = OrderImageGenerator.shared.generate(for: self.order, productImages: imagesToProcess, textContent: textToProcess) else {
                DispatchQueue.main.async {
                    self.isLoading = false; self.alertTitle = "生成失败"; self.alertMessage = "无法创建订单图片。"; self.showAlert = true
                }
                return
            }
            ImageStore.shared.saveToPhotoLibrary(finalImage) { success, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if success { self.alertTitle = "保存成功"; self.alertMessage = "订单图片已保存到您的相册。" }
                    else { self.alertTitle = "保存失败"; self.alertMessage = "无法保存图片，请检查App的相册访问权限。" }
                    self.showAlert = true
                }
            }
        }
    }

    private func saveChanges() {
        if item.factoryOrderText != textContent {
            item.factoryOrderText = textContent
            viewModel.updateOrder(order)
        }
    }
    
    private func deleteImage(imageId: String) {
        if let index = item.productImageIdentifiers.firstIndex(of: imageId) {
            item.productImageIdentifiers.remove(at: index)
            ImageStore.shared.deleteImage(withIdentifier: imageId)
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data), let newId = ImageStore.shared.saveImage(uiImage) {
                await MainActor.run {
                    self.item.productImageIdentifiers.append(newId)
                }
            }
        }
        await MainActor.run {
            selectedPhotoItems.removeAll()
        }
    }

    // <--- 核心修改点
    static func generateInitialText(for order: Order, item: OrderItem) -> String {
        var lines: [String] = [
            "订单编号: \(order.orderNumber)",
            "客户名称: \(order.customerName)"
        ]
        
        if order.trademark == .guestLabel {
            lines.append("客人标")
        }
        
        lines.append(contentsOf: [
            "产品编号: \(item.productName)",
            "颜色: \(item.color)",
            "码数+数量: \(item.sizeQuantities.sorted { $0.key < $1.key }.map { "\($0.key.replacingOccurrences(of: "码", with: ""))x\($0.value)" }.joined(separator: ", "))"
        ])
        
        if order.urgency == .urgent {
            lines.append("订单加急！")
        }
        
        lines.append("\n\(order.date.formattedAsYMD())")
        
        return lines.joined(separator: "\n")
    }
}
