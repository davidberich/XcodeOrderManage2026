import SwiftUI
import Combine

struct BusinessSummaryData {
    var revenue: Double = 0
    var orderCount: Int = 0
    var unitsSold: Int = 0
    var customerCount: Int = 0
    var previousRevenue: Double?
    var previousOrderCount: Int?
    var previousUnitsSold: Int?
    var previousCustomerCount: Int?
    
    var revenueChange: Double? { guard let p = previousRevenue, p != 0 else { return nil }; return (revenue - p) / p }
    var orderCountChange: Double? { guard let p = previousOrderCount, p != 0 else { return nil }; return (Double(orderCount - p) / Double(p)) }
    var unitsSoldChange: Double? { guard let p = previousUnitsSold, p != 0 else { return nil }; return (Double(unitsSold - p) / Double(p)) }
    var customerCountChange: Double? { guard let p = previousCustomerCount, p != 0 else { return nil }; return (Double(customerCount - p) / Double(p)) }
}

struct ChartSegment: Identifiable {
    let id: Date
    var date: Date
    var totalValue: Double
    var retailValue: Double
    var wholesaleValue: Double
    var orderCount: Int
    var unitCount: Int
    var retailOrderCount: Int
    var wholesaleOrderCount: Int
}

struct ProductAnalysisData: Identifiable {
    let id: String
    let productName: String
    var totalQuantity: Int
    var totalRevenue: Double
    init(id: String, productName: String, totalQuantity: Int = 0, totalRevenue: Double = 0.0) {
        self.id = id; self.productName = productName; self.totalQuantity = totalQuantity; self.totalRevenue = totalRevenue
    }
}

struct SizeRankData: Identifiable, Hashable { let id: String; let size: String; var quantity: Int }
struct ColorRankData: Identifiable, Hashable { let id: String; let color: String; var quantity: Int }
struct CustomerAnalysisData: Identifiable { let id = UUID(); let customerName: String; var monthlyData: [MonthlyCustomerData] }
struct MonthlyCustomerData: Identifiable, Hashable { let id: String; let month: Date; var orderCount: Int; var unitsSold: Int; var revenue: Double; var topProducts: [String] }


@MainActor
class AnalyticsViewModel: ObservableObject {
    
    enum TimeGranularity: String, CaseIterable, Identifiable {
        case day = "按日"
        case week = "按周"
        case month = "按月"
        case quarter = "按季度"
        case year = "按年"
        var id: String { self.rawValue }
        
        var calendarComponent: Calendar.Component {
            switch self {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            case .quarter: return .quarter
            case .year: return .year
            }
        }
    }
    
    enum ComparisonType: String, CaseIterable, Identifiable { case none = "当前数据", periodOverPeriod = "环比", yearOverYear = "同比"; var id: String { self.rawValue } }
    
    @Published var granularity: TimeGranularity = .day
    @Published var selectedDate: Date = .now
    @Published var customDateRange: ClosedRange<Date>? = nil
    @Published var customerType: CustomerType? = nil
    @Published var comparisonType: ComparisonType = .none
    
    @Published var summaryData = BusinessSummaryData()
    @Published var chartData: [ChartSegment] = []
    
    @Published var productAnalysisByRevenue: [ProductAnalysisData] = []
    @Published var productAnalysisByQuantity: [ProductAnalysisData] = []
    @Published var sizeRanking: [SizeRankData] = []
    @Published var colorRanking: [ColorRankData] = []
    
    @Published var customerAnalysis: [CustomerAnalysisData] = []
    @Published var selectedCustomerName: String? = nil
    @Published var customerSummaryData = BusinessSummaryData()
    
    var wholesaleCustomerNames: [String] { Set(allOrders.filter { $0.customerType == .wholesale }.map { $0.customerName }).sorted() }
    
