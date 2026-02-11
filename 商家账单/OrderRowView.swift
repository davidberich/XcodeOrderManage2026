// OrderRowView.swift
// 已修复编译错误

import SwiftUI

struct OrderRowView: View {
    let order: Order
    let screenWidth: CGFloat
    let fontScaleMultiplier: Double
    var onImageTapped: (Order) -> Void
    var namespace: Namespace.ID
    
    private let imageAreaWidth: CGFloat = 110

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            VStack(alignment: .leading, spacing: 6) {
                if order.customerName.isEmpty {
                    Text("客户名待填写")
                        .scaledFont(size: FontSizeManager.scaledSize(for: .headline, in: screenWidth, multiplier: fontScaleMultiplier))
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.red)
                } else {
                    Text(order.customerName)
                        .scaledFont(size: FontSizeManager.scaledSize(for: .headline, in: screenWidth, multiplier: fontScaleMultiplier))
                        .fontWeight(.semibold)
                        .lineLimit(2)
                }
                
                productNameListView
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("总数:")
                        Text("\(order.totalOrderQuantity)件")
                    }
                    
                    if !order.reworkItems.isEmpty {
                        // <<< 核心修复点 2: 现在编译器可以找到 statusTag 了 >>>
                        statusTag(text: "含返工", color: .white, backgroundColor: .purple)
                    }
                }
                .scaledFont(size: FontSizeManager.scaledSize(for: .caption, in: screenWidth, multiplier: fontScaleMultiplier))
                .foregroundColor(.secondary)
                .padding(.top, 2)

                salesAmountView
                
                Spacer(minLength: 0)
                
                Text(order.date.formattedAsYMD())
                    .scaledFont(size: FontSizeManager.scaledSize(for: .caption, in: screenWidth, multiplier: fontScaleMultiplier))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { onImageTapped(order) }) {
                imageStackView
            }
            .buttonStyle(.plain)
            .frame(width: imageAreaWidth, height: imageAreaWidth)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 5, y: 3)
    }
    
    @ViewBuilder
    private var salesAmountView: some View {
        HStack(spacing: 4) {
            Text("销售额:")
            
            if order.hasPendingPrice {
                (Text("¥\(String(format: "%.2f", order.totalOrderPrice))") + Text(" (单价待定)"))
                    .foregroundColor(.red)
            } else {
                Text("¥\(String(format: "%.2f", order.totalOrderPrice))")
            }
        }
        .foregroundColor(.secondary)
        .scaledFont(size: FontSizeManager.scaledSize(for: .caption, in: screenWidth, multiplier: fontScaleMultiplier))
        .fontWeight(.medium)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    
    @ViewBuilder
    private var imageStackView: some View {
        let identifiers = order.previewImageIdentifiers
        
        ZStack {
            if identifiers.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1))
                    Image(systemName: "photo.on.rectangle.angled").font(.title).foregroundColor(.gray.opacity(0.6))
                }
                .frame(width: imageAreaWidth, height: imageAreaWidth)
            } else {
                ForEach(Array(identifiers.prefix(3).reversed().enumerated()), id: \.element) { (index, imageId) in
                    if let uiImage = ImageStore.shared.loadImage(withIdentifier: imageId) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFill().frame(width: imageAreaWidth, height: imageAreaWidth)
                            .cornerRadius(8).clipped()
                            .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                            .offset(x: CGFloat(index) * -5, y: CGFloat(index) * -5)
                            .matchedGeometryEffect(
                                id: (index == (identifiers.prefix(3).count - 1)) ? "image_\(imageId)" : "image_bg_\(imageId)",
                                in: namespace
                            )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var productNameListView: some View {
        let items = order.orderItems
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                    if index == 2 && items.count > 3 {
                        (Text(item.productName) + Text(" 等 共计 \(items.count)款").foregroundColor(.gray))
                            .font(.system(size: FontSizeManager.scaledSize(for: .caption, in: screenWidth, multiplier: fontScaleMultiplier)))
                            .foregroundColor(.secondary).lineLimit(1)
                    } else {
                        Text(item.productName)
                            .scaledFont(size: FontSizeManager.scaledSize(for: .caption, in: screenWidth, multiplier: fontScaleMultiplier))
                            .foregroundColor(.secondary).lineLimit(1)
                    }
                }
            }
        }
    }
}
