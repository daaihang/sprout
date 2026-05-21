import Foundation
import SwiftUI
import UIKit

enum CaptureMapLegibilityStyle: String, Hashable, Sendable {
    case lightText
    case darkText
    case fallback

    static func resolve(snapshotData: Data?) -> CaptureMapLegibilityStyle {
        guard let snapshotData,
              let image = UIImage(data: snapshotData) else {
            return .fallback
        }
        return resolve(image: image)
    }

    static func resolve(image: UIImage) -> CaptureMapLegibilityStyle {
        guard let luminance = averageBottomLuminance(image: image) else {
            return .fallback
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

enum CaptureCardLegibilityTone: String, Hashable, Sendable {
    case lightText
    case darkText
    case semantic
}

struct CaptureCardLegibility {
    let tone: CaptureCardLegibilityTone
    let primaryText: Color
    let secondaryText: Color
    let shadow: Color
    let scrimColors: [Color]

    static func lightText(highContrast: Bool) -> CaptureCardLegibility {
        CaptureCardLegibility(
            tone: .lightText,
            primaryText: .white,
            secondaryText: .white.opacity(highContrast ? 0.94 : 0.78),
            shadow: .black.opacity(highContrast ? 0.46 : 0.28),
            scrimColors: [.clear, .black.opacity(highContrast ? 0.68 : 0.46)]
        )
    }

    static func darkText(highContrast: Bool) -> CaptureCardLegibility {
        CaptureCardLegibility(
            tone: .darkText,
            primaryText: .black.opacity(0.9),
            secondaryText: .black.opacity(highContrast ? 0.82 : 0.64),
            shadow: .white.opacity(highContrast ? 0.28 : 0.18),
            scrimColors: [.clear, .white.opacity(highContrast ? 0.78 : 0.58)]
        )
    }

    static func semantic(highContrast: Bool) -> CaptureCardLegibility {
        CaptureCardLegibility(
            tone: .semantic,
            primaryText: .primary,
            secondaryText: .secondary,
            shadow: .clear,
            scrimColors: [.clear, .black.opacity(highContrast ? 0.24 : 0.12)]
        )
    }

    static func imageData(_ data: Data?, highContrast: Bool) -> CaptureCardLegibility {
        guard let data,
              let imageObject = UIImage(data: data) else {
            return lightText(highContrast: highContrast)
        }
        return image(imageObject, highContrast: highContrast)
    }

    static func image(_ image: UIImage, highContrast: Bool) -> CaptureCardLegibility {
        switch CaptureMapLegibilityStyle.resolve(image: image) {
        case .lightText:
            return lightText(highContrast: highContrast)
        case .darkText:
            return darkText(highContrast: highContrast)
        case .fallback:
            return semantic(highContrast: highContrast)
        }
    }

    static func map(snapshotData: Data?, isPrivacyEnabled: Bool, highContrast: Bool) -> CaptureCardLegibility {
        guard !isPrivacyEnabled else {
            return semantic(highContrast: highContrast)
        }
        switch CaptureMapLegibilityStyle.resolve(snapshotData: snapshotData) {
        case .lightText:
            return lightText(highContrast: highContrast)
        case .darkText:
            return darkText(highContrast: highContrast)
        case .fallback:
            return semantic(highContrast: highContrast)
        }
    }

    static func weather(style: CaptureWeatherVisualStyle, highContrast: Bool) -> CaptureCardLegibility {
        switch style {
        case .clearNight, .rain, .heavyRain, .thunderstorm:
            return lightText(highContrast: highContrast)
        case .sunny, .cloudy, .snow, .fog, .wind, .hot, .cold:
            return darkText(highContrast: highContrast)
        case .unknown:
            return semantic(highContrast: highContrast)
        }
    }

    static func palette(_ palette: CaptureCardPalette, highContrast: Bool) -> CaptureCardLegibility {
        CaptureCardLegibility(
            tone: .semantic,
            primaryText: palette.primaryText,
            secondaryText: palette.secondaryText,
            shadow: .black.opacity(highContrast ? 0.32 : 0.18),
            scrimColors: palette.scrim
        )
    }
}
