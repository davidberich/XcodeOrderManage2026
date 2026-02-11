// CashConfirmationView.swift
// 已移除重复的 statusTag 函数定义

import SwiftUI

struct CashConfirmationView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.presentationMode) var presentationMode
    
    @Namespace private var cashConfirmationNamespace
    
    @State private var searchText = ""
    @State private var selectedOrder: Order?

    private var unconfirmedOrders: [Order] {
        viewModel.orders
            .filter { ($0.status ?? .active) == .active && $0.paymentStatus != .paid }
    }
    
    private var filteredOrders: [Order] {
        if searchText.isEmpty {
            return unconfirmedOrders
        } else {
            return unconfirmedOrders.filter {
                $0.customerName.localizedCaseInsensitiveContains(searchText) ||
                $0.orderNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                mainContent(screenWidth: geometry.size.width)
                    .listStyle(.plain)
                    .navigationTitle("现金对账")
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
                            .environmentObject(userSettings)
                        }
                    }
            }
        }
    }
    
    // MARK: - 辅助视图构建器
    
    @ViewBuilder
    private func mainContent(screenWidth: CGFloat) -> some View {
        List {
            Section {
                summaryCard
            }
            .id(userSettings.fontScaleMultiplier)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if filteredOrders.isEmpty {
                Section {
                    emptyStateView
                }
            } else {
                orderListSection(screenWidth: screenWidth)
            }
        }
    }
    
    @ViewBuilder
    private func orderListSection(screenWidth: CGFloat) -> some View {
        Section(header: Text("待处理订单 (\(filteredOrders.count))")) {
            ForEach(filteredOrders) { order in
                CashConfirmationRow(
                    order: order,
                    screenWidth: screenWidth,
                    namespace: cashConfirmationNamespace
                )
                .onTapGesture {
                    self.selectedOrder = order
                }
            }
        }
    }
    
    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "hourglass.circle.fill").font(.title2).foregroundColor(.orange)
                Text("待收总额").font(.headline)
                Spacer()
                Text("¥\(String(format: "%.2f", viewModel.unconfirmedBalanceDue))").font(.system(.title, design: .rounded).bold()).foregroundColor(.orange)
            }
            Divider()
            HStack {
                SummaryStatItem(title: "总营收", value: "¥\(String(format: "%.2f", viewModel.totalRevenue))")
                Spacer()
                SummaryStatItem(title: "已收总额", value: "¥\(String(format: "%.2f", viewModel.totalPaidAmount))")
                Spacer()
                SummaryStatItem(title: "待收单数", value: "\(unconfirmedOrders.count) 单")
            }
        }
        .padding().background(Color(.systemBackground)).cornerRadius(12).shadow(color: .black.opacity(0.05), radius: 5, y: 2).padding()
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 80)
            Image(systemName: "checkmark.seal.fill").font(.system(size: 70)).foregroundColor(.green)
            Text("账目清晰").font(.title.bold())
            Text("所有正常订单均已付清全款！").font(.body).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity).listRowBackground(Color.clear)
    }
}

private struct CashConfirmationRow: View {
    @EnvironmentObject var userSettings: UserSettings
    
    let order: Order
    let screenWidth: CGFloat
    let namespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .topTrailing) {
            OrderRowView(
                order: order,
                screenWidth: screenWidth,
                fontScaleMultiplier: userSettings.fontScaleMultiplier,
                onImageTapped: { _ in },
                namespace: namespace
            )

            let status = order.paymentStatus
            statusTag(
                text: status.rawValue,
                color: .white,
                backgroundColor: status.color
            )
            .padding([.top, .trailing], 6)
        }
        .padding(.horizontal)
        .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
        .listRowSeparator(.hidden)
    }
}


private struct SummaryStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.callout.weight(.medium))
        }
    }
}

// <<< 核心修复点: 我已经删除了这里对 statusTag 的重复定义 >>>
// @ViewBuilder
// private func statusTag(...) -> some View { ... }
