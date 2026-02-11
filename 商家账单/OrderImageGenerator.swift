// OrderImageGenerator.swift

import UIKit

class OrderImageGenerator {
    static let shared = OrderImageGenerator()
    private let renderWidth: CGFloat = 800
    private let padding: CGFloat = 30
    
    private let textFontSize: CGFloat = 64.0
    private let urgentTextFontSize: CGFloat = 76.0

    private init() {}
    
    func generate(for order: Order, productImages: [UIImage], textContent: String) -> UIImage? {
        guard let textImage = renderTextToImage(for: order, textContent: textContent) else {
            print("Error: Failed to render text to image.")
            return nil
        }
        
        return stitchImages(productImages: productImages, textImage: textImage)
    }

    private func renderTextToImage(for order: Order, textContent: String) -> UIImage? {
        // --- 准备样式 ---
        let normalParagraphStyle = NSMutableParagraphStyle()
        normalParagraphStyle.lineSpacing = 12
        
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "PingFangSC-Regular", size: textFontSize) ?? UIFont.systemFont(ofSize: textFontSize),
            .paragraphStyle: normalParagraphStyle,
            .foregroundColor: UIColor.black
        ]
        
        let urgentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "PingFangSC-Semibold", size: urgentTextFontSize) ?? UIFont.boldSystemFont(ofSize: urgentTextFontSize),
            .paragraphStyle: normalParagraphStyle,
            .foregroundColor: UIColor.red
        ]
        
        // --- 构建富文本 (NSMutableAttributedString) ---
        // 1. 先用普通样式创建整个文本
        let finalAttributedString = NSMutableAttributedString(string: textContent, attributes: normalAttributes)
        
        // 2. 如果是加急订单，在整个富文本中查找“订单加急！”并应用特殊样式
        if order.urgency == .urgent {
            let urgentText = "订单加急！"
            // 使用 NSString 的 range(of:) 方法来查找子字符串的位置
            let range = (textContent as NSString).range(of: urgentText)
            
            // 如果找到了匹配的范围
            if range.location != NSNotFound {
                // 在该范围上应用加急样式
                finalAttributedString.addAttributes(urgentAttributes, range: range)
            }
        }
        
        // --- 渲染图片 ---
        let textMaxWidth = renderWidth - (padding * 2)
        let textRect = finalAttributedString.boundingRect(with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
        let imageSize = CGSize(width: renderWidth, height: ceil(textRect.height) + (padding * 2))
        
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
            let borderPath = UIBezierPath(rect: CGRect(origin: .zero, size: imageSize))
            UIColor.black.setStroke()
            borderPath.lineWidth = 2.5
            borderPath.stroke()
            finalAttributedString.draw(in: CGRect(x: padding, y: padding, width: textMaxWidth, height: textRect.height))
        }
    }
    
    private func stitchImages(productImages: [UIImage], textImage: UIImage) -> UIImage? {
        let finalWidth = textImage.size.width
        let resizedProductImages = productImages.map { img -> UIImage in
            let scale = finalWidth / img.size.width
            let newHeight = img.size.height * scale
            let newSize = CGSize(width: finalWidth, height: newHeight)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
        }
        let totalHeight = resizedProductImages.reduce(0) { $0 + $1.size.height } + textImage.size.height
        guard totalHeight > 0, finalWidth > 0 else { return nil }
        let finalSize = CGSize(width: finalWidth, height: totalHeight)
        let renderer = UIGraphicsImageRenderer(size: finalSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: finalSize))
            var currentY: CGFloat = 0
            for image in resizedProductImages {
                image.draw(at: CGPoint(x: 0, y: currentY))
                currentY += image.size.height
            }
            textImage.draw(at: CGPoint(x: 0, y: currentY))
        }
    }
}
