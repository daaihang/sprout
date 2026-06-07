import SwiftUI
import UIKit

struct PlaceCaptureCardContent: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let common: CaptureCardCommonDisplay
    let payload: CapturePlaceCardPayload
    let context: CaptureCardRenderContext
    let accent: Color
    let highContrastOverride: Bool?

    @State private var generatedSnapshotData: Data?

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: "mappin.and.ellipse",
                title: placeTitle,
                subtitle: placeAddress,
                accent: accent,
                context: context
            )
        } else {
            ZStack(alignment: .bottomLeading) {
                mapImage
                LinearGradient(
                    colors: legibility.scrimColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(placeTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if context.isDetailed, let placeAddress {
                        Text(placeAddress)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(legibility.primaryText)
                .shadow(color: legibility.shadow, radius: 3, y: 1)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .task(id: snapshotTaskID) {
                await loadSnapshotIfNeeded()
            }
        }
    }

    private var placeTitle: String {
        common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.place")
    }

    private var placeAddress: String? {
        common.detail.trimmedOrNil
    }

    @ViewBuilder
    private var mapImage: some View {
        if let image = snapshotImage, !payload.isPrivacyEnabled {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            fallbackMapBackground
                .overlay {
                    if payload.isPrivacyEnabled {
                        privacyLocationMask
                    }
                }
        }
    }

    private var snapshotImage: UIImage? {
        guard let data = payload.mapSnapshotData ?? generatedSnapshotData else { return nil }
        return UIImage(data: data)
    }

    private var activeSnapshotData: Data? {
        payload.mapSnapshotData ?? generatedSnapshotData
    }

    private var privacyLocationMask: some View {
        LinearGradient(
            colors: [
                Color(.secondarySystemBackground).opacity(0.34),
                accent.opacity(0.12),
                Color(.systemBackground).opacity(0.52),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackMapBackground: some View {
        ZStack {
            accent.opacity(0.1)
            Path { path in
                path.move(to: CGPoint(x: 0, y: 32))
                path.addCurve(to: CGPoint(x: 190, y: 52), control1: CGPoint(x: 58, y: 4), control2: CGPoint(x: 104, y: 82))
                path.move(to: CGPoint(x: 20, y: 132))
                path.addCurve(to: CGPoint(x: 184, y: 16), control1: CGPoint(x: 50, y: 62), control2: CGPoint(x: 132, y: 90))
                path.move(to: CGPoint(x: 18, y: 18))
                path.addLine(to: CGPoint(x: 76, y: 98))
                path.move(to: CGPoint(x: 116, y: 0))
                path.addLine(to: CGPoint(x: 154, y: 132))
            }
            .stroke(accent.opacity(0.34), lineWidth: 2)
            Circle()
                .fill(accent.opacity(0.14))
                .frame(width: 42, height: 42)
                .offset(x: 54, y: -18)
            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, accent)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        }
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.map(
            snapshotData: activeSnapshotData,
            isPrivacyEnabled: payload.isPrivacyEnabled,
            highContrast: highContrast
        )
    }

    private var snapshotTaskID: String {
        [
            payload.latitude.map { String(format: "%.5f", $0) } ?? "nil",
            payload.longitude.map { String(format: "%.5f", $0) } ?? "nil",
            payload.isPrivacyEnabled ? "private" : "public",
            context.density.rawValue,
        ].joined(separator: "-")
    }

    @MainActor
    private func loadSnapshotIfNeeded() async {
        guard payload.mapSnapshotData == nil,
              generatedSnapshotData == nil,
              !payload.isPrivacyEnabled
        else { return }

        generatedSnapshotData = await CapturePlaceMapSnapshotCache.shared.snapshotData(
            latitude: payload.latitude,
            longitude: payload.longitude,
            size: snapshotSize
        )
    }

    private var snapshotSize: CGSize {
        switch context.density {
        case .simple:
            return CGSize(width: 240, height: 120)
        case .standard:
            return CGSize(width: 480, height: 360)
        case .detailed:
            return CGSize(width: 420, height: 560)
        }
    }

    private var highContrast: Bool {
        highContrastOverride ?? (colorSchemeContrast == .increased)
    }
}

@MainActor
final class CapturePlaceMapSnapshotCache {
    static let shared = CapturePlaceMapSnapshotCache()

    private var storage: [Key: Data] = [:]

    func snapshotData(
        latitude: Double?,
        longitude: Double?,
        size: CGSize
    ) async -> Data? {
        let key = Key(latitude: latitude, longitude: longitude, size: size)
        if let cached = storage[key] {
            return cached
        }
        let data = await CapturePlaceMapSnapshotter.snapshotData(
            latitude: latitude,
            longitude: longitude,
            size: size
        )
        if let data {
            storage[key] = data
        }
        return data
    }

    private struct Key: Hashable {
        let latitude: Int
        let longitude: Int
        let width: Int
        let height: Int

        init(latitude: Double?, longitude: Double?, size: CGSize) {
            self.latitude = Int(((latitude ?? 0) * 100_000).rounded())
            self.longitude = Int(((longitude ?? 0) * 100_000).rounded())
            self.width = Int(size.width.rounded())
            self.height = Int(size.height.rounded())
        }
    }
}
