// NewOrderViewModel.swift

import SwiftUI
import PhotosUI

struct IdentifiableUIImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

@MainActor
class NewOrderViewModel: ObservableObject {
    // 记录当前正在编辑的订单ID
    @Published var currentOrderID: UUID? = nil
    
    // MARK: - 客户信息
    @Published var customerName: String = ""
    @Published var urgency: OrderUrgency = .normal
    @Published var trademark: TrademarkOption = .none
    
    // MARK: - 商品信息
    @Published var productName: String = ""
    @Published var color: String = "" // 代表 "颜色和皮料"
    @Published var sizeQuantities: [String: Int] = [:]
    
    // MARK: - 新增：价格信息 (使用字符串方便输入)
    @Published var unitPrice: String = ""
    
    // MARK: - 图片处理
    @Published var selectedPhotoItems: [PhotosPickerItem] = []
    @Published var loadedImages: [IdentifiableUIImage] = []
    
    var totalQuantity: Int {
        sizeQuantities.values.reduce(0, +)
    }
    
    // 计算总金额 (用于显示)
    var calculatedTotalPrice: Double {
        let price = Double(unitPrice) ?? 0.0
        return price * Double(totalQuantity)
    }
    
    // MARK: - 逻辑方法
    
    func toggleSizeSelection(_ size: String) {
        if sizeQuantities[size] != nil {
            sizeQuantities[size] = nil
        } else {
            sizeQuantities[size] = 1
        }
    }
    
    func updateQuantity(for size: String, value: Int) {
        if value <= 0 {
            sizeQuantities[size] = nil
        } else {
            sizeQuantities[size] = value
        }
    }
    
    // 图片加载
    func loadImages(from items: [PhotosPickerItem]) async {
        var newImages: [IdentifiableUIImage] = []
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    newImages.append(IdentifiableUIImage(image: uiImage))
                }
            } catch {
                print("加载图片出错: \(error)")
            }
        }
        await MainActor.run {
            self.loadedImages.append(contentsOf: newImages)
            self.selectedPhotoItems = []
        }
    }
    
    func deleteImage(id: UUID) {
        loadedImages.removeAll { $0.id == id }
    }

    // MARK: - 自动保存逻辑
    func autoSave(in mainViewModel: OrderViewModel) {
        let safeCustomerName = customerName.isEmpty ? "新订单" : customerName
        let imageIdentifiers = loadedImages.compactMap { ImageStore.shared.saveImage($0.image) }
        
        // 解析价格
        let priceValue = Double(unitPrice) ?? 0.0
        
        let newItem = OrderItem(
            productName: productName,
            color: color,
            leather: "",
            sizeQuantities: sizeQuantities,
            unitPrice: priceValue, // 保存价格
            productImageIdentifiers: imageIdentifiers,
            productType: .custom
        )
        
        if let existingID = currentOrderID {
            if let index = mainViewModel.orders.firstIndex(where: { $0.id == existingID }) {
                var orderToUpdate = mainViewModel.orders[index]
                orderToUpdate.customerName = safeCustomerName
                orderToUpdate.urgency = urgency
                orderToUpdate.trademark = trademark
                orderToUpdate.orderItems = [newItem]
                orderToUpdate.date = Date()
                mainViewModel.updateOrder(orderToUpdate)
            }
        } else {
            let newOrder = Order(
                orderNumber: "",
                customerName: safeCustomerName,
                date: Date(),
                orderItems: [newItem],
                urgency: urgency,
                customerType: .retail,
                trademark: trademark,
                shipmentStatus: .notShipped
            )
            let savedOrder = mainViewModel.addOrder(newOrder)
            self.currentOrderID = savedOrder.id
        }
    }
    
    func deleteCurrentOrder(in mainViewModel: OrderViewModel) {
        if let id = currentOrderID {
            mainViewModel.removeOrdersPermanently(ids: [id])
        }
        loadedImages.removeAll()
    }
}
