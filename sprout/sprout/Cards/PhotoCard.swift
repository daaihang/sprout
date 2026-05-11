import SwiftUI
import MapKit
import PhotosUI

struct PhotoCardData {
    var imagesData: [Data]
    var locationName: String
    var descriptionText: String
    var locationCoordinate: CLLocationCoordinate2D?
    var aiDescription: String?

    init(
        imagesData: [Data] = [],
        locationName: String = "",
        descriptionText: String = "",
        locationCoordinate: CLLocationCoordinate2D? = nil,
        aiDescription: String? = nil
    ) {
        self.imagesData = imagesData
        self.locationName = locationName
        self.descriptionText = descriptionText
        self.locationCoordinate = locationCoordinate
        self.aiDescription = aiDescription
    }

    var images: [UIImage] {
        imagesData.compactMap { UIImage(data: $0) }
    }
}

struct PhotoCard: View {
    var data: PhotoCardData?

    var body: some View {
        cardContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cardBackground()
    }

    @ViewBuilder
    private var cardContent: some View {
        if let data = data, !data.images.isEmpty {
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    imageSection(images: data.images, containerSize: geometry.size)
                    infoOverlay(data: data)
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
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.5))
                Text(localizedString("card.photo.placeholder", default: "Tap to add a photo"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func imageSection(images: [UIImage], containerSize: CGSize) -> some View {
        let hasMultiple = images.count > 1
        let metrics = CardLayoutMetrics(containerSize: containerSize)

        ZStack {
            if hasMultiple {
                ForEach(0..<(metrics.isTallHeight ? 3 : 2), id: \.self) { i in
                    let offsetX = CGFloat(2 - i) * -6
                    let offsetY = CGFloat(2 - i) * -4
                    let opacity = 1.0 - Double(i) * 0.25
                    Image(uiImage: images[0])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: containerSize.width, height: containerSize.height, alignment: .center)
                        .offset(x: offsetX, y: offsetY)
                        .opacity(opacity)
                        .mask(
                            RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous)
                        )
                }
            }

            if hasMultiple {
                TabView {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: containerSize.width, height: containerSize.height, alignment: .center)
                            .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else {
                GeometryReader { geo in
                    Image(uiImage: images[0])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                        .clipped()
                }
            }
        }
    }

    @ViewBuilder
    private func infoOverlay(data: PhotoCardData) -> some View {
        let hasLocation = !data.locationName.isEmpty
        let hasDescription = !data.descriptionText.isEmpty

        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            if hasLocation {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(data.locationName)
                        .font(.caption)
                        .fontWeight(hasDescription ? .regular : .bold)
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            if hasDescription {
                Text(data.descriptionText)
                    .font(.caption)
                    .fontWeight(hasLocation ? .regular : .bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
