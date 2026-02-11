// ContentView.swift

import SwiftUI

// Helper enum for grouping orders by time period
private enum TimeCategory: Hashable, Comparable {
    case today, previous7Days, month(Date)
    
    static func < (lhs: TimeCategory, rhs: TimeCategory) -> Bool {
        switch (lhs, rhs) {
        case (.today, _): return false
        case (_, .today): return true
        case (.previous7Days, .month): return false
        case (.month, .previous7Days): return true
        case (.previous7Days, .previous7Days): return false
        case (.month(let d1), .month(let d2)): return d1 < d2
        }
    }
}

// Helper enum for the payment status filter menu
enum PaymentStatusFilter: String, CaseIterable, Identifiable {
    case all = "所有订单"
    case rework = "含返工"
    case pendingPrice = "单价待定"
    case unpaid = "未收款"
    case partial = "部分收款"
    case paid = "已结清"
    var id: String { self.rawValue }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    @EnvironmentObject var userSettings: UserSettings
    
    @State private var showingNewOrderSheet = false // 重命名以反映新视图
    @State private var selectedOrderID: OrderIDWrapper?
    
    @State private var searchText = ""
    
    @State private var showTrashViewSheet = false
    @State private var showingDatabaseView = false
    @State private var showingAnalyticsView = false
    @State private var showSideMenu = false
    @State private var menuOffset: CGFloat = 0
    @State private var showingCashConfirmationView = false
    @State private var isEditingForDelete = false
    @State private var selectedOrderIDs = Set<UUID>()
    @State private var showingDeleteConfirmationAlert = false
    @State private var galleryOrder: Order?
    @Namespace private var galleryNamespace
    
    @State private var paymentStatusFilter: PaymentStatusFilter = .all

