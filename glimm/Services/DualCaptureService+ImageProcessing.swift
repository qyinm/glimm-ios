//
//  DualCaptureService+ImageProcessing.swift
//  glimm
//

import UIKit

extension DualCaptureService {
    func compositeImages(main: UIImage, pip: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: main.size)
        return renderer.image { ctx in
            // Draw main image full size
            main.draw(in: CGRect(origin: .zero, size: main.size))

            // Calculate PIP size and position (top-right, ~30% width)
            let pipWidth = main.size.width * 0.3
            let pipHeight = pipWidth * (pip.size.height / pip.size.width)
            let margin: CGFloat = 16 * (main.size.width / 390) // Scale margin relative
            let pipRect = CGRect(
                x: main.size.width - pipWidth - margin,
                y: margin,
                width: pipWidth,
                height: pipHeight
            )

            let cornerRadius: CGFloat = 16 * (main.size.width / 390)

            ctx.cgContext.saveGState()
            let clipPath = UIBezierPath(roundedRect: pipRect, cornerRadius: cornerRadius)
            clipPath.addClip()
            pip.draw(in: pipRect)
            ctx.cgContext.restoreGState()
        }
    }

    #if targetEnvironment(simulator)
    static func simulatorPlaceholderImage() -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let text = "glimm simulator camera"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 56, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let textSize = text.size(withAttributes: attributes)
            let origin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: origin, withAttributes: attributes)
        }
    }
    #endif
}
