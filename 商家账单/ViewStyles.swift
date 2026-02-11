
//ViewStyles.swift

import SwiftUI

// 将按钮样式定义在自己的文件中，以便整个 App 都可以访问
struct FactoryOrderButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .foregroundColor(.white)
            .background(isEnabled ? Color.accentColor : Color.gray) // 可用时为蓝色，禁用时为灰色
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}


// <<< 核心修复点 1: 在这里定义全局可用的 statusTag 函数 >>>
@ViewBuilder
func statusTag(text: String, color: Color, backgroundColor: Color) -> some View {
    Text(text)
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(backgroundColor, in: Capsule())
}