    private var isEditing: Bool { isEditingForDelete }
    private var sideMenuWidth: CGFloat { UIScreen.main.bounds.width * 0.75 }
    private var menuAnimation: Animation { .interpolatingSpring(stiffness: 300, damping: 30) }

    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            
            ZStack {
                mainContentView(screenWidth: screenWidth)
                    .offset(x: menuOffset)
                    .disabled(showSideMenu)
                    .scaleEffect(galleryOrder != nil ? 0.92 : 1.0)
                    .brightness(galleryOrder != nil ? -0.2 : 0)
                
                sideMenuView.offset(x: menuOffset - sideMenuWidth)
                
                if galleryOrder != nil {
                    ImageGalleryView(selectedOrder: $galleryOrder, namespace: galleryNamespace).zIndex(3)
                }
            }
            .animation(menuAnimation, value: menuOffset)
            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: galleryOrder)
            .gesture(dragGestureToToggleMenu)
        }
    }

    // MARK: - Main Views
    
    private func mainContentView(screenWidth: CGFloat) -> some View {
        NavigationView {
            orderListView(screenWidth: screenWidth)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, prompt: "搜索客户、订单号或商品")
                .toolbar { mainToolbarContent }
        }
        // <<< 核心修改点: 使用 fullScreenCover 调用 NewOrderView >>>
        .fullScreenCover(isPresented: $showingNewOrderSheet) {
            NewOrderView().environmentObject(viewModel)
        }
        .sheet(item: $selectedOrderID) { wrapper in
            if let index = viewModel.orders.firstIndex(where: { $0.id == wrapper.id }) {
                NavigationView {
                    OrderDetailView(order: $viewModel.orders[index])
                }
                .environmentObject(viewModel)
                .environmentObject(userSettings)
            }
        }
        .sheet(isPresented: $showTrashViewSheet) { TrashView().environmentObject(viewModel) }
        .sheet(isPresented: $showingDatabaseView) { DatabaseView().environmentObject(viewModel) }
        .sheet(isPresented: $showingCashConfirmationView) { CashConfirmationView().environmentObject(viewModel) }
        .fullScreenCover(isPresented: $showingAnalyticsView) { AnalyticsView(orders: viewModel.orders) }
        .alert("确认操作", isPresented: $showingDeleteConfirmationAlert) {
            Button("移至垃圾桶", role: .destructive) { viewModel.moveOrdersToTrash(ids: selectedOrderIDs); cancelEditing() }
            Button("取消", role: .cancel) {}
        } message: { Text("你确定要将选中的 \(selectedOrderIDs.count) 个订单移至垃圾桶吗？") }
    }
    
    @ViewBuilder
    private func orderListView(screenWidth: CGFloat) -> some View {
        let currentGroupedOrders = groupedOrders(for: viewModel.orders)
        let ordersToDisplay = currentGroupedOrders.flatMap { $0.orders }

        if viewModel.orders.filter({ ($0.status ?? .active) == .active }).isEmpty {
            emptyStateView(message: "还没有订单 🧾\n点击右上角的 '+' 创建一个新订单吧！")
        } else if ordersToDisplay.isEmpty {
             emptyStateView(message: "没有符合筛选条件的订单")
        } else {
            List {
                ForEach(currentGroupedOrders, id: \.category) { group in
                    if !group.orders.isEmpty {
                        Section(header: Text(title(for: group.category))) {
                            ForEach(group.orders) { order in
                                savedOrderListRow(for: order, screenWidth: screenWidth)
                                    .opacity(galleryOrder?.id == order.id ? 0 : 1)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .id(userSettings.fontScaleMultiplier)
        }
    }
    
    // MARK: - Helper Views & Components
    
    @ToolbarContentBuilder
    private var mainToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                Text("商家记账本").font(.headline)
                Menu {
                    Picker("筛选状态", selection: $paymentStatusFilter) {
                        ForEach(PaymentStatusFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(paymentStatusFilter.rawValue).font(.caption).foregroundColor(.accentColor)
                        Image(systemName: "chevron.down").font(.caption).foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(8)
                }
            }
        }
        ToolbarItem(placement: .navigationBarLeading) {
            if isEditingForDelete { Button("取消") { cancelEditing() } }
            else { Button(action: { toggleSideMenu() }) { Image(systemName: "line.3.horizontal") } }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isEditingForDelete {
                Button(action: { if !selectedOrderIDs.isEmpty { showingDeleteConfirmationAlert = true } }) {
                    Image(systemName: "trash")
                }.disabled(selectedOrderIDs.isEmpty)
            } else {
                // <<< 核心修改点: 按钮触发 showingNewOrderSheet >>>
                Button(action: { showingNewOrderSheet = true }) {
                    Image(systemName: "plus.circle.fill").imageScale(.large)
                }
            }
        }
    }
    
    @ViewBuilder
    private func savedOrderListRow(for order: Order, screenWidth: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                if isEditing {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2).foregroundColor(selectedOrderIDs.contains(order.id) ? .accentColor : .secondary)
                        .frame(maxHeight: .infinity, alignment: .top).padding(.top, 10)
                }
                OrderRowView(
                    order: order,
                    screenWidth: screenWidth,
                    fontScaleMultiplier: userSettings.fontScaleMultiplier,
                    onImageTapped: { selectedOrder in self.galleryOrder = selectedOrder },
                    namespace: galleryNamespace
                )
                .padding(.horizontal)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditing { toggleSelection(for: order) }
                else { selectedOrderID = OrderIDWrapper(id: order.id) }
            }
            .saturation( (order.status ?? .active) == .refunded ? 0 : 1)
            
            if let status = order.status, status == .refunded {
                statusTag(text: "退货退款", color: .white, backgroundColor: .gray)
                    .padding([.top, .trailing])
            } else if order.customerName.isEmpty {
                statusTag(text: "信息待补全", color: .white, backgroundColor: .red.opacity(0.8))
                    .padding([.top, .trailing])
            } else if order.hasPendingPrice {
                // 如果有待定价格，这里不显示Tag，让OrderRowView内部的红色文字来提示
            } else if order.paymentStatus != .unpaid {
                let status = order.paymentStatus
                statusTag(text: status.rawValue, color: .white, backgroundColor: status.color)
                    .padding([.top, .trailing])
            }
        }
        .matchedGeometryEffect(id: "row_\(order.id)", in: galleryNamespace, isSource: false)
        .contextMenu {
            if !isEditing {
                Button { selectedOrderID = OrderIDWrapper(id: order.id) } label: { Label("查看详情/编辑", systemImage: "doc.text.magnifyingglass") }
                if (order.status ?? .active) == .active {
                    Button(role: .destructive) { viewModel.updateOrderStatus(for: order.id, to: .refunded) } label: { Label("退货退款", systemImage: "arrow.uturn.backward.circle.fill") }
                } else {
                    Button { viewModel.updateOrderStatus(for: order.id, to: .active) } label: { Label("取消退货退款", systemImage: "arrow.uturn.forward.circle.fill") }
                }
                Divider()
                Button(role: .destructive) { viewModel.moveOrderToTrash(id: order.id) } label: { Label("移至垃圾桶", systemImage: "trash") }
            }
        }
    }
    
    @ViewBuilder
    private var sideMenuView: some View {
        if showSideMenu {
            Color.black.opacity(0.001).ignoresSafeArea().onTapGesture { toggleSideMenu() }.zIndex(1)
        }
        HStack {
            SideMenuView(showTrashView: $showTrashViewSheet, showSideMenu: $showSideMenu, showCashConfirmation: $showingCashConfirmationView, onToggleMultiSelectDelete: { self.isEditingForDelete.toggle(); if !self.isEditingForDelete { self.selectedOrderIDs.removeAll() }; self.toggleSideMenu() }, onShowDatabase: { self.showingDatabaseView = true }, onShowAnalytics: { self.showingAnalyticsView = true })
            .frame(width: self.sideMenuWidth).background(Color(.systemBackground)).transition(.move(edge: .leading))
            Spacer()
        }.zIndex(2).shadow(radius: showSideMenu ? 15 : 0)
    }

    @ViewBuilder
    private func emptyStateView(message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    
    private func groupedOrders(for orders: [Order]) -> [(category: TimeCategory, orders: [Order])] {
        let activeOrders = orders.filter { ($0.status ?? .active) == .active }
        
        let filteredByStatus: [Order]
        switch paymentStatusFilter {
        case .all:
            filteredByStatus = activeOrders
        case .rework:
            filteredByStatus = activeOrders.filter { !$0.reworkItems.isEmpty }
        case .pendingPrice:
            filteredByStatus = activeOrders.filter { $0.hasPendingPrice }
        case .unpaid:
            filteredByStatus = activeOrders.filter { !$0.hasPendingPrice && $0.paymentStatus == .unpaid }
        case .partial:
            filteredByStatus = activeOrders.filter { !$0.hasPendingPrice && $0.paymentStatus == .partial }
        case .paid:
            filteredByStatus = activeOrders.filter { !$0.hasPendingPrice && $0.paymentStatus == .paid }
        }
        
        let searchFiltered = filteredByStatus.filter { order in
            if searchText.isEmpty { return true }
            return order.customerName.localizedCaseInsensitiveContains(searchText) ||
                   order.orderNumber.localizedCaseInsensitiveContains(searchText) ||
                   order.orderItems.contains { $0.productName.localizedCaseInsensitiveContains(searchText) }
        }

        let grouped = Dictionary(grouping: searchFiltered, by: categorize)
        return grouped.keys.sorted(by: >).map { (category: $0, orders: grouped[$0]!) }
    }
    
    private func toggleSideMenu() {
        showSideMenu.toggle()
        menuOffset = showSideMenu ? sideMenuWidth : 0
    }

    private var dragGestureToToggleMenu: some Gesture {
        DragGesture()
            .onChanged { value in
                guard galleryOrder == nil, !isEditingForDelete else { return }
                let newOffset: CGFloat
                if showSideMenu { newOffset = sideMenuWidth + value.translation.width }
                else { guard value.startLocation.x < 50 else { return }; newOffset = value.translation.width }
                menuOffset = max(0, min(newOffset, sideMenuWidth))
            }
            .onEnded { value in
                guard galleryOrder == nil, !isEditingForDelete else { return }
                let velocity = value.predictedEndTranslation.width
                if (velocity > 200 && !showSideMenu) || (menuOffset > sideMenuWidth / 2 && velocity > -200) { showSideMenu = true }
                else { showSideMenu = false }
                menuOffset = showSideMenu ? sideMenuWidth : 0
            }
    }
    
    private func categorize(order: Order) -> TimeCategory {
        let now = Date(); let calendar = Calendar.current
        if calendar.isDateInToday(order.date) { return .today }
        if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now), order.date >= sevenDaysAgo { return .previous7Days }
        let components = calendar.dateComponents([.year, .month], from: order.date)
        return .month(calendar.date(from: components)!)
    }
    
    private func title(for category: TimeCategory) -> String {
        switch category {
        case .today: return "今日"
        case .previous7Days: return "过去7日"
        case .month(let date):
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "zh_CN_POSIX"); formatter.dateFormat = "yyyy年M月"
            let thisMonthComponents = Calendar.current.dateComponents([.year, .month], from: Date())
            if Calendar.current.date(from: thisMonthComponents) == date { return "本月" }
            return formatter.string(from: date)
        }
    }
    
    private func cancelEditing() { isEditingForDelete = false; selectedOrderIDs.removeAll() }
    
    private func toggleSelection(for order: Order) {
        if selectedOrderIDs.contains(order.id) { selectedOrderIDs.remove(order.id) }
        else { selectedOrderIDs.insert(order.id) }
    }
}
