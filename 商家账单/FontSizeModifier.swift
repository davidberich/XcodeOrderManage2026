import SwiftUI

// 回归到最简单的实现：接收一个具体的 size 值
struct ScaledFont: ViewModifier {
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content.font(.system(size: size))
    }
}

extension View {
    // 扩展方法也回归简单
    func scaledFont(size: CGFloat) -> some View {
        self.modifier(ScaledFont(size: size))
    }
}

// 这个 Manager 保持不变，它的计算逻辑是正确的
struct FontSizeManager {
    static let baseScreenWidth: CGFloat = 390
    
    static func scaledSize(for style: Font.TextStyle, in screenWidth: CGFloat, multiplier: Double) -> CGFloat {
        let scale = screenWidth / baseScreenWidth
        let baseSize = UIFont.preferredFont(forTextStyle: style.toUIFontTextStyle()).pointSize
        return (baseSize * scale) * multiplier
    }
}

extension Font.TextStyle {
    func toUIFontTextStyle() -> UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default:
            return .body
        }
    }
}
