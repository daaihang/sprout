import Foundation
import UIKit

enum CaptureMapLegibilityStyle: String, Hashable, Sendable {
    case lightText
    case darkText
    case materialFallback

    static func resolve(snapshotData: Data?) -> CaptureMapLegibilityStyle {
        guard let snapshotData,
              let image = UIImage(data: snapshotData) else {
            return .materialFallback
        }
        return resolve(image: image)
    }

    static func resolve(image: UIImage) -> CaptureMapLegibilityStyle {
        guard let luminance = averageBottomLuminance(image: image) else {
            return .materialFallback
        }
        return luminance < 0.56 ? .lightText : .darkText
    }

    static func averageBottomLuminance(image: UIImage) -> Double? {
        guard let cgImage = image.cgImage else { return nil }

        let width = max(1, min(24, cgImage.width))
        let height = max(1, min(16, cgImage.height))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let bottomBandOriginY = Int(Double(cgImage.height) * 0.54)
        let bottomBandHeight = max(1, cgImage.height - bottomBandOriginY)
        let bottomBandRect = CGRect(
            x: 0,
            y: bottomBandOriginY,
            width: cgImage.width,
            height: bottomBandHeight
        )

        guard let bottomBandImage = cgImage.cropping(to: bottomBandRect) else {
            return nil
        }

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(bottomBandImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total = 0.0
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Double(pixels[index]) / 255.0
            let green = Double(pixels[index + 1]) / 255.0
            let blue = Double(pixels[index + 2]) / 255.0
            total += 0.2126 * red + 0.7152 * green + 0.0722 * blue
        }
        return total / Double(width * height)
    }
}
