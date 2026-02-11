import SwiftUI
import Charts

// MARK: - Main Analytics View
struct AnalyticsView: View {
    @StateObject private var viewModel: AnalyticsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    private enum AnalyticsTab: String, CaseIterable {
        case summary = "经营汇总"
        case products = "商品分析"
        case customers = "批发客"
    }
    @State private var selectedTab: AnalyticsTab = .summary
    
    init(orders: [Order]) {
        _viewModel = StateObject(wrappedValue: AnalyticsViewModel(orders: orders))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("分析模块", selection: $selectedTab) {
                    ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                
                if selectedTab == .customers {
                    CustomerFilterView(viewModel: viewModel)
                } else {
                    MainFilterView(viewModel: viewModel)
                }
                
                Divider()

                switch selectedTab {
                case .summary:
                    BusinessSummaryView(viewModel: viewModel)
                case .products:
                    ProductAnalysisView(viewModel: viewModel)
                case .customers:
                    CustomerAnalysisView(viewModel: viewModel)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("数据分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Filter Views
struct MainFilterView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @State private var showingCustomDateRangePicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            Picker("时间粒度", selection: $viewModel.granularity) {
                ForEach(AnalyticsViewModel.TimeGranularity.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.granularity) {
                viewModel.customDateRange = nil
            }
            
            HStack(spacing: 0) {
                Button(action: { viewModel.moveToPreviousPeriod() }) {
                    Image(systemName: "chevron.left").padding()
                }.disabled(viewModel.customDateRange != nil)

                datePickerLabel()
                
                Button(action: { viewModel.moveToNextPeriod() }) {
                    Image(systemName: "chevron.right").padding()
                }.disabled(viewModel.customDateRange != nil)

                Spacer(minLength: 10)
                
                Menu {
                    Button("自定义范围") { showingCustomDateRangePicker = true }
                    Divider()
                    Picker("客户类型", selection: $viewModel.customerType) {
                        Text("全部客户").tag(CustomerType?(nil))
                        ForEach(CustomerType.allCases, id: \.self) { Text($0.displayTitle).tag(CustomerType?($0)) }
                    }
                } label: { FilterButton(label: viewModel.customerType?.displayTitle ?? "全部客户") }

                Menu {
                    Picker("数据对比", selection: $viewModel.comparisonType) {
                        ForEach(AnalyticsViewModel.ComparisonType.allCases) { Text($0.rawValue).tag($0) }
                    }.disabled(viewModel.customDateRange != nil)
                } label: { FilterButton(label: viewModel.comparisonType.rawValue) }
            }
        }
        .padding()
        .sheet(isPresented: $showingCustomDateRangePicker) {
            CustomDateRangePicker(dateRange: $viewModel.customDateRange)
        }
    }
    
    @ViewBuilder
    private func datePickerLabel() -> some View {
        Text(viewModel.selectedDateLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                DatePicker("选择周期", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .blendMode(.destinationOver)
                    .disabled(viewModel.customDateRange != nil)
            )
    }
}

struct CustomerFilterView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    var body: some View {
        HStack {
            Menu {
                Picker("选择客户", selection: $viewModel.selectedCustomerName) {
                    Text("所有批发客户").tag(String?(nil))
                    ForEach(viewModel.wholesaleCustomerNames, id: \.self) { name in Text(name).tag(String?(name)) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.3.sequence.fill")
                    Text(viewModel.selectedCustomerName ?? "所有批发客户")
                }
                .font(.headline)
                .foregroundColor(.accentColor)
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
            }
            Spacer()
        }
        .padding()
    }
}

struct CustomDateRangePicker: View {
    @Binding var dateRange: ClosedRange<Date>?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var startDate: Date
    @State private var endDate: Date
    
    init(dateRange: Binding<ClosedRange<Date>?>) {
        self._dateRange = dateRange
        let today = Date()
        let existingRange = dateRange.wrappedValue ?? today...today
        self._startDate = State(initialValue: existingRange.lowerBound)
        self._endDate = State(initialValue: existingRange.upperBound)
    }
    
    var body: some View {
        NavigationView {
            Form {
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                DatePicker("结束日期", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            .navigationTitle("选择日期范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("确定") {
                    dateRange = startDate...endDate
                    presentationMode.wrappedValue.dismiss()
                } }
            }
        }
    }
}

struct FilterButton: View {
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
            Image(systemName: "chevron.down")
        }
        .font(.caption.bold())
        .foregroundColor(.primary)
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

// MARK: - Business Summary, Product, Customer Views
struct BusinessSummaryView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    private let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                LazyVGrid(columns: columns, spacing: 15) {
                    KpiCard(title: "销售金额", value: String(format: "¥%.2f", viewModel.summaryData.revenue), change: viewModel.summaryData.revenueChange, icon: "yensign.circle.fill", color: .blue)
                    KpiCard(title: "销售单数", value: "\(viewModel.summaryData.orderCount)", change: viewModel.summaryData.orderCountChange, icon: "doc.text.fill", color: .indigo)
                    KpiCard(title: "销售件数", value: "\(viewModel.summaryData.unitsSold)", change: viewModel.summaryData.unitsSoldChange, icon: "shippingbox.fill", color: .orange)
                    KpiCard(title: "客户数", value: "\(viewModel.summaryData.customerCount)", change: viewModel.summaryData.customerCountChange, icon: "person.2.fill", color: .green)
                }
                .padding(.horizontal)
                
                InteractiveBarChartView(
                    title: "销售金额趋势 (\(viewModel.customerType?.displayTitle ?? "全部"))",
                    data: viewModel.chartData,
                    granularity: viewModel.granularity
                )
            }
            .padding(.top)
        }
    }
}

