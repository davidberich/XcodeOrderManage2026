// Extensions.swift

import SwiftUI

// 这个文件专门存放所有通用的 SwiftUI 扩展

// MARK: - Binding<String?>
extension Binding where Value == String? {
    /// 将一个可选的 String 绑定转换为非可选的 String 绑定。
    ///
    /// 这对于需要 String 绑定的 TextField 视图非常有用。
    /// 当 TextField 为空时，绑定的原始值会变为 nil。
    func toNonOptional() -> Binding<String> {
        return Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Binding<String>
extension Binding where Value == String {
    /// 将一个非可选的 String 绑定转换为可选的 String 绑定。
    ///
    /// 这在需要将一个非可选的状态变量与一个期望可选绑定的视图组件连接时很有用。
    func toOptional() -> Binding<String?> {
        return Binding<String?>(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 ?? "" }
        )
    }
}

// MARK: - Binding<ProductType?>
extension Binding {
    /// 通用扩展，将任何可选类型的绑定转换为一个有默认值的非可选绑定。
    ///
    /// 示例: `productType.toUnwrapped(defaultValue: .custom)`
    func toUnwrapped<T>(defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}
