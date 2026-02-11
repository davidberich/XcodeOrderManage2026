// OrderModels.swift

import Foundation
import SwiftUI

// 新增: 物流状态枚举
enum ShipmentStatus: String, Codable, CaseIterable, Identifiable {
    case notShipped = "未寄出"
    case shipped = "已寄出"
    
    var id: Self { self }
    var displayTitle: String { self.rawValue }
}

// 新增: 商标选项
enum TrademarkOption: String, Codable, CaseIterable, Identifiable {
    case none = "无"
    case guestLabel = "客人标"
    
    var id: Self { self }
    var displayTitle: String { self.rawValue }
}

enum OrderUrgency: String, Codable, CaseIterable, Identifiable {
    case normal = "正常"
    case urgent = "加急"
    
    var id: Self { self }
    var displayTitle: String { self.rawValue }
}

enum ReworkReason: String, Codable, CaseIterable, Hashable, Identifiable {
    case wrongColor = "颜色错误", wrongSize = "尺码错误", wrongModel = "型号错误", wrongLeather = "皮料错误", qualityIssue = "质量问题", orderError = "订单填错", other = "其他"
    var id: Self { self }
    var displayTitle: String { self.rawValue }
}

struct ReworkItem: Identifiable, Codable, Hashable {
    // MARK: - 修复点 1: 将 let 改为 var
    var id = UUID(); var date: Date; var originalOrderItemID: UUID; var reasons: Set<ReworkReason>; var otherReasonDetail: String?; var reworkedItem: OrderItem
}

enum OrderStatus: String, Codable, CaseIterable {
    case active = "正常", refunded = "退货退款"
}

enum CustomerType: String, CaseIterable, Codable, Identifiable {
    case retail = "零售", wholesale = "批发"
    var id: Self { self }; var displayTitle: String { self.rawValue }
}

enum PaymentMethod: String, CaseIterable, Codable, Identifiable {
    case bankTransfer = "银行转账", wechat = "微信", alipay = "支付宝", cash = "现金", other = "其他"
    var id: Self { self }; var displayTitle: String { self.rawValue }
}

enum PaymentStatus: String, Codable {
    case pendingPrice = "单价待定", unpaid = "未收款", partial = "部分收款", paid = "已结清"
    var color: Color {
        switch self {
        case .pendingPrice, .unpaid: return .red
        case .partial: return .orange
        case .paid: return .green
        }
    }
}

struct Payment: Codable, Hashable, Identifiable, Equatable {
    // MARK: - 修复点 2: 将 let 改为 var
    var id = UUID(); var date: Date = Date(); var amount: Double = 0.0; var method: PaymentMethod = .other; var notes: String?
}

enum ProductType: String, Codable, CaseIterable, Identifiable {
    case custom = "定制", stock = "现货"
    var id: String { self.rawValue }
}

struct OrderItem: Codable, Identifiable, Hashable {
    var id = UUID(); var productName: String = ""; var color: String = ""; var leather: String = ""; var sizeQuantities: [String: Int] = [:]; var unitPrice: Double = 0.0; var productImageIdentifiers: [String] = []; var factoryOrderText: String?; var productType: ProductType?
    var totalItemQuantity: Int { sizeQuantities.values.reduce(0, +) }
    var totalItemPrice: Double { Double(totalItemQuantity) * unitPrice }
    init(id: UUID = UUID(), productName: String = "", color: String = "", leather: String = "", sizeQuantities: [String : Int] = [:], unitPrice: Double = 0.0, productImageIdentifiers: [String] = [], factoryOrderText: String? = nil, productType: ProductType? = .custom) {
        self.id = id; self.productName = productName; self.color = color; self.leather = leather; self.sizeQuantities = sizeQuantities; self.unitPrice = unitPrice; self.productImageIdentifiers = productImageIdentifiers; self.factoryOrderText = factoryOrderText; self.productType = productType
    }
}

struct Order: Codable, Identifiable, Hashable {
    var id = UUID()
    var orderNumber: String
    var customerName: String
    var date: Date
    var orderItems: [OrderItem]
    var urgency: OrderUrgency
    var customerType: CustomerType
    var trademark: TrademarkOption
    var shipmentStatus: ShipmentStatus
    var payments: [Payment] = []
    var status: OrderStatus? = .active
    var reworkItems: [ReworkItem] = []
    
