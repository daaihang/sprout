import CoreImage
import SwiftUI
import UIKit

enum CaptureCardPaletteSource: String, Hashable, Sendable {
    case fallback
    case weather
    case map
    case photoSample
    case musicArtwork
}

struct CaptureCardPalette {
    let source: CaptureCardPaletteSource
    let accent: Color
    let background: [Color]
    let primaryText: Color
    let secondaryText: Color
    let selectionStroke: Color
    let controlTint: Color
    let scrim: [Color]

    static func resolve(
        for item: CaptureCardItem,
        highContrast: Bool,
        mapLegibility: CaptureMapLegibilityStyle = .fallback
    ) -> CaptureCardPalette {
        switch item.payload {
        case let .photo(payload):
            if let hex = payload.thumbnailData.flatMap(sampleHexColor(from:)) {
                return fromHex(
                    source: .photoSample,
                    backgroundHex: hex,
                    fallbackAccent: fallbackAccent(for: item.kind),
                    highContrast: highContrast
                )
            }
            return fallback(kind: item.kind, highContrast: highContrast)
        case .place:
            return place(mapLegibility: mapLegibility, highContrast: highContrast)
        case let .weather(payload):
            return weather(style: payload.style ?? .unknown, highContrast: highContrast)
        case let .music(payload):
            if let palette = payload.artworkPalette,
               let backgroundHex = palette.backgroundColorHex {
                return fromHex(
                    source: .musicArtwork,
                    backgroundHex: backgroundHex,
                    primaryTextHex: palette.primaryTextColorHex,
                    secondaryTextHex: palette.secondaryTextColorHex,
                    fallbackAccent: fallbackAccent(for: item.kind),
                    highContrast: highContrast
                )
            }
            if let hex = payload.artworkData.flatMap(sampleHexColor(from:)) {
                return fromHex(
                    source: .musicArtwork,
                    backgroundHex: hex,
                    fallbackAccent: fallbackAccent(for: item.kind),
                    highContrast: highContrast
                )
            }
            return fallback(kind: item.kind, highContrast: highContrast)
        case .audio, .link, .todo, .prompt, .person, .affect, .status:
            return fallback(kind: item.kind, highContrast: highContrast)
        }
    }

    private static func fallback(kind: CaptureCardKind, highContrast: Bool) -> CaptureCardPalette {
        let accent = fallbackAccent(for: kind)
        return CaptureCardPalette(
            source: .fallback,
            accent: accent,
            background: [accent.opacity(highContrast ? 0.18 : 0.1), Color(.secondarySystemBackground).opacity(0.86)],
            primaryText: .primary,
            secondaryText: .secondary,
            selectionStroke: accent.opacity(highContrast ? 0.86 : 0.58),
            controlTint: accent,
            scrim: [.clear, .black.opacity(highContrast ? 0.28 : 0.16)]
        )
    }

