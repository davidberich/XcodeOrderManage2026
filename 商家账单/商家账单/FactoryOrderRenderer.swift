// FactoryOrderRenderer.swift
import SwiftUI

// --- 1. 仅用于渲染的 SwiftUI 视图模板 ---
struct FactoryOrderExportView: View {
    let order: Order
    let textContent: String
    
    private var allImageIds: [String] {
        order.orderItems.flatMap { $0.productImageIdentifiers }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(allImageIds, id: \.self) { imageId in
                if let uiImage = ImageStore.shared.loadImage(withIdentifier: imageId) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
            }
            
            Divider().padding(.vertical, 8)
            
            Text(textContent)
                .font(.body)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom)
        .frame(width: UIScreen.main.bounds.width)
        .background(Color.white)
    }
}


// --- 2. 图片生成器 ---
@MainActor
class FactoryOrderImageGenerator {
    static let shared = FactoryOrderImageGenerator()

    private init() {}
    
    func generate(for order: Order, textContent: String) -> UIImage? {
        let viewToRender = FactoryOrderExportView(order: order, textContent: textContent)
        
        let controller = UIHostingController(rootView: viewToRender)
        guard let view = controller.view else { return nil }
        
        let targetSize = view.intrinsicContentSize
        view.bounds = CGRect(origin: .zero, size: targetSize)
        view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        
        return image
    }
}
