// UserSettings.swift

import Foundation
import Combine

// 一个遵循 ObservableObject 协议的类，用于管理所有用户可配置的设置。
// @MainActor 确保所有对 @Published 属性的更新都在主线程上进行。
@MainActor
class UserSettings: ObservableObject {
    
    // 我们将使用这个 key 在 UserDefaults 中存储用户的字体缩放设置
    private let fontScaleMultiplierKey = "userFontScaleMultiplier"
    
    // 使用 @Published 属性包装器，这样任何监听此对象的 SwiftUI 视图都会在它改变时自动刷新。
    @Published var fontScaleMultiplier: Double {
        didSet {
            // 每当 fontScaleMultiplier 的值被改变时，我们就将新值保存到 UserDefaults。
            UserDefaults.standard.set(fontScaleMultiplier, forKey: fontScaleMultiplierKey)
        }
    }
    
    init() {
        // 在类初始化时，我们尝试从 UserDefaults 加载之前保存的设置。
        // 如果找不到（比如用户第一次打开App），就使用默认值 1.0。
        let savedMultiplier = UserDefaults.standard.double(forKey: fontScaleMultiplierKey)
        
        // UserDefaults 在找不到 double 值时会返回 0.0，所以我们需要检查一下。
        if savedMultiplier == 0.0 {
            self.fontScaleMultiplier = 1.0
        } else {
            self.fontScaleMultiplier = savedMultiplier
        }
    }
}