    // 计算属性 (无变化)
    var totalOrderQuantity: Int { orderItems.reduce(0) { $0 + $1.totalItemQuantity } }
    var totalOrderPrice: Double { orderItems.reduce(0.0) { $0 + $1.totalItemPrice } }
    var paidAmount: Double { payments.reduce(0) { $0 + $1.amount } }
    var balanceDue: Double { let balance = totalOrderPrice - paidAmount; return balance < 0.001 ? 0 : balance }
    var paymentStatus: PaymentStatus { if hasPendingPrice { return .pendingPrice }; if paidAmount <= 0 { return .unpaid } else if balanceDue <= 0 { return .paid } else { return .partial } }
    var hasPendingPrice: Bool { orderItems.contains { $0.unitPrice <= 0 } }
    var previewImageIdentifiers: [String] { Array(orderItems.flatMap { $0.productImageIdentifiers }.prefix(4)) }
    static func == (lhs: Order, rhs: Order) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    enum CodingKeys: String, CodingKey {
        case id, orderNumber, customerName, date, orderItems, urgency, customerType, trademark, shipmentStatus, payments, status, reworkItems
        case trackingNumber // 保留旧key用于解码
    }
    
    // 构造函数
    init(id: UUID = UUID(), orderNumber: String, customerName: String, date: Date, orderItems: [OrderItem], urgency: OrderUrgency, customerType: CustomerType, trademark: TrademarkOption, shipmentStatus: ShipmentStatus, payments: [Payment] = [], status: OrderStatus? = .active, reworkItems: [ReworkItem] = []) {
        self.id = id; self.orderNumber = orderNumber; self.customerName = customerName; self.date = date; self.orderItems = orderItems; self.urgency = urgency; self.customerType = customerType; self.trademark = trademark; self.shipmentStatus = shipmentStatus; self.payments = payments; self.status = status; self.reworkItems = reworkItems
    }

    // 自定义解码器
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        orderNumber = try container.decode(String.self, forKey: .orderNumber)
        customerName = try container.decode(String.self, forKey: .customerName)
        date = try container.decode(Date.self, forKey: .date)
        orderItems = try container.decode([OrderItem].self, forKey: .orderItems)
        urgency = try container.decodeIfPresent(OrderUrgency.self, forKey: .urgency) ?? .normal
        customerType = try container.decodeIfPresent(CustomerType.self, forKey: .customerType) ?? .retail
        trademark = try container.decodeIfPresent(TrademarkOption.self, forKey: .trademark) ?? .none
        payments = try container.decodeIfPresent([Payment].self, forKey: .payments) ?? []
        status = try container.decodeIfPresent(OrderStatus.self, forKey: .status) ?? .active
        reworkItems = try container.decodeIfPresent([ReworkItem].self, forKey: .reworkItems) ?? []
        
        if let newStatus = try container.decodeIfPresent(ShipmentStatus.self, forKey: .shipmentStatus) {
            self.shipmentStatus = newStatus
        } else if let _ = try? container.decodeIfPresent(String.self, forKey: .trackingNumber) {
            self.shipmentStatus = .shipped
        } else {
            self.shipmentStatus = .shipped
        }
    }
    
    // MARK: - 修复点 3: 补上缺失的编码 (encode) 方法
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderNumber, forKey: .orderNumber)
        try container.encode(customerName, forKey: .customerName)
        try container.encode(date, forKey: .date)
        try container.encode(orderItems, forKey: .orderItems)
        try container.encode(urgency, forKey: .urgency)
        try container.encode(customerType, forKey: .customerType)
        try container.encode(trademark, forKey: .trademark)
        try container.encode(shipmentStatus, forKey: .shipmentStatus) // 只编码新字段
        try container.encode(payments, forKey: .payments)
        try container.encode(status, forKey: .status)
        try container.encode(reworkItems, forKey: .reworkItems)
    }
}

struct OrderIDWrapper: Identifiable {
    let id: UUID
}
