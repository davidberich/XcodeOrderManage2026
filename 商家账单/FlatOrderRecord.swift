// FlatOrderRecord.swift

import Foundation

// 代表扁平化数据库中的单条记录
struct FlatOrderRecord: Identifiable {
    let id = UUID()
    
    // 1. 订单号
    let orderNumber: String
    
    // 2. 客户名称
    let customerName: String
    
    // 3. 产品编号ID (对应商品名称)
    let productName: String
    
    // 4. 颜色/皮料
    let colorAndLeather: String
    
    // 5. 码数/件数 (聚合字符串，例如: "37x1, 38x2")
    let sizeQuantitySummary: String
    
    // 6. 总件数 (这行记录的总数量)
    let totalItemQuantity: Int
    
    // 7. 商标
    let trademark: String
    
    // 8. 单价
    let unitPrice: Double
    
    // 9. 销售总金额
    var itemTotalPrice: Double {
        return Double(totalItemQuantity) * unitPrice
    }
    
    // 10. 订单日期
    let orderDate: Date
}
