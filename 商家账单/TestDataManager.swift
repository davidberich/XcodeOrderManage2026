// TestDataManager.swift

import Foundation

class TestDataManager {
    
    @MainActor
    static func generateTestData(for viewModel: OrderViewModel) {
        // 先清空现有数据，避免重复生成
        deleteAllData(for: viewModel)
        
        let sampleProductNames = ["经典款小白鞋", "复古德训鞋", "厚底老爹鞋", "帆布板鞋", "切尔西短靴", "乐福鞋"]
        let sampleColors = ["白色", "黑色", "米白", "燕麦色", "卡其色", "银色"]
        let sampleLeathers = ["牛皮", "羊皮", "帆布", "麂皮"]
        let allSizes = (35...42).map { "\($0)码" }
        
        let wholesaleCustomers = ["广州大客户", "深圳张小姐", "杭州批发商", "北京潮流店"]
        let retailCustomers = ["李女士", "王先生", "小红薯用户", "VIP客户-赵"]
        
        var generatedOrders: [Order] = []
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let endDate = Date.now
        
        for i in 0..<100 {
            let randomTimeInterval = TimeInterval.random(in: startDate.timeIntervalSince1970...endDate.timeIntervalSince1970)
            let randomDate = Date(timeIntervalSince1970: randomTimeInterval)
            let customerType: CustomerType = Bool.random() ? .wholesale : .retail
            let customerName = customerType == .wholesale ? wholesaleCustomers.randomElement()! : retailCustomers.randomElement()!
            var orderItems: [OrderItem] = []
            for _ in 0..<Int.random(in: 1...3) {
                var sizeQuantities: [String: Int] = [:]; for _ in 0..<Int.random(in: 2...5) { sizeQuantities[allSizes.randomElement()!] = Int.random(in: 1...5) }
                let item = OrderItem(productName: sampleProductNames.randomElement()! + "-\(Int.random(in: 100...999))", color: sampleColors.randomElement()!, leather: sampleLeathers.randomElement()!, sizeQuantities: sizeQuantities, unitPrice: Double(Int.random(in: 200...800)))
                orderItems.append(item)
            }
            
            // MARK: - 核心修复点: 移除重复的 'trademark' 参数
            let newOrder = Order(
                orderNumber: OrderNumberGenerator.shared.generateNewOrderNumber(for: randomDate, dailyCounter: i),
                customerName: customerName,
                date: randomDate,
                orderItems: orderItems,
                urgency: OrderUrgency.allCases.randomElement() ?? .normal,
                customerType: customerType,
                trademark: TrademarkOption.allCases.randomElement() ?? .none, // <-- 只保留这一行
                shipmentStatus: ShipmentStatus.allCases.randomElement() ?? .notShipped
            )
            generatedOrders.append(newOrder)
        }
        
        viewModel.orders.insert(contentsOf: generatedOrders, at: 0)
        viewModel.orders.sort { $0.date > $1.date }
        
        Task {
            await viewModel.saveOrders()
        }
    }
    
    @MainActor
    static func deleteAllData(for viewModel: OrderViewModel) {
        for order in viewModel.orders { for item in order.orderItems { ImageStore.shared.deleteImages(withIdentifiers: item.productImageIdentifiers) } }
        for order in viewModel.deletedOrders { for item in order.orderItems { ImageStore.shared.deleteImages(withIdentifiers: item.productImageIdentifiers) } }
        
        viewModel.orders.removeAll()
        viewModel.deletedOrders.removeAll()
        
        Task {
            await viewModel.saveOrders()
            await viewModel.saveDeletedOrders()
        }
    }
}