struct KpiCard: View {
    let title: String, value: String, change: Double?, icon: String, color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.headline).foregroundColor(color)
                Text(title).font(.subheadline).foregroundColor(.secondary)
                Spacer()
            }
            Text(value).font(.system(.title, design: .rounded).bold()).foregroundColor(.primary)
            if let change = change {
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%.1f%%", abs(change * 100)))
                }
                .font(.footnote.weight(.semibold)).foregroundColor(change >= 0 ? .green : .red)
            } else { Text("-").font(.footnote).foregroundColor(.clear) }
        }
        .padding().background(Color(.systemBackground)).cornerRadius(12).shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

struct ProductAnalysisView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    enum ProductRankType: String, CaseIterable, Identifiable { case byRevenue = "按销售额", byQuantity = "按销量", byColor = "按颜色", bySize = "按尺码"; var id: String { self.rawValue } }
    @State private var rankType: ProductRankType = .byRevenue
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("排行依据", selection: $rankType) {
                ForEach(ProductRankType.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).padding()

            List {
                switch rankType {
                case .byRevenue:
                    RankSection(title: "按销售额", items: viewModel.productAnalysisByRevenue, content: { product in
                        Text("销售额: ¥\(String(format: "%.0f", product.totalRevenue)) | 销量: \(product.totalQuantity)件").font(.subheadline).foregroundColor(.secondary)
                    }, primaryText: { Text($0.productName) })
                case .byQuantity:
                    RankSection(title: "按销量", items: viewModel.productAnalysisByQuantity, content: { product in
                        Text("销量: \(product.totalQuantity)件 | 销售额: ¥\(String(format: "%.0f", product.totalRevenue))").font(.subheadline).foregroundColor(.secondary)
                    }, primaryText: { Text($0.productName) })
                case .byColor:
                    RankSection(title: "按颜色", items: viewModel.colorRanking, content: { color in
                        Text("销量: \(color.quantity) 件").font(.subheadline).foregroundColor(.secondary)
                    }, primaryText: { Text($0.color) })
                case .bySize:
                    RankSection(title: "按尺码", items: viewModel.sizeRanking, content: { size in
                        Text("销量: \(size.quantity) 件").font(.subheadline).foregroundColor(.secondary)
                    }, primaryText: { Text($0.size) })
                }
            }.listStyle(.insetGrouped)
        }
    }
}

struct RankSection<Item: Identifiable, Content: View, PrimaryText: View>: View {
    let title: String; let items: [Item]
    @ViewBuilder let content: (Item) -> Content; @ViewBuilder let primaryText: (Item) -> PrimaryText
    