    var selectedDateLabel: String {
        if let range = customDateRange { let formatter = DateFormatter(); formatter.dateFormat = "yyyy.MM.dd"; return "\(formatter.string(from: range.lowerBound)) - \(formatter.string(from: range.upperBound))" }
        let calendar = Calendar.current; let today = Date.now
        switch granularity {
        case .day: if calendar.isDateInToday(selectedDate) { return "今天" }; if calendar.isDateInYesterday(selectedDate) { return "昨天" }; return selectedDate.formatted(.dateTime.year().month().day())
        case .week: if calendar.isDate(selectedDate, equalTo: today, toGranularity: .weekOfYear) { return "本周" }; if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: today), calendar.isDate(selectedDate, equalTo: lastWeek, toGranularity: .weekOfYear) { return "上周" }; let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate)!; let start = weekInterval.start.formatted(.dateTime.month().day()); let end = weekInterval.end.addingTimeInterval(-1).formatted(.dateTime.month().day()); return "\(start) - \(end)"
        case .month: if calendar.isDate(selectedDate, equalTo: today, toGranularity: .month) { return "\(selectedDate.formatted(.dateTime.year().month())) (本月)" }; return selectedDate.formatted(.dateTime.year().month())
        case .quarter: let year = selectedDate.formatted(.dateTime.year()); let quarter = (Calendar.current.component(.month, from: selectedDate) - 1) / 3 + 1; return "\(year) Q\(quarter)"
        case .year: if calendar.isDate(selectedDate, equalTo: today, toGranularity: .year) { return "\(selectedDate.formatted(.dateTime.year())) (本年)"}; return selectedDate.formatted(.dateTime.year())
        }
    }
    
    private var allOrders: [Order]
    private var cancellables = Set<AnyCancellable>()

    init(orders: [Order]) {
        // 在初始化时，就过滤掉所有已退款的订单
        self.allOrders = orders.filter { $0.status ?? .active == .active }
        
        let trigger = PassthroughSubject<Void, Never>()
        $granularity.sink { _ in trigger.send() }.store(in: &cancellables)
        $selectedDate.sink { _ in trigger.send() }.store(in: &cancellables)
        $customDateRange.sink { _ in trigger.send() }.store(in: &cancellables)
        $customerType.sink { _ in trigger.send() }.store(in: &cancellables)
        $comparisonType.sink { _ in trigger.send() }.store(in: &cancellables)
        $selectedCustomerName.sink { _ in trigger.send() }.store(in: &cancellables)
        trigger.debounce(for: .milliseconds(100), scheduler: DispatchQueue.main).sink { [weak self] in self?.calculateAllData() }.store(in: &cancellables)
        calculateAllData()
    }
    
    func moveToNextPeriod() {
        let component: Calendar.Component = { switch self.granularity { case .day: return .day; case .week: return .weekOfYear; case .month: return .month; case .quarter: return .month; case .year: return .year } }()
        let value = (granularity == .quarter) ? 3 : 1
        if let nextDate = Calendar.current.date(byAdding: component, value: value, to: selectedDate) { selectedDate = nextDate }
    }
    
    func moveToPreviousPeriod() {
        let component: Calendar.Component = { switch self.granularity { case .day: return .day; case .week: return .weekOfYear; case .month: return .month; case .quarter: return .month; case .year: return .year } }()
        let value = (granularity == .quarter) ? -3 : -1
        if let prevDate = Calendar.current.date(byAdding: component, value: value, to: selectedDate) { selectedDate = prevDate }
    }
    
    private func calculateAllData() {
        let (currentRange, previousRange) = getDateRangesForKPIs()
        let kpiOrders = filterOrders(in: currentRange)
        calculateBusinessSummary(currentOrders: kpiOrders, previousRange: previousRange)
        calculateProductAnalysis(orders: kpiOrders)
        calculateCustomerAnalysis()
        generateChartData(for: granularity)
    }

    private func calculateBusinessSummary(currentOrders: [Order], previousRange: DateInterval?) {
        let currentSummary = calculateSummary(for: currentOrders)
        if comparisonType != .none, let prevRange = previousRange {
            let previousOrders = filterOrders(in: prevRange); let previousSummary = calculateSummary(for: previousOrders)
            summaryData = BusinessSummaryData(revenue: currentSummary.revenue, orderCount: currentSummary.orderCount, unitsSold: currentSummary.unitsSold, customerCount: currentSummary.customerCount, previousRevenue: previousSummary.revenue, previousOrderCount: previousSummary.orderCount, previousUnitsSold: previousSummary.unitsSold, previousCustomerCount: previousSummary.customerCount)
        } else { summaryData = currentSummary }
    }
    
    private func calculateProductAnalysis(orders: [Order]) {
        var productDict: [String: ProductAnalysisData] = [:]; var sizeDict: [String: Int] = [:]; var colorDict: [String: Int] = [:]
        for order in orders { for item in order.orderItems {
            var product = productDict[item.productName, default: ProductAnalysisData(id: item.productName, productName: item.productName)]; product.totalQuantity += item.totalItemQuantity; product.totalRevenue += item.totalItemPrice; productDict[item.productName] = product
            colorDict[item.color, default: 0] += item.totalItemQuantity
            for (size, quantity) in item.sizeQuantities { sizeDict[size, default: 0] += quantity }
        }}
        
        self.productAnalysisByRevenue = productDict.values.sorted { $0.totalRevenue > $1.totalRevenue }
        self.productAnalysisByQuantity = productDict.values.sorted { $0.totalQuantity > $1.totalQuantity }
        self.colorRanking = colorDict.map { ColorRankData(id: $0.key, color: $0.key, quantity: $0.value) }.sorted { $0.quantity > $1.quantity }
        self.sizeRanking = sizeDict.map { SizeRankData(id: $0.key, size: $0.key, quantity: $0.value) }.sorted { $0.quantity > $1.quantity }
    }
    
    private func calculateCustomerAnalysis() {
        let wholesaleOrders = allOrders.filter { $0.customerType == .wholesale }
        let customerOrders: [Order] = selectedCustomerName != nil ? wholesaleOrders.filter { $0.customerName == selectedCustomerName } : wholesaleOrders
        self.customerSummaryData = calculateSummary(for: customerOrders)
        
        let groupedByCustomer = Dictionary(grouping: wholesaleOrders, by: { $0.customerName }); let monthFormatter = DateFormatter(); monthFormatter.dateFormat = "yyyy-MM"; var finalAnalysis: [CustomerAnalysisData] = []
        for (name, orders) in groupedByCustomer {
            let groupedByMonth = Dictionary(grouping: orders, by: { monthFormatter.string(from: $0.date) }); var monthlyDataList: [MonthlyCustomerData] = []
            for (monthStr, monthOrders) in groupedByMonth {
                var productTally: [String: Int] = [:]; for order in monthOrders { for item in order.orderItems { productTally[item.productName, default: 0] += item.totalItemQuantity } }
                if let monthDate = monthFormatter.date(from: monthStr) {
                    monthlyDataList.append(MonthlyCustomerData(id: monthStr, month: monthDate, orderCount: monthOrders.count, unitsSold: monthOrders.reduce(0){$0 + $1.totalOrderQuantity}, revenue: monthOrders.reduce(0){$0 + $1.totalOrderPrice}, topProducts: productTally.sorted{$0.value > $1.value}.prefix(3).map{$0.key}))
                }
            }
            finalAnalysis.append(CustomerAnalysisData(customerName: name, monthlyData: monthlyDataList.sorted{$0.month > $1.month}))
        }
        self.customerAnalysis = finalAnalysis.sorted{$0.customerName < $1.customerName}
    }

    private func generateChartData(for granularity: TimeGranularity) {
        let calendar = Calendar.current
        let components: Set<Calendar.Component>
        
        switch granularity {
        case .day:
            components = [.year, .month, .day]
        case .week:
            components = [.yearForWeekOfYear, .weekOfYear]
        case .month:
            components = [.year, .month]
        case .quarter:
            components = [.year, .quarter]
        case .year:
            components = [.year]
        }
        
        let ordersForChart = allOrders
        
        guard !ordersForChart.isEmpty else {
            self.chartData = []
            return
        }

        let groupedOrders = Dictionary(grouping: ordersForChart) { order in
            let dateComponents = calendar.dateComponents(components, from: order.date)
            return calendar.date(from: dateComponents) ?? calendar.startOfDay(for: order.date)
        }
        
        var aggregatedData: [ChartSegment] = []
        
        for (date, orders) in groupedOrders {
            let totalValue = orders.reduce(0) { $0 + $1.totalOrderPrice }
            let unitCount = orders.reduce(0) { $0 + $1.totalOrderQuantity }
            
            let retailOrders = orders.filter { $0.customerType == .retail }
            let wholesaleOrders = orders.filter { $0.customerType == .wholesale }
            
            let retailValue = retailOrders.reduce(0) { $0 + $1.totalOrderPrice }
            let wholesaleValue = wholesaleOrders.reduce(0) { $0 + $1.totalOrderPrice }
            
            let segment = ChartSegment(
                id: date,
                date: date,
                totalValue: totalValue,
                retailValue: retailValue,
                wholesaleValue: wholesaleValue,
                orderCount: orders.count,
                unitCount: unitCount,
                retailOrderCount: retailOrders.count,
                wholesaleOrderCount: wholesaleOrders.count
            )
            aggregatedData.append(segment)
        }
        
        self.chartData = aggregatedData.sorted { $0.date < $1.date }
    }
    
    private func getDateRangesForKPIs() -> (DateInterval, DateInterval?) {
        if let customRange = customDateRange {
            let endOfDay = Calendar.current.startOfDay(for: customRange.upperBound).addingTimeInterval(24 * 60 * 60 - 1)
            return (DateInterval(start: customRange.lowerBound, end: endOfDay), nil)
        }
        
        let component: Calendar.Component = granularity.calendarComponent
        if component == .day { // Day logic is simpler
            let dayInterval = Calendar.current.dateInterval(of: .day, for: selectedDate)!
            var previousRange: DateInterval? = nil
            if comparisonType == .periodOverPeriod, let prevDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                previousRange = Calendar.current.dateInterval(of: .day, for: prevDate)
            }
            if comparisonType == .yearOverYear, let prevDate = Calendar.current.date(byAdding: .year, value: -1, to: selectedDate) {
                previousRange = Calendar.current.dateInterval(of: .day, for: prevDate)
            }
            return (dayInterval, previousRange)
        }
        
        let calendar = Calendar.current
        guard let currentRange = calendar.dateInterval(of: component, for: selectedDate) else { return (DateInterval(), nil) }
        
        var previousRange: DateInterval? = nil
        if comparisonType == .periodOverPeriod {
            let moveValue = (component == .quarter) ? -3 : -1
            let componentToMove = (component == .quarter) ? .month : component
            if let prevDate = calendar.date(byAdding: componentToMove, value: moveValue, to: selectedDate) {
                previousRange = calendar.dateInterval(of: component, for: prevDate)
            }
        } else if comparisonType == .yearOverYear {
            if let prevDate = calendar.date(byAdding: .year, value: -1, to: selectedDate) {
                previousRange = calendar.dateInterval(of: component, for: prevDate)
            }
        }
        
        return (currentRange, previousRange)
    }

    private func filterOrders(in interval: DateInterval) -> [Order] {
        allOrders.filter { interval.contains($0.date) && (customerType == nil || $0.customerType == customerType) }
    }
    
    private func calculateSummary(for orders: [Order]) -> BusinessSummaryData {
        BusinessSummaryData(revenue: orders.reduce(0, {$0 + $1.totalOrderPrice}), orderCount: orders.count, unitsSold: orders.reduce(0, {$0 + $1.totalOrderQuantity}), customerCount: Set(orders.map({$0.customerName})).count)
    }
}
