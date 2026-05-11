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
            cardContent(size: geo.size)
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
            .onTapGesture {
                onTap?()
            }
            .onChange(of: data?.coordinate) { _, _ in
                generateSnapshot()
            }
    }

    @ViewBuilder
    private func cardContent(size: CGSize) -> some View {
        if data?.coordinate != nil {
            ZStack {
                if let image = mapImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()

                    pinOverlay(size: size)
                } else if isLoading {
                    Color.gray.opacity(0.2)
                    ProgressView()
                } else {
                    placeholderContent
                }
            }
        } else {
            placeholderContent
        }
    }

    @ViewBuilder
    private var placeholderContent: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.5))
                Text(localizedString("card.map.placeholder", default: "Tap to choose a place"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func pinOverlay(size: CGSize) -> some View {
        let metrics = CardLayoutMetrics(containerSize: size)
        let pinX = metrics.isLandscape ? size.width * 0.62 : size.width * 0.5
        let pinY = metrics.isLandscape ? size.height * 0.5 : size.height * 0.42

        Image(systemName: "mappin")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.red)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .position(x: pinX, y: pinY)
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
        snapshotter.start { snapshot, error in
            DispatchQueue.main.async {
                isLoading = false
                if let snapshot = snapshot {
                    self.mapImage = snapshot.image
                }
            }
        }
    }

    private func updateSnapshotSize(_ size: CGSize) {
        snapshotSize = size
    }
}