    var body: some View {
        Section(header: Text(title)) {
            if items.isEmpty {
                Text("无数据").foregroundColor(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).").font(.headline).frame(width: 30, alignment: .leading)
                        VStack(alignment: .leading, spacing: 5) {
                            primaryText(item).font(.headline)
                            content(item)
                        }
                    }.padding(.vertical, 5)
                }
            }
        }
    }
}

struct CustomerAnalysisView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                let summary = viewModel.customerSummaryData; let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]
                LazyVGrid(columns: columns, spacing: 15) {
                    KpiCard(title: "总销售额", value: String(format: "¥%.2f", summary.revenue), change: nil, icon: "yensign.circle.fill", color: .blue)
                    KpiCard(title: "总订单数", value: "\(summary.orderCount)", change: nil, icon: "doc.text.fill", color: .indigo)
                }
                
                VStack {
                    if filteredCustomerData().isEmpty {
                        Text("无客户月度数据").foregroundColor(.gray).padding().frame(maxWidth: .infinity)
                    } else {
                        ForEach(filteredCustomerData()) { customer in
                            VStack(alignment: .leading) {
                                Text(customer.customerName).font(.title3.bold()).padding(.top)
                                ForEach(customer.monthlyData, id: \.self) { monthData in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(monthData.month, format: .dateTime.year().month(.wide)).font(.headline)
                                        Text("订单: \(monthData.orderCount) | 件数: \(monthData.unitsSold) | 金额: ¥\(String(format: "%.0f", monthData.revenue))").font(.subheadline)
                                        if !monthData.topProducts.isEmpty { Text("热销品: \(monthData.topProducts.joined(separator: ", "))").font(.caption).foregroundColor(.secondary) }
                                    }
                                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemBackground)).cornerRadius(10)
                                    .padding(.bottom, 5)
                                }
                            }
                        }
                    }
                }
            }.padding()
        }
    }
    
    private func filteredCustomerData() -> [CustomerAnalysisData] {
        if let name = viewModel.selectedCustomerName { return viewModel.customerAnalysis.filter { $0.customerName == name } }
        return viewModel.customerAnalysis
    }
}


// MARK: - Interactive Chart
struct InteractiveBarChartView: View {
    let title: String
    let data: [ChartSegment]
    let granularity: AnalyticsViewModel.TimeGranularity
    
    @State private var showingFullScreenChart = false
    @State private var selectedDate: Date?

    private var selectedSegment: ChartSegment? {
        guard let selectedDate else { return nil }
        return data.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }
    
    private var visibleDomainLength: Double {
        let day: Double = 3600 * 24
        switch granularity {
        case .day: return day * 30
        case .week: return day * 365 / 2
        case .month: return day * 365 * 1.5
        case .quarter: return day * 365 * 3
        case .year: return day * 365 * 8
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chartHeader
            if data.isEmpty {
                emptyStateView
            } else {
                chartContent
            }
        }
        .padding([.horizontal, .top])
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .sheet(isPresented: $showingFullScreenChart) {
            FullScreenChartView(title: title, data: data, unit: granularity.calendarComponent)
        }
    }
    
