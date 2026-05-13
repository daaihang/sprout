import SwiftUI
import UIKit
import MapKit

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct MapCardData {
    var coordinate: CLLocationCoordinate2D?
    var locationName: String
    var descriptionText: String

    init(
        coordinate: CLLocationCoordinate2D? = nil,
        locationName: String = "",
        descriptionText: String = ""
    ) {
        self.coordinate = coordinate
        self.locationName = locationName
        self.descriptionText = descriptionText
    }
}

struct MapCard: View {
    var data: MapCardData?
    var onTap: (() -> Void)?

    @State private var mapImage: UIImage?
    @State private var isLoading = false
    @State private var snapshotSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let context = MapCardLayoutContext(containerSize: geo.size)

            cardContent(size: geo.size, context: context)
                .onAppear {
                    updateSnapshotSize(geo.size)
                    generateSnapshot()
                }
                .onChange(of: geo.size) { _, newSize in
                    updateSnapshotSize(newSize)
                    generateSnapshot()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onChange(of: data?.coordinate) { _, _ in
            generateSnapshot()
        }
    }

    @ViewBuilder
    private func cardContent(size: CGSize, context: MapCardLayoutContext) -> some View {
        if data?.coordinate != nil {
            if let mapImage {
                MapCardRenderer(data: data, image: mapImage, context: context)
            } else if isLoading {
                loadingView(context: context)
            } else {
                placeholderContent
            }
        } else {
            placeholderContent
        }
    }

    private func loadingView(context: MapCardLayoutContext) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.89, green: 0.94, blue: 0.97),
                    Color(red: 0.95, green: 0.93, blue: 0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                ProgressView()
                    .tint(.accentColor)
                Text(localizedString("card.map.loading", default: "Loading map snapshot"))
                    .font(context.metaFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var placeholderContent: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.89, green: 0.94, blue: 0.97),
                    Color(red: 0.95, green: 0.93, blue: 0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius - 6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                .padding(6)

            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.78))
                        .frame(width: 42, height: 42)
                    Image(systemName: "map.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.58))
                }

                Text(localizedString("card.map.placeholder", default: "Tap to choose a place"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.72))

                Text(localizedString("card.map.placeholder.subtitle", default: "Places become spatial memory artifacts with names, coordinates, and scenes."))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .lineLimit(2)
            }
            .padding(16)
        }
    }

    private func generateSnapshot() {
        guard let coordinate = data?.coordinate else {
            mapImage = nil
            return
        }

        guard snapshotSize.width > 0, snapshotSize.height > 0 else {
            return
        }

        isLoading = true

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 300,
            longitudinalMeters: 300
        )
        options.size = CGSize(width: snapshotSize.width * 2, height: snapshotSize.height * 2)
        options.mapType = .mutedStandard

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, _ in
            DispatchQueue.main.async {
                isLoading = false
                if let snapshot {
                    self.mapImage = snapshot.image
                }
            }
        }
    }

    private func updateSnapshotSize(_ size: CGSize) {
        snapshotSize = size
    }
}

private struct MapCardRenderer: View {
    let data: MapCardData?
    let image: UIImage
    let context: MapCardLayoutContext

    var body: some View {
        ZStack {
            switch context.mode {
            case .overlayHero:
                overlayHero
            case .splitInfo:
                splitInfo
            case .snapshotOnly:
                snapshotOnly
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous))
        .animation(.spring(duration: 0.34, bounce: 0.16), value: context.mode.rawValue)
    }

