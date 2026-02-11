// Date+Extensions.swift

import Foundation

extension Date {
    /// 将日期格式化为 "yyyy年MM月dd日" 格式的字符串
    func formattedAsYMD() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }

    /// 将日期格式化为 "yyyy/MM/dd" 格式的字符串
    func formattedAsYMDWithSlash() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }
    
    func formattedAsShortDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: self)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