    private var chartHeader: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Button(action: { showingFullScreenChart = true }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .disabled(data.isEmpty)
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("无销售数据").font(.caption).foregroundColor(.gray)
            Spacer()
        }
        .frame(height: 250, alignment: .center)
    }

    @ViewBuilder
    private var chartContent: some View {
        ScrollViewReader { proxy in
            Chart {
                ForEach(data) { segment in
                    BarMark(
                        x: .value("日期", segment.date, unit: granularity.calendarComponent),
                        y: .value("金额", segment.wholesaleValue)
                    ).foregroundStyle(by: .value("客户类型", "批发客"))
                    
                    BarMark(
                        x: .value("日期", segment.date, unit: granularity.calendarComponent),
                        y: .value("金额", segment.retailValue)
                    ).foregroundStyle(by: .value("客户类型", "零售客"))
                }
                
                if let selectedDate {
                    RuleMark(x: .value("选中", selectedDate))
                        .foregroundStyle(Color.gray.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .zIndex(1)
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: visibleDomainLength)
            .chartXAxis(content: {
                switch self.granularity {
                case .day, .week:
                    AxisMarks(values: .stride(by: .month, count: 1)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                case .month:
                    AxisMarks(values: .stride(by: .month, count: 6)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                case .quarter:
                    AxisMarks(values: .stride(by: .year, count: 1)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.year(.twoDigits).quarter(.oneDigit))
                    }
                case .year:
                    AxisMarks(values: .stride(by: .year, count: 1)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.year())
                    }
                }
            })
            .chartYAxis { AxisMarks() }
            .frame(height: 250)
            .chartXSelection(value: $selectedDate)
            .overlay(alignment: .top) {
                if let selectedSegment {
                    TooltipView(segment: selectedSegment, granularity: granularity)
                        .padding(.vertical, 8)
                        .transition(.opacity.animation(.easeInOut))
                }
            }
            .task(id: data.count) {
                if let lastDate = data.last?.date {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                    proxy.scrollTo(lastDate, anchor: .trailing)
                }
            }
        }
    }
}

// MARK: - Tooltip & FullScreenChart
struct TooltipView: View {
    let segment: ChartSegment
    let granularity: AnalyticsViewModel.TimeGranularity
    
    private func formattedDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        switch granularity {
        case .day:
            formatter.dateFormat = "yyyy/M/d EEEE"
            return formatter.string(from: segment.date)
        case .week:
            guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: segment.date) else {
                return "N/A"
            }
            let start = weekInterval.start
            let end = weekInterval.end.addingTimeInterval(-1)
            formatter.dateFormat = "M/d"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .month:
            formatter.dateFormat = "yyyy年 M月"
            return formatter.string(from: segment.date)
        case .quarter:
            let quarter = Calendar.current.component(.quarter, from: segment.date)
            formatter.dateFormat = "yyyy年"
            return "\(formatter.string(from: segment.date)) Q\(quarter)"
        case .year:
            formatter.dateFormat = "yyyy年"
            return formatter.string(from: segment.date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDateString())
                .font(.caption.bold())
                .foregroundColor(.primary)
            
            Divider().padding(.vertical, 2)
            
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    Text("总金额:").gridColumnAlignment(.leading)
                    Text("¥\(String(format: "%.2f", segment.totalValue))").gridColumnAlignment(.trailing)
                }
                GridRow {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
                        Text("批发客:")
                    }
                    Text("¥\(String(format: "%.0f", segment.wholesaleValue)) (\(segment.wholesaleOrderCount)单)").gridColumnAlignment(.trailing)
                }
                GridRow {
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue.opacity(0.8)).frame(width: 8, height: 8)
                        Text("零售客:")
                    }
                    Text("¥\(String(format: "%.0f", segment.retailValue)) (\(segment.retailOrderCount)单)").gridColumnAlignment(.trailing)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Material.thin)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 5)
        .frame(width: 175)
    }
}

struct FullScreenChartView: View {
    let title: String
    let data: [ChartSegment]
    let unit: Calendar.Component
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                Chart {
                    ForEach(data) { segment in
                        BarMark(
                            x: .value("日期", segment.date, unit: unit),
                            y: .value("金额", segment.wholesaleValue)
                        ).foregroundStyle(by: .value("客户类型", "批发客"))
                        
                        BarMark(
                            x: .value("日期", segment.date, unit: unit),
                            y: .value("金额", segment.retailValue)
                        ).foregroundStyle(by: .value("客户类型", "零售客"))
                    }
                }
                .chartForegroundStyleScale([
                    "批发客": Color.green.gradient,
                    "零售客": Color.blue.gradient
                ])
                .chartXAxis {
                     AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                }
                .padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") { presentationMode.wrappedValue.dismiss() }
                    }
                }
            }
            .forceLandscape()
        }
        .navigationViewStyle(.stack)
    }
}

struct LandscapeViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
                        print("Error requesting geometry update for landscape: \(error.localizedDescription)")
                    }
                }
                AppDelegate.orientationLock = .landscape
            }
            .onDisappear {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                     windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                        print("Error requesting geometry update for portrait: \(error.localizedDescription)")
                    }
                }
                AppDelegate.orientationLock = .portrait
            }
    }
}

extension View {
    func forceLandscape() -> some View {
        self.modifier(LandscapeViewModifier())
    }
}