    private var overlayHero: some View {
        ZStack(alignment: .topLeading) {
            snapshotImage
            LinearGradient(
                colors: [.black.opacity(0.16), .clear, .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                topChips(lightText: true)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let title = titleLine {
                            Text(title)
                                .font(context.heroTitleFont)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                        }

                        if let description = descriptionLine {
                            Text(description)
                                .font(context.heroBodyFont)
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(context.descriptionLineLimit)
                        }
                    }

                    Spacer(minLength: 0)

                    pinBadge
                }
                .padding(14)
            }
        }
    }

    private var splitInfo: some View {
        HStack(spacing: 0) {
            snapshotImage
                .frame(width: context.leadingSnapshotWidth)
                .overlay(alignment: .topLeading) {
                    topChips(lightText: true)
                        .padding(10)
                }
                .overlay(alignment: .bottomTrailing) {
                    pinBadge
                        .padding(10)
                }

            VStack(alignment: .leading, spacing: 8) {
                if let title = titleLine {
                    Text(title)
                        .font(context.standardTitleFont)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                if let description = descriptionLine {
                    Text(description)
                        .font(context.standardBodyFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(context.descriptionLineLimit)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    if let coordinateLine {
                        Text(coordinateLine)
                            .font(context.metaFont)
                            .foregroundStyle(.secondary.opacity(0.82))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.97))
        }
    }

    private var snapshotOnly: some View {
        ZStack(alignment: .topLeading) {
            snapshotImage
            LinearGradient(
                colors: [.black.opacity(0.10), .clear, .black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                topChips(lightText: true)
                    .padding(12)
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    pinBadge
                }
                .padding(12)
            }
        }
    }

    private var snapshotImage: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: context.containerSize.width, height: context.containerSize.height)
            .clipped()
    }

    @ViewBuilder
    private func topChips(lightText: Bool) -> some View {
        HStack(spacing: 8) {
            chip(
                text: localizedString("card.map.place", default: "Place"),
                systemImage: "mappin.and.ellipse",
                lightText: lightText
            )

            if let coordinateLine {
                chip(
                    text: coordinateLine,
                    systemImage: "location",
                    lightText: lightText
                )
            }

            Spacer(minLength: 0)
        }
    }

    private func chip(text: String, systemImage: String, lightText: Bool) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(lightText ? Color.white : Color.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(lightText ? Color.black.opacity(0.28) : Color.black.opacity(0.05))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke((lightText ? Color.white : Color.black).opacity(lightText ? 0.16 : 0.08), lineWidth: 1)
            )
    }

    private var pinBadge: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.88))
                .frame(width: 34, height: 34)
            Image(systemName: "mappin")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.red)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private var titleLine: String? {
        let trimmed = (data?.locationName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var descriptionLine: String? {
        let trimmed = (data?.descriptionText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var coordinateLine: String? {
        guard let coordinate = data?.coordinate else { return nil }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}

private struct MapCardLayoutContext {
    enum Mode: String {
        case overlayHero
        case splitInfo
        case snapshotOnly
    }

    let containerSize: CGSize

    var aspectRatio: CGFloat {
        guard containerSize.height > 0 else { return 1 }
        return containerSize.width / containerSize.height
    }

    var mode: Mode {
        if containerSize.height < 110 || containerSize.width < 170 {
            return .snapshotOnly
        }
        if aspectRatio >= 1.28 {
            return .splitInfo
        }
        return .overlayHero
    }

    var leadingSnapshotWidth: CGFloat {
        max(min(containerSize.width * 0.42, 136), 96)
    }

    var heroTitleFont: Font {
        containerSize.height > 220
            ? .system(size: 24, weight: .bold, design: .rounded)
            : .system(size: 20, weight: .bold, design: .rounded)
    }

    var heroBodyFont: Font {
        .system(size: 13, weight: .semibold)
    }

    var standardTitleFont: Font {
        containerSize.height > 180
            ? .system(size: 18, weight: .bold, design: .rounded)
            : .system(size: 16, weight: .semibold, design: .rounded)
    }

    var standardBodyFont: Font {
        .system(size: 12, weight: .medium)
    }

    var metaFont: Font {
        .system(size: 11, weight: .medium)
    }

    var descriptionLineLimit: Int {
        containerSize.height > 180 ? 3 : 2
    }
}
