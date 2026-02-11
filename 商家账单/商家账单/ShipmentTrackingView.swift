// ShipmentTrackingView.swift

import SwiftUI
import UIKit

struct ShipmentTrackingView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var reportText: String = "正在生成报告..."
    
    // 定义工厂出货周期为7天
    private let shippingDeadlineInDays: Int = 7

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextEditor(text: $reportText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("出货追踪报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        Button(action: copyReport) {
                            Image(systemName: "doc.on.doc")
                        }
                        Button("关闭") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .onAppear(perform: generateTrackingReport)
        }
    }
    
    private func copyReport() {
        UIPasteboard.general.string = reportText
    }
    
    // MARK: - 核心修改: 重构报告生成逻辑
    private func generateTrackingReport() {
        let unshippedOrders = viewModel.orders.filter { $0.shipmentStatus == .notShipped }
        
        if unshippedOrders.isEmpty {
            self.reportText = "太棒了！所有订单均已出货。"
            return
        }

        let today = Calendar.current.startOfDay(for: Date())

        let reportItems = unshippedOrders.map { order -> ReportItem in
            let orderDate = Calendar.current.startOfDay(for: order.date)
            let deadlineDate = Calendar.current.date(byAdding: .day, value: shippingDeadlineInDays, to: orderDate)!
            let daysDifference = Calendar.current.dateComponents([.day], from: today, to: deadlineDate).day ?? 0
            return ReportItem(order: order, daysDifference: daysDifference)
        }
        
        // 1. 按“加急”和“正常”进行分组
        let urgentItems = reportItems
            .filter { $0.order.urgency == .urgent }
            .sorted { $0.daysDifference < $1.daysDifference }
        
        let normalItems = reportItems
            .filter { $0.order.urgency == .normal }
            .sorted { $0.daysDifference < $1.daysDifference }

        // 2. 计算顶部的汇总数据
        let totalUnshippedCount = urgentItems.reduce(0) { $0 + $1.order.totalOrderQuantity } + normalItems.reduce(0) { $0 + $1.order.totalOrderQuantity }
        let totalUrgentCount = urgentItems.reduce(0) { $0 + $1.order.totalOrderQuantity }
        let totalNormalCount = normalItems.reduce(0) { $0 + $1.order.totalOrderQuantity }
        
        var reportLines: [String] = []

        // 3. 构建汇总信息部分
        reportLines.append("待出货总数：\(totalUnshippedCount)对")
        reportLines.append("加急出货总数：\(totalUrgentCount)对")
        reportLines.append("正常出货总数：\(totalNormalCount)对")
        reportLines.append("") // 添加一个空行

        // 4. 构建“加急出货”部分
        if !urgentItems.isEmpty {
            reportLines.append("一、加急出货")
            let urgentStrings = urgentItems.enumerated().map { (index, item) -> String in
                return "\(index + 1). \(item.formattedString)"
            }
            reportLines.append(contentsOf: urgentStrings)
            reportLines.append("") // 添加一个空行
        }

        // 5. 构建“正常出货”部分
        if !normalItems.isEmpty {
            reportLines.append("二、正常出货")
            let normalStrings = normalItems.enumerated().map { (index, item) -> String in
                return "\(index + 1). \(item.formattedString)"
            }
            reportLines.append(contentsOf: normalStrings)
        }
        
        // 6. 拼接成最终的报告文本
        self.reportText = reportLines.joined(separator: "\n")
    }
}

// MARK: - 辅助数据结构 (格式化字符串已更新)
private struct ReportItem {
    let order: Order
    let daysDifference: Int

    var deadlineStatus: String {
        if daysDifference < 0 {
            return "逾期 \(-daysDifference) 日"
        } else if daysDifference == 0 {
            return "今日出货！"
        } else {
            return "\(daysDifference) 日内出货"
        }
    }
    
    // MARK: - 修改点: 移除 urgency 状态，因为它已经通过分组体现了
    var formattedString: String {
        "订单: \(order.orderNumber) | \(deadlineStatus) | \(order.totalOrderQuantity)对"
    }
}
