// ImageGalleryView.swift

import SwiftUI

struct ImageGalleryView: View {
    // 绑定当前显示的订单，当设为 nil 时，视图消失
    @Binding var selectedOrder: Order?
    
    // 动画命名空间
    var namespace: Namespace.ID

    // 当前页面的ID，通过 @State 和 .scrollPosition 实现双向绑定
    @State private var currentPageId: String?
    
    // 手势状态
    @State private var dragOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = 1.0

    // 计算属性，获取所有图片ID
    private var allImageIds: [String] {
        selectedOrder?.orderItems.flatMap { $0.productImageIdentifiers } ?? []
    }

    var body: some View {
        ZStack {
            // 半透明背景，点击可关闭
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture(perform: closeGallery)

            VStack(spacing: 0) {
                // --- 关闭按钮 ---
                HStack {
                    Spacer()
                    Button(action: closeGallery) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding()
                .opacity(backgroundOpacity)

                Spacer()

                // --- 主图区域：使用带 .scrollPosition 绑定的 ScrollView ---
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(allImageIds, id: \.self) { imageId in
                            if let image = ImageStore.shared.loadImage(withIdentifier: imageId) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .matchedGeometryEffect(id: "image_\(imageId)", in: namespace)
                                    .containerRelativeFrame(.horizontal)
                                    .id(imageId) // 必须有 ID 才能被 scrollPosition 追踪
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging) // 开启分页滚动效果
                .scrollIndicators(.hidden) // 隐藏滚动条
                .scrollPosition(id: $currentPageId, anchor: .center) // 双向绑定滚动位置和状态
                .offset(y: dragOffset.height) // 跟随手势垂直移动
                
                Spacer()

                // --- 缩略图预览条 ---
                thumbnailScrollView
                    .opacity(backgroundOpacity)
            }
        }
        .gesture(
            DragGesture()
                .onChanged(handleDragChanged)
                .onEnded(handleDragEnded)
        )
        .onAppear {
            if currentPageId == nil {
                currentPageId = allImageIds.first
            }
        }
    }
    
    // --- 缩略图滚动视图 ---
    @ViewBuilder
    private var thumbnailScrollView: some View {
        // 只有多于一张图时才显示
        if allImageIds.count > 1 {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(allImageIds, id: \.self) { imageId in
                            if let image = ImageStore.shared.loadImage(withIdentifier: imageId) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .id(imageId) // ID for ScrollViewReader
                                    .overlay(
                                        // 高亮当前选中的缩略图
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(currentPageId == imageId ? Color.white : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        // 点击小图，直接更新 currentPageId
                                        // 主 ScrollView 会因为绑定而自动滚动
                                        withAnimation(.spring()) {
                                            currentPageId = imageId
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 70)
                .onChange(of: currentPageId) { _, newId in
                    // 当 currentPageId 改变时（无论是滑动主图还是点击小图），
                    // 都让缩略图列表滚动到对应位置
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }
    
    // --- 手势处理函数 ---
    private func handleDragChanged(_ value: DragGesture.Value) {
        // 只响应向下的拖动
        if value.translation.height > 0 {
            dragOffset = value.translation
            // 根据拖动距离计算背景透明度
            let dragDistance = value.translation.height
            backgroundOpacity = max(0, 1 - (dragDistance / 400))
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let dragDistance = value.translation.height
        // 如果拖动距离超过阈值，则关闭
        if dragDistance > 100 {
            closeGallery()
        } else {
            // 否则，弹回原位
            withAnimation(.interactiveSpring()) {
                dragOffset = .zero
                backgroundOpacity = 1.0
            }
        }
    }

    // --- 关闭画廊的函数 ---
    private func closeGallery() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            dragOffset = .zero
            backgroundOpacity = 0
            selectedOrder = nil
        }
    }
}
