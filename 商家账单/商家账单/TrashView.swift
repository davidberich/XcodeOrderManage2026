// TrashView.swift
// 已修复编译器无法在合理时间内完成类型检查的错误，并优化了视图结构

import SwiftUI

struct TrashView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    @EnvironmentObject var userSettings: UserSettings // <<< 修复点1: 添加 UserSettings >>>
    @Environment(\.presentationMode) var presentationMode

    @Namespace private var trashNamespace
    
    @State private var orderToDelete: Order?
    @State private var showingDeleteConfirm = false

    var body: some View {
        // <<< 修复点2: 将 GeometryReader 移到最外层 >>>
        GeometryReader { geometry in
            NavigationView {
                // 将主要内容提取到 mainContent() 中
                mainContent(screenWidth: geometry.size.width)
                    .navigationTitle("垃圾桶 (\(viewModel.deletedOrders.count))")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("关闭") { presentationMode.wrappedValue.dismiss() }
                        }
                    }
                    .alert("确认永久删除", isPresented: $showingDeleteConfirm, presenting: orderToDelete) { order in
                        Button("永久删除", role: .destructive) {
                            viewModel.permanentlyDeleteOrdersFromTrash(ids: [order.id])
                            self.orderToDelete = nil
                        }
                        Button("取消", role: .cancel) {
                            self.orderToDelete = nil
                        }
                    } message: { order in
                        Text("你确定要永久删除客户“\(order.customerName)”的这份订单吗？此操作无法撤销，所有相关图片也会被删除。")
                    }
            }
        }
    }
    
    // MARK: - 辅助视图构建器
    
    // <<< 修复点3: 将主要内容封装成一个私有函数 >>>
    @ViewBuilder
    private func mainContent(screenWidth: CGFloat) -> some View {
        VStack {
            if viewModel.deletedOrders.isEmpty {
                emptyStateView
            } else {
                orderListView(screenWidth: screenWidth)
            }
        }
    }
    
    // <<< 修复点4: 将 List 及其内容也封装起来 >>>
    @ViewBuilder
    private func orderListView(screenWidth: CGFloat) -> some View {
        List {
            ForEach(viewModel.deletedOrders) { order in
                TrashOrderRow(
                    order: order,
                    screenWidth: screenWidth,
                    namespace: trashNamespace,
                    onRestore: {
                        viewModel.restoreOrdersFromTrash(ids: [order.id])
                    },
                    onDelete: {
                        self.orderToDelete = order
                        self.showingDeleteConfirm = true
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "trash.slash.fill")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            Text("垃圾桶是空的")
                .font(.title.bold())
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}


// <<< 修复点5: 创建一个专门的行项目视图，包含其所有逻辑 >>>
private struct TrashOrderRow: View {
    @EnvironmentObject var userSettings: UserSettings
    
    let order: Order
    let screenWidth: CGFloat
    let namespace: Namespace.ID
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            OrderRowView(
                order: order,
                screenWidth: screenWidth,
                fontScaleMultiplier: userSettings.fontScaleMultiplier,
                onImageTapped: { _ in },
                namespace: namespace
            )
            .saturation(0)
            
            statusTag(text: "垃圾桶", color: .white, backgroundColor: .gray)
                .padding([.top, .trailing], 6)
        }
        .padding(.horizontal)
        .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onRestore) {
                Label("恢复订单", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("永久删除", systemImage: "trash.fill")
            }
        }
    }
}
