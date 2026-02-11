import SwiftUI

struct PlainDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.label
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        configuration.isExpanded.toggle()
                    }
                }
            
            if configuration.isExpanded {
                configuration.content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}


struct SideMenuView: View {
    @EnvironmentObject var viewModel: OrderViewModel
    @EnvironmentObject var userSettings: UserSettings
    
    @Binding var showTrashView: Bool
    @Binding var showSideMenu: Bool
    @Binding var showCashConfirmation: Bool
    
    @State private var showingBackupView = false
    @State private var isFontAdjusterExpanded = false
    @State private var showingRefundedView = false
    @State private var showingShipmentTracking = false
    
    var onToggleMultiSelectDelete: () -> Void
    var onShowDatabase: () -> Void
    var onShowAnalytics: () -> Void
    
    var body: some View {
        List {
            Section {
                Text("操作菜单")
                    .font(.largeTitle.bold())
                    .padding(.vertical, 10)
            }
            .listRowBackground(Color.clear)

            Section {
                menuButton(icon: "archivebox.circle.fill", text: "备份与恢复") { showingBackupView = true }
                menuButton(icon: "dollarsign.circle.fill", text: "现金对账") { showCashConfirmation = true }
                menuButton(icon: "chart.pie.fill", text: "数据分析", action: onShowAnalytics)
                
                // MARK: - 新增功能按钮
                menuButton(icon: "shippingbox.and.arrow.backward.fill", text: "出货追踪") { showingShipmentTracking = true }
                
                menuButton(icon: "server.rack", text: "数据库", action: onShowDatabase)
            }

            Section {
                DisclosureGroup(isExpanded: $isFontAdjusterExpanded) {
                    HStack(spacing: 15) {
                        Image(systemName: "textformat.size.smaller")
                        Slider(value: $userSettings.fontScaleMultiplier, in: 0.8...1.5, step: 0.05)
                        Image(systemName: "textformat.size.larger")
                    }
                    .padding(.top, 10)
                } label: {
                    Label("列表字体大小 (\(Int(userSettings.fontScaleMultiplier * 100))%)", systemImage: "textformat.size")
                }
                .accentColor(.primary)
            }

            Section(header: Text("订单管理")) {
                let refundedCount = viewModel.orders.filter { $0.status == .refunded }.count
                menuButton(icon: "arrow.uturn.backward.circle.fill", text: "退货退款 (\(refundedCount))") {
                    showingRefundedView = true
                }
                menuButton(icon: "checklist", text: "选择订单删除", action: onToggleMultiSelectDelete)
                menuButton(icon: "trash.fill", text: "垃圾桶 (\(viewModel.deletedOrders.count))") { showTrashView = true }
            }
        }
        .listStyle(.insetGrouped)
        .onChange(of: showSideMenu) { oldState, newState in
            if newState {
                isFontAdjusterExpanded = false
            }
        }
        .sheet(isPresented: $showingBackupView) {
            BackupAndRestoreView().environmentObject(viewModel)
        }
        .sheet(isPresented: $showingRefundedView) {
            RefundedOrdersView().environmentObject(viewModel)
        }
        // MARK: - 新增 sheet
        .sheet(isPresented: $showingShipmentTracking) {
            ShipmentTrackingView().environmentObject(viewModel)
        }
    }
    
    private func menuButton(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { showSideMenu = false }
            }
        }) {
            Label(text, systemImage: icon)
        }
        .foregroundColor(.primary)
    }
}
