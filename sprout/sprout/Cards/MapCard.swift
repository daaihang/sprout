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
    let size: CardSize
    var data: MapCardData?
    var onTap: (() -> Void)?

    @State private var mapImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        cardContent
            .frame(width: size.width, height: size.height)
            .cardBackground()
            .onTapGesture {
                onTap?()
            }
            .onChange(of: data?.coordinate) { _, _ in
                generateSnapshot()
            }
            .onAppear {
                generateSnapshot()
            }
    }

    @ViewBuilder
    private var cardContent: some View {
        if let coordinate = data?.coordinate {
            ZStack {
                if let image = mapImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()

                    pinOverlay
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
                Text("点击选择地点")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var pinOverlay: some View {
        GeometryReader { _ in
            let pinX = size == .w4h2 ? size.width * 2 / 3 : size.width / 2
            let pinY = size == .w4h2 ? size.height / 2 : size.height * 2 / 5
            Image(systemName: "mappin")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.red)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .position(x: pinX, y: pinY)
        }
    }

    private func generateSnapshot() {
        guard let coordinate = data?.coordinate else {
            mapImage = nil
            return
        }

        isLoading = true

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 300,
            longitudinalMeters: 300
        )
        options.size = CGSize(width: size.width * 2, height: size.height * 2)
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
}

struct MapCard_4x2: View {
    var data: MapCardData?
    var onTap: (() -> Void)?
    var body: some View { MapCard(size: .w4h2, data: data, onTap: onTap) }
}

struct MapCard_4x4: View {
    var data: MapCardData?
    var onTap: (() -> Void)?
    var body: some View { MapCard(size: .w4h4, data: data, onTap: onTap) }
}

#Preview {
    VStack(spacing: 12) {
        MapCard_4x2(data: MapCardData(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            locationName: "San Francisco",
            descriptionText: "Test location"
        ))
        MapCard_4x4(data: MapCardData(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            locationName: "San Francisco",
            descriptionText: "Test location"
        ))
    }
    .frame(width: 400)
}
