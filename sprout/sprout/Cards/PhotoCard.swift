import SwiftUI
import UIKit
import MapKit

struct PhotoCardData {
    var images: [UIImage]
    var locationName: String
    var descriptionText: String
    var locationCoordinate: CLLocationCoordinate2D?
    var aiDescription: String?

    init(
        images: [UIImage] = [],
        locationName: String = "",
        descriptionText: String = "",
        locationCoordinate: CLLocationCoordinate2D? = nil,
        aiDescription: String? = nil
    ) {
        self.images = images
        self.locationName = locationName
        self.descriptionText = descriptionText
        self.locationCoordinate = locationCoordinate
        self.aiDescription = aiDescription
    }
}

struct PhotoCard: View {
    let size: CardSize
    var data: PhotoCardData?

    var body: some View {
        cardContent
            .frame(width: size.width, height: size.height)
            .cardBackground()
    }

    @ViewBuilder
    private var cardContent: some View {
        if let data = data, !data.images.isEmpty {
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    imageSection(images: data.images, size: geometry.size)
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
                Text("点击添加照片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func imageSection(images: [UIImage], size: CGSize) -> some View {
        let hasMultiple = images.count > 1

        ZStack {
            if hasMultiple {
                ForEach(0..<3, id: \.self) { i in
                    let offsetX = CGFloat(3 - i) * -6
                    let offsetY = CGFloat(3 - i) * -4
                    let opacity = 1.0 - Double(i) * 0.25
                    Image(uiImage: images[0])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height, alignment: .center)
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
                            .frame(width: size.width, height: size.height, alignment: .center)
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
                    .lineLimit(1)
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

struct PhotoCard_4x2: View {
    var data: PhotoCardData?
    var body: some View { PhotoCard(size: .w4h2, data: data) }
}

struct PhotoCard_4x4: View {
    var data: PhotoCardData?
    var body: some View { PhotoCard(size: .w4h4, data: data) }
}

#Preview {
    VStack(spacing: 12) {
        PhotoCard_4x2(data: PhotoCardData(
            images: [],
            locationName: "",
            descriptionText: ""
        ))
        PhotoCard_4x4(data: PhotoCardData(
            images: [],
            locationName: "",
            descriptionText: ""
        ))
    }
    .frame(width: 400)
}
