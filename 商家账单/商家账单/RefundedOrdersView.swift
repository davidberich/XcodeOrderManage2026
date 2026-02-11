// RefundedOrdersView.swift
// 已修复编译器无法在合理时间内完成类型检查的错误

import SwiftUI

struct RefundedOrdersView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    @EnvironmentObject var userSettings: UserSettings // <<< 修复点1: 添加 UserSettings 环璄变量 >>>
    @Environment(\.presentationMode) var presentationMode
    
    @Namespace private var refundedNamespace
    
    @State private var searchText = ""
    @State private var selectedOrder: Order?

    private var refundedOrders: [Order] {
        viewModel.orders.filter { $0.status == .refunded }
    }
    
    private var filteredOrders: [Order] {
        if searchText.isEmpty {
            return refundedOrders
        } else {
            return refundedOrders.filter {
                $0.customerName.localizedCaseInsensitiveContains(searchText) ||
                $0.orderNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        // <<< 修复点2: 将 GeometryReader 移到最外层 >>>
        // 这样可以确保 screenWidth 在所有子视图中都可用
        GeometryReader { geometry in
            NavigationView {
                // 将主要内容提取到一个私有函数中，以简化 body
                mainContent(screenWidth: geometry.size.width)
                    .background(Color(.systemGroupedBackground))
                    .navigationTitle("退货退款记录")
                    .navigationBarTitleDisplayMode(.inline)
                    .searchable(text: $searchText, prompt: "搜索客户或订单号")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完成") { presentationMode.wrappedValue.dismiss() }
                        }
                    }
                    .sheet(item: $selectedOrder) { orderToEdit in
                        if let index = viewModel.orders.firstIndex(where: { $0.id == orderToEdit.id }) {
                            NavigationView {
                                OrderDetailView(order: $viewModel.orders[index])
                            }
                            .environmentObject(viewModel)
                            .environmentObject(userSettings) // 确保 sheet 也能获取到
                        }
                    }
            }
        }
    }
    
    // MARK: - 辅助视图构建器
    
    // <<< 修复点3: 将主要内容封装成一个私有函数 >>>
    @ViewBuilder
    private func mainContent(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            summaryCard
                .padding([.horizontal, .top])
            
            if filteredOrders.isEmpty {
                emptyStateView
            } else {
                orderListView(screenWidth: screenWidth)
            }
        }
    }

    // <<< 修复点4: 将 List 及其内容也封装成一个私有函数 >>>
    @ViewBuilder
    private func orderListView(screenWidth: CGFloat) -> some View {
        List {
            ForEach(filteredOrders) { order in
                ZStack(alignment: .topTrailing) {
                    OrderRowView(
                        order: order,
                        screenWidth: screenWidth,
                        // <<< 修复点1: 传递 fontScaleMultiplier >>>
                        fontScaleMultiplier: userSettings.fontScaleMultiplier,
                        onImageTapped: { _ in },
                        namespace: refundedNamespace
                    )
                    .saturation(0)
                    
                    statusTag(text: "退货退款", color: .white, backgroundColor: .gray)
                        .padding([.top, .trailing], 6)
                }
                .padding(.horizontal)
                .onTapGesture {
                    self.selectedOrder = order
                }
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var summaryCard: some View {
        let totalRefundAmount = refundedOrders.reduce(0) { $0 + $1.totalOrderPrice }
        let totalRefundUnits = refundedOrders.reduce(0) { $0 + $1.totalOrderQuantity }
        
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                Text("已退款总额")
                    .font(.headline)
                Spacer()
                Text("¥\(String(format: "%.2f", totalRefundAmount))")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundColor(.gray)
            }
            Divider()
            HStack {
                RefundStatItem(title: "退款单数", value: "\(refundedOrders.count) 单")
                Spacer()
                RefundStatItem(title: "退款件数", value: "\(totalRefundUnits) 件")
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "tray.fill")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            Text("暂无退款记录")
                .font(.title.bold())
            Text("所有退货退款的订单会在这里显示")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RefundStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
        }
    }
}
