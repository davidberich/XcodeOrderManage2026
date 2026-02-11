import Foundation
import SwiftUI

@MainActor
class OrderViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var deletedOrders: [Order] = []

    let ordersFileURL: URL
    let deletedOrdersFileURL: URL
    
    // 修改计算属性，只统计 active 状态的订单
    var totalRevenue: Double {
        orders.filter { $0.status ?? .active == .active }.reduce(0.0) { $0 + $1.totalOrderPrice }
    }
    
    var totalPaidAmount: Double {
        orders.filter { $0.status ?? .active == .active }.reduce(0.0) { $0 + $1.paidAmount }
    }
    
    var unconfirmedBalanceDue: Double {
        let balance = totalRevenue - totalPaidAmount
        return balance < 0.01 ? 0 : balance
    }

    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        ordersFileURL = documentsDirectory.appendingPathComponent("app_orders.json")
        deletedOrdersFileURL = documentsDirectory.appendingPathComponent("app_deleted_orders.json")
        migrateDataFromOldVersions(in: documentsDirectory)
        loadOrders()
        loadDeletedOrders()
    }
    
    private func migrateDataFromOldVersions(in directory: URL) {
        let oldOrdersFileURL = directory.appendingPathComponent("orders_v3.json")
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: ordersFileURL.path) && fileManager.fileExists(atPath: oldOrdersFileURL.path) {
            do {
                try fileManager.moveItem(at: oldOrdersFileURL, to: ordersFileURL)
                let oldDeletedOrdersURL = directory.appendingPathComponent("deletedOrders_v3.json")
                if fileManager.fileExists(atPath: oldDeletedOrdersURL.path) {
                    try fileManager.moveItem(at: oldDeletedOrdersURL, to: deletedOrdersFileURL)
                }
            } catch {
                print("Error migrating data: \(error)")
            }
        }
    }

    func mergeImportedOrders(_ ordersToImport: [Order]) -> (importedCount: Int, skippedCount: Int) {
        let existingOrderIDs = Set(self.orders.map { $0.id })
        var newOrders: [Order] = []
        var skippedCount = 0
        
        for order in ordersToImport {
            if !existingOrderIDs.contains(order.id) {
                newOrders.append(order)
            } else {
                skippedCount += 1
            }
        }
        
        if !newOrders.isEmpty {
            self.orders.append(contentsOf: newOrders)
            self.orders.sort { $0.date > $1.date }
            Task { await self.saveOrders() }
        }
        
        return (newOrders.count, skippedCount)
    }
    
    // 实现订单状态更新方法
    func updateOrderStatus(for orderId: UUID, to newStatus: OrderStatus) {
        if let index = orders.firstIndex(where: { $0.id == orderId }) {
            orders[index].status = newStatus
            Task { await saveOrders() }
        }
    }
    
    @discardableResult
    func addOrder(_ order: Order) -> Order {
        var newOrder = order
        newOrder.orderNumber = OrderNumberGenerator.shared.generateNewOrderNumber(for: newOrder.date)
        
        orders.insert(newOrder, at: 0)
        Task { await saveOrders() }
        
        return newOrder
    }

    func updateOrder(_ updatedOrder: Order) {
        if let index = orders.firstIndex(where: { $0.id == updatedOrder.id }) {
            orders[index] = updatedOrder
            Task { await saveOrders() }
        }
    }

    func moveOrdersToTrash(ids: Set<UUID>) {
        let ordersToMove = orders.filter { ids.contains($0.id) }
        deletedOrders.insert(contentsOf: ordersToMove, at: 0)
        orders.removeAll { ids.contains($0.id) }
        Task {
            await saveOrders()
            await saveDeletedOrders()
        }
    }
    
    func moveOrderToTrash(id: UUID) {
        moveOrdersToTrash(ids: [id])
    }

    func restoreOrdersFromTrash(ids: Set<UUID>) {
        let ordersToRestore = deletedOrders.filter { ids.contains($0.id) }
        orders.insert(contentsOf: ordersToRestore, at: 0)
        orders.sort { $0.date > $1.date }
        deletedOrders.removeAll { ids.contains($0.id) }
        Task {
            await saveOrders()
            await saveDeletedOrders()
        }
    }

    func permanentlyDeleteOrdersFromTrash(ids: Set<UUID>) {
        let ordersToDelete = deletedOrders.filter { ids.contains($0.id) }
        for order in ordersToDelete {
            for item in order.orderItems {
                ImageStore.shared.deleteImages(withIdentifiers: item.productImageIdentifiers)
            }
        }
        deletedOrders.removeAll { ids.contains($0.id) }
        Task { await saveDeletedOrders() }
    }
    
    func removeOrdersPermanently(ids: Set<UUID>) {
        let ordersToRemove = orders.filter { ids.contains($0.id) }
        for order in ordersToRemove {
            for item in order.orderItems {
                ImageStore.shared.deleteImages(withIdentifiers: item.productImageIdentifiers)
            }
        }
        orders.removeAll { ids.contains($0.id) }
        Task { await saveOrders() }
    }
    
    // 确保加载时为旧数据设置默认状态
    func loadOrders() {
        do {
            let data = try Data(contentsOf: ordersFileURL)
            let decoder = JSONDecoder()
            var loadedOrders = try decoder.decode([Order].self, from: data)
            // 为没有 status 字段的旧数据设置默认值
            for i in 0..<loadedOrders.count {
                if loadedOrders[i].status == nil {
                    loadedOrders[i].status = .active
                }
            }
            orders = loadedOrders.sorted(by: { $0.date > $1.date })
        } catch {
            print("Could not load active orders: \(error)")
        }
    }

    func saveOrders() async {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(orders)
            try data.write(to: ordersFileURL, options: .atomic)
        } catch {
            print("Could not save active orders: \(error)")
        }
    }
    
    func loadDeletedOrders() {
        do {
            let data = try Data(contentsOf: deletedOrdersFileURL)
            let decoder = JSONDecoder()
            deletedOrders = try decoder.decode([Order].self, from: data)
        } catch {
            print("Could not load deleted orders: \(error)")
        }
    }

    func saveDeletedOrders() async {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(deletedOrders)
            try data.write(to: deletedOrdersFileURL, options: .atomic)
        } catch {
            print("Could not save deleted orders: \(error)")
        }
    }
}
