// FullScreenImageViewer.swift
import SwiftUI

// 一个通用的、可包含自定义工具栏操作的全屏图片预览器
struct FullScreenImageViewer<Toolbar: View>: View {
    @Environment(\.presentationMode) var presentationMode
    
    let image: UIImage
    let toolbarContent: Toolbar

    init(image: UIImage, @ViewBuilder toolbarContent: () -> Toolbar) {
        self.image = image
        self.toolbarContent = toolbarContent()
    }

    var body: some View {
        // 使用 NavigationView 来方便地添加导航栏和按钮
        NavigationView {
            // 使用 ScrollView 来确保长图可以完整滚动查看
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .background(Color.black) // 设置黑色背景
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左侧关闭按钮
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                // 右侧自定义操作按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarContent
                }
            }
        }
    }
}