    private static func weather(style: CaptureWeatherVisualStyle, highContrast: Bool) -> CaptureCardPalette {
        let colors: [Color]
        let accent: Color
        switch style.atmosphereSpec.palette {
        case .warmLight:
            colors = [
                Color(red: 0.56, green: 0.82, blue: 1.0),
                Color(red: 1.0, green: 0.83, blue: 0.42)
            ]
            accent = .orange
        case .night:
            colors = [
                Color(red: 0.05, green: 0.08, blue: 0.2),
                Color(red: 0.2, green: 0.19, blue: 0.38)
            ]
            accent = .indigo
        case .softCloud:
            colors = [
                Color(red: 0.62, green: 0.76, blue: 0.88),
                Color(red: 0.95, green: 0.97, blue: 0.98)
            ]
            accent = .cyan
        case .coolRain:
            colors = [
                Color(red: 0.24, green: 0.42, blue: 0.58),
                Color(red: 0.1, green: 0.19, blue: 0.31)
            ]
            accent = .blue
        case .storm:
            colors = [
                Color(red: 0.07, green: 0.1, blue: 0.18),
                Color(red: 0.2, green: 0.15, blue: 0.34)
            ]
            accent = .purple
        case .frost:
            colors = [
                Color(red: 0.72, green: 0.9, blue: 1.0),
                Color(red: 0.99, green: 1.0, blue: 1.0)
            ]
            accent = .cyan
        case .fog:
            colors = [
                Color(red: 0.7, green: 0.77, blue: 0.82),
                Color(red: 0.94, green: 0.95, blue: 0.94)
            ]
            accent = .gray
        case .wind:
            colors = [
                Color(red: 0.58, green: 0.86, blue: 0.92),
                Color(red: 0.96, green: 0.99, blue: 0.97)
            ]
            accent = .teal
        case .heat:
            colors = [
                Color(red: 1.0, green: 0.58, blue: 0.36),
                Color(red: 1.0, green: 0.9, blue: 0.58)
            ]
            accent = .red
        case .neutral:
            colors = [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)]
            accent = .cyan
        }
        return CaptureCardPalette(
            source: .weather,
            accent: accent,
            background: colors,
            primaryText: .primary,
            secondaryText: .secondary,
            selectionStroke: accent.opacity(highContrast ? 0.9 : 0.62),
            controlTint: accent,
            scrim: [.clear, .black.opacity(highContrast ? 0.24 : 0.12)]
        )
    }

    private static func place(mapLegibility: CaptureMapLegibilityStyle, highContrast: Bool) -> CaptureCardPalette {
        let accent = Color.green
        let primary: Color
        let secondary: Color
        switch mapLegibility {
        case .lightText:
            primary = .white
            secondary = .white.opacity(highContrast ? 0.92 : 0.78)
        case .darkText:
            primary = .black.opacity(0.88)
            secondary = .black.opacity(highContrast ? 0.78 : 0.62)
        case .fallback:
            primary = .primary
            secondary = .secondary
        }
        return CaptureCardPalette(
            source: .map,
            accent: accent,
            background: [accent.opacity(0.12), Color(.secondarySystemBackground)],
            primaryText: primary,
            secondaryText: secondary,
            selectionStroke: accent.opacity(highContrast ? 0.88 : 0.6),
            controlTint: accent,
            scrim: [.clear, .black.opacity(highContrast ? 0.38 : 0.22)]
        )
    }

    private static func fromHex(
        source: CaptureCardPaletteSource,
        backgroundHex: String,
        primaryTextHex: String? = nil,
        secondaryTextHex: String? = nil,
        fallbackAccent: Color,
        highContrast: Bool
    ) -> CaptureCardPalette {
        let background = Color(hex: backgroundHex) ?? fallbackAccent
        let primary = primaryTextHex.flatMap(Color.init(hex:)) ?? contrastTextColor(for: backgroundHex)
        let secondary = secondaryTextHex.flatMap(Color.init(hex:)) ?? primary.opacity(0.78)
        return CaptureCardPalette(
            source: source,
            accent: background,
            background: [background.opacity(0.92), background.opacity(0.58), Color(.secondarySystemBackground).opacity(0.72)],
            primaryText: primary,
            secondaryText: secondary,
            selectionStroke: background.opacity(highContrast ? 0.94 : 0.66),
            controlTint: background,
            scrim: [.clear, contrastScrimColor(for: backgroundHex).opacity(highContrast ? 0.44 : 0.24)]
        )
    }

    private static func fallbackAccent(for kind: CaptureCardKind) -> Color {
        switch kind {
        case .photo: return .pink
        case .audio: return .red
        case .place: return .green
        case .weather: return .cyan
        case .music: return .indigo
        case .link: return .blue
        case .todo: return .orange
        case .prompt: return .purple
        case .person: return .teal
        case .affect: return .pink
        case .status: return .secondary
        }
    }

    nonisolated private static func contrastTextColor(for hex: String) -> Color {
        (luminance(for: hex) ?? 0) > 0.54 ? .black.opacity(0.88) : .white
    }

    nonisolated private static func contrastScrimColor(for hex: String) -> Color {
        (luminance(for: hex) ?? 0) > 0.54 ? .white : .black
    }

    nonisolated private static func luminance(for hex: String) -> Double? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }

    nonisolated private static func sampleHexColor(from data: Data) -> String? {
        guard let image = UIImage(data: data),
              let inputImage = CIImage(image: image),
              let outputImage = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: inputImage,
                kCIInputExtentKey: CIVector(cgRect: inputImage.extent)
              ])?.outputImage else {
            return nil
        }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return String(format: "#%02X%02X%02X", bitmap[0], bitmap[1], bitmap[2])
    }
}

private extension Color {
    nonisolated init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
