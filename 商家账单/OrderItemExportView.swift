// OrderItemExportView.swift

import SwiftUI

// 这个视图现在只用于渲染订单的“文字部分”
struct OrderItemExportView: View {
    let order: Order
    let item: OrderItem
    
    // 渲染宽度
    private let renderWidth: CGFloat = 800

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            infoRow(label: "客户名称:", value: order.customerName)
            infoRow(label: "鞋子编号:", value: item.productName)
            infoRow(label: "颜色:", value: item.color)
            
            // <<< 核心修复点: 不再检查 orderNotes，而是检查 urgency >>>
            if order.urgency == .urgent {
                // 如果是加急订单，就显示一行 "订单类型: 加急"
                infoRow(label: "订单类型:", value: "加急")
            }
            
            infoRow(label: "对数和码数:", value: formatSizeQuantities(item.sizeQuantities))
            
            infoRow(label: "日期:", value: order.date.formattedAsYMD())
        }
        .font(.custom("PingFangSC-Medium", size: 32))
        .padding(30)
        .frame(width: renderWidth, alignment: .leading)
        .background(Color.white)
        .border(Color.black, width: 2.5)
    }
    
    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .frame(width: 240, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func formatSizeQuantities(_ quantities: [String: Int]) -> String {
        let sortedSizes = quantities.keys.sorted()
        return sortedSizes.map { size in
            let quantity = quantities[size] ?? 0
            let sizeNumber = size.replacingOccurrences(of: "码", with: "")
            return "\(quantity)/\(sizeNumber)"
        }.joined(separator: " ")
    }
}
