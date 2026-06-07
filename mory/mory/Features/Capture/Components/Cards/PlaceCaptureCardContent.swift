import SwiftUI
import UIKit

struct PlaceCaptureCardContent: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let common: CaptureCardCommonDisplay
    let payload: CapturePlaceCardPayload
    let accent: Color
    let highContrastOverride: Bool?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            placeBackground
            standardContent
        }
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(placePrimaryText, accent)

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.place"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(placePrimaryText)
                    .lineLimit(1)
                Text(common.detail)
                    .font(.caption)
                    .foregroundStyle(placeSecondaryText)
                    .lineLimit(2)
            }
        }
        .shadow(color: placeTextShadow, radius: 3, y: 1)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var placeBackground: some View {
        if let image = payload.mapSnapshotImage, !payload.isPrivacyEnabled {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(placeSnapshotScrim)
        } else {
            mapBackground
                .overlay {
                    if payload.isPrivacyEnabled {
                        privacyLocationMask
                    }
                }
        }
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

    private var mapBackground: some View {
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1.2)
                .frame(width: 92, height: 54)
                .rotationEffect(.degrees(-9))
                .offset(x: -32, y: 28)
        }
    }

    private var legibilityStyle: CaptureMapLegibilityStyle {
        guard payload.mapSnapshotData != nil, !payload.isPrivacyEnabled else {
            return .fallback
        }
        return CaptureMapLegibilityStyle.resolve(snapshotData: payload.mapSnapshotData)
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.map(
            snapshotData: payload.mapSnapshotData,
            isPrivacyEnabled: payload.isPrivacyEnabled,
            highContrast: highContrast
        )
    }

    private var placePrimaryText: Color {
        legibility.primaryText
    }

    private var placeSecondaryText: Color {
        legibility.secondaryText
    }

    private var placeTextShadow: Color {
        legibility.shadow
    }

    private var placeSnapshotScrim: some View {
        LinearGradient(
            colors: placeScrimColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var placeScrimColors: [Color] {
        legibility.scrimColors
    }

    private var highContrast: Bool {
        highContrastOverride ?? (colorSchemeContrast == .increased)
    }
}

private extension CapturePlaceCardPayload {
    var mapSnapshotImage: UIImage? {
        guard let mapSnapshotData else { return nil }
        return UIImage(data: mapSnapshotData)
    }
}
