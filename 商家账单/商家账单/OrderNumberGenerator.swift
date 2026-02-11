
//OrderNumberGenerator

import Foundation

class OrderNumberGenerator {
    
    static let shared = OrderNumberGenerator()

    private let userDefaults = UserDefaults.standard
    private let lastOrderDateKey = "lastOrderDate_v2" // 使用新key避免与旧数据冲突
    private let dailyCounterKey = "dailyCounter_v2"

    private init() {}

    // MARK: - 主要生成函数
    
    /// 为当天生成一个新的、递增的订单号。
    func generateNewOrderNumber() -> String {
        return generateNewOrderNumber(for: Date())
    }
    
    /// 为指定的日期生成一个新的订单号。
    /// 这个函数会检查并更新 UserDefaults，以确保同一天的订单号是连续的。
    func generateNewOrderNumber(for date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        
        let targetDateString = dateFormatter.string(from: date)
        let lastOrderDateString = userDefaults.string(forKey: lastOrderDateKey) ?? ""
        
        var currentCounter = userDefaults.integer(forKey: dailyCounterKey)

        if targetDateString == lastOrderDateString {
            // 如果是同一天，计数器加1
            currentCounter += 1
        } else {
            // 如果是新的一天，计数器重置为1
            currentCounter = 1
        }
        
        // 保存新的日期和计数器
        userDefaults.set(targetDateString, forKey: lastOrderDateKey)
        userDefaults.set(currentCounter, forKey: dailyCounterKey)
        
        // 格式化订单号，例如：20231027-001
        let formattedCounter = String(format: "%03d", currentCounter)
        return "\(targetDateString)-\(formattedCounter)"
    }

    // MARK: - 测试数据专用生成函数
    
    /// 为测试数据生成一个不依赖 UserDefaults 的订单号。
    /// - Parameters:
    ///   - date: 订单的日期。
    ///   - dailyCounter: 当天的序列号，以确保唯一性。
    func generateNewOrderNumber(for date: Date, dailyCounter: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        
        // 直接使用传入的 dailyCounter，不与 UserDefaults 交互
        let formattedCounter = String(format: "%03d", dailyCounter + 1)
        return "\(dateString)-\(formattedCounter)"
    }
}
