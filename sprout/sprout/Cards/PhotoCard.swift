import SwiftUI
import MapKit
import PhotosUI
import UIKit

struct PhotoCardData {
    var imagesData: [Data]
    var locationName: String
    var descriptionText: String
    var locationCoordinate: CLLocationCoordinate2D?
    var aiDescription: String?
    var trailingInfoText: String

    init(
        imagesData: [Data] = [],
        locationName: String = "",
        descriptionText: String = "",
        locationCoordinate: CLLocationCoordinate2D? = nil,
        aiDescription: String? = nil,
        trailingInfoText: String = ""
    ) {
        self.imagesData = imagesData
        self.locationName = locationName
        self.descriptionText = descriptionText
        self.locationCoordinate = locationCoordinate
        self.aiDescription = aiDescription
        self.trailingInfoText = trailingInfoText
    }

    var images: [UIImage] {
        imagesData.compactMap { UIImage(data: $0) }
    }
}

private enum PhotoCardLayoutMode: String {
    case fullBleedBottomOverlay
    case fullBleedCenteredSplitText
    case topImageBottomText
    case leadingImageTrailingText
    case imageOnly
}

private struct PhotoCardLayoutReport {
    var mode: PhotoCardLayoutMode
    var titleFits: Bool
    var locationFits: Bool
    var descriptionFits: Bool
    var trailingFits: Bool
    var cropFraction: CGFloat
    var fallbackReason: String
    var titleLineLimit: Int
    var visibleDescriptionLines: Int
    var displayedDescriptionText: String?
    var displayedLocationText: String?
    var displayedTrailingText: String?
}

struct PhotoCard: View {
    var data: PhotoCardData?

    var body: some View {
        Group {
            if let data, !data.images.isEmpty {
                GeometryReader { geometry in
                    let context = PhotoCardLayoutContext(containerSize: geometry.size)
                    let report = PhotoCardLayoutAnalyzer(data: data, context: context).resolve()

                    PhotoCardRenderer(data: data, report: report, context: context)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .adaptiveCardDiagnostics(diagnostics(from: report, context: context))
                }
            } else {
                placeholderContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
    }

    private func diagnostics(from report: PhotoCardLayoutReport, context: PhotoCardLayoutContext) -> AdaptiveCardDiagnostics {
        AdaptiveCardDiagnostics(
            layoutMode: report.mode.rawValue,
            density: context.density.label,
            metricFont: "Photo",
            theme: "Photo",
            titleOverflow: !report.titleFits,
            bodyOverflow: !report.descriptionFits,
            subtitleOverflow: !report.locationFits,
            visibleListItems: report.visibleDescriptionLines > 0 ? "\(report.visibleDescriptionLines)L" : "0L",
            heroCrop: "\(Int((report.cropFraction * 100).rounded()))%",
            fallbackReason: report.fallbackReason
        )
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
}

private struct PhotoCardRenderer: View {
    let data: PhotoCardData
    let report: PhotoCardLayoutReport
    let context: PhotoCardLayoutContext

    var body: some View {
        ZStack {
            switch report.mode {
            case .fullBleedBottomOverlay:
                fullBleedBottomOverlay
            case .fullBleedCenteredSplitText:
                fullBleedCenteredSplitText
            case .topImageBottomText:
                topImageBottomText
            case .leadingImageTrailingText:
                leadingImageTrailingText
            case .imageOnly:
                imageOnly
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous))
        .animation(.spring(duration: 0.36, bounce: 0.16), value: report.mode.rawValue)
    }

    private var fullBleedBottomOverlay: some View {
        ZStack(alignment: .bottomLeading) {
            mediaView(fillMode: true)
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if let title = titleText {
                        Text(title)
                            .font(context.overlayTitleFont)
                            .foregroundStyle(.white)
                            .lineLimit(report.titleLineLimit)
                            .minimumScaleFactor(0.82)
                    }

                    if let description = report.displayedDescriptionText {
                        Text(description)
                            .font(context.overlayBodyFont)
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(report.visibleDescriptionLines)
                    }

                    if let location = report.displayedLocationText {
                        Text(location)
                            .font(context.overlayMetaFont)
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if let trailing = report.displayedTrailingText {
                    Text(trailing)
                        .font(context.trailingInfoFont)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .monospacedDigit()
                }
            }
            .padding(context.overlayPadding)
        }
    }

    private var fullBleedCenteredSplitText: some View {
        ZStack {
            mediaView(fillMode: true)
            LinearGradient(
                colors: [.black.opacity(0.10), .black.opacity(0.36), .black.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 8) {
                if let title = titleText {
                    Text(title)
                        .font(context.centeredTitleFont)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(report.titleLineLimit)
                        .minimumScaleFactor(0.82)
                }

                if let description = report.displayedDescriptionText {
                    Text(description)
                        .font(context.centeredBodyFont)
                        .foregroundStyle(.white.opacity(0.94))
                        .multilineTextAlignment(.center)
                        .lineLimit(report.visibleDescriptionLines)
                }
            }
            .padding(.horizontal, context.overlayPadding)
            .frame(maxWidth: min(context.containerSize.width * 0.72, 280))
        }
    }

    private var topImageBottomText: some View {
        VStack(spacing: 0) {
            mediaView(fillMode: false)
                .frame(height: context.topSeparatedImageHeight)

            VStack(alignment: .leading, spacing: 6) {
                if let title = titleText {
                    Text(title)
                        .font(context.separatedTitleFont)
                        .foregroundStyle(.primary)
                        .lineLimit(report.titleLineLimit)
                }

                if let description = report.displayedDescriptionText {
                    Text(description)
                        .font(context.separatedBodyFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(report.visibleDescriptionLines)
                }

                HStack(spacing: 8) {
                    if let location = report.displayedLocationText {
                        Text(location)
                            .font(context.separatedMetaFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if let trailing = report.displayedTrailingText {
                        Text(trailing)
                            .font(context.separatedMetaFont.monospacedDigit())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(context.separatedPadding)
            .background(Color.white.opacity(0.96))
        }
    }

    private var leadingImageTrailingText: some View {
        HStack(spacing: 0) {
            mediaView(fillMode: false)
                .frame(width: context.leadingSeparatedImageWidth)

            VStack(alignment: .leading, spacing: 6) {
                if let title = titleText {
                    Text(title)
                        .font(context.separatedTitleFont)
                        .foregroundStyle(.primary)
                        .lineLimit(report.titleLineLimit)
                }

                if let description = report.displayedDescriptionText {
                    Text(description)
                        .font(context.separatedBodyFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(report.visibleDescriptionLines)
                }

                Spacer(minLength: 0)

                if let location = report.displayedLocationText {
                    Text(location)
                        .font(context.separatedMetaFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let trailing = report.displayedTrailingText {
                    Text(trailing)
                        .font(context.separatedMetaFont.monospacedDigit())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(context.separatedPadding)
            .background(Color.white.opacity(0.96))
        }
    }

    private var imageOnly: some View {
        mediaView(fillMode: true)
    }

    @ViewBuilder
    private func mediaView(fillMode: Bool) -> some View {
        let images = data.images
        let hasMultiple = images.count > 1

        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                if hasMultiple && fillMode {
                    ForEach(0..<(context.density == .relaxed ? 3 : 2), id: \.self) { index in
                        let offsetX = CGFloat(2 - index) * -6
                        let offsetY = CGFloat(2 - index) * -4
                        Image(uiImage: images[0])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height)
                            .offset(x: offsetX, y: offsetY)
                            .opacity(1 - Double(index) * 0.25)
                            .mask(
                                RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous)
                            )
                    }
                }

                if hasMultiple {
                    TabView {
                        ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                            imageView(image: image, size: size, fillMode: fillMode)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else if let image = images.first {
                    imageView(image: image, size: size, fillMode: fillMode)
                }
            }
        }
        .clipped()
    }

    private func imageView(image: UIImage, size: CGSize, fillMode: Bool) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: fillMode ? .fill : .fit)
            .frame(width: size.width, height: size.height)
            .background(Color.black.opacity(fillMode ? 0 : 0.03))
            .clipped()
    }

    private var titleText: String? {
        let trimmed = data.aiDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var locationText: String? {
        let trimmed = data.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var descriptionText: String? {
        let trimmed = data.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var trailingText: String? {
        let trimmed = data.trailingInfoText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct PhotoCardLayoutContext {
    let containerSize: CGSize
    let contentSize: CGSize
    let density: AdaptiveCardDensity

    init(containerSize: CGSize) {
        self.containerSize = containerSize
        let padding = max(10, min(18, min(containerSize.width, containerSize.height) * 0.1))
        self.contentSize = CGSize(
            width: max(containerSize.width - padding * 2, 0),
            height: max(containerSize.height - padding * 2, 0)
        )

        if containerSize.height < 96 || containerSize.width < 136 {
            density = .compact
        } else if containerSize.height > 180 || containerSize.width > 260 {
            density = .relaxed
        } else {
            density = .standard
        }
    }

    var aspectRatio: CGFloat {
        guard containerSize.height > 0 else { return 1 }
        return containerSize.width / containerSize.height
    }

    var isWide: Bool { aspectRatio >= 1.45 }
    var isTall: Bool { aspectRatio <= 0.9 }

    var overlayPadding: CGFloat {
        switch density {
        case .compact: 12
        case .standard: 14
        case .relaxed: 16
        }
    }

    var separatedPadding: CGFloat {
        switch density {
        case .compact: 12
        case .standard: 14
        case .relaxed: 16
        }
    }

    var topSeparatedImageHeight: CGFloat {
        max(containerSize.height * 0.52, min(120, containerSize.height * 0.62))
    }

    var leadingSeparatedImageWidth: CGFloat {
        max(containerSize.width * 0.42, min(126, containerSize.width * 0.5))
    }

    var overlayTitleFont: Font {
        switch density {
        case .compact: .system(size: 15, weight: .bold, design: .rounded)
        case .standard: .system(size: 18, weight: .bold, design: .rounded)
        case .relaxed: .system(size: 22, weight: .bold, design: .rounded)
        }
    }

    var overlayBodyFont: Font {
        switch density {
        case .compact: .system(size: 11, weight: .medium)
        case .standard: .system(size: 12, weight: .medium)
        case .relaxed: .system(size: 13, weight: .medium)
        }
    }

    var overlayMetaFont: Font {
        switch density {
        case .compact: .system(size: 10, weight: .medium, design: .rounded)
        case .standard: .system(size: 11, weight: .medium, design: .rounded)
        case .relaxed: .system(size: 12, weight: .medium, design: .rounded)
        }
    }

    var trailingInfoFont: Font {
        switch density {
        case .compact: .system(size: 20, weight: .bold, design: .rounded)
        case .standard: .system(size: 28, weight: .bold, design: .rounded)
        case .relaxed: .system(size: 34, weight: .bold, design: .rounded)
        }
    }

    var centeredTitleFont: Font {
        switch density {
        case .compact: .system(size: 16, weight: .bold, design: .rounded)
        case .standard: .system(size: 20, weight: .bold, design: .rounded)
        case .relaxed: .system(size: 28, weight: .bold, design: .rounded)
        }
    }

    var centeredBodyFont: Font {
        switch density {
        case .compact: .system(size: 11, weight: .semibold, design: .rounded)
        case .standard: .system(size: 13, weight: .semibold, design: .rounded)
        case .relaxed: .system(size: 15, weight: .semibold, design: .rounded)
        }
    }

    var separatedTitleFont: Font {
        switch density {
        case .compact: .system(size: 14, weight: .semibold)
        case .standard: .system(size: 16, weight: .semibold)
        case .relaxed: .system(size: 18, weight: .semibold)
        }
    }

    var separatedBodyFont: Font {
        switch density {
        case .compact: .system(size: 11)
        case .standard: .system(size: 12)
        case .relaxed: .system(size: 13)
        }
    }

    var separatedMetaFont: Font {
        switch density {
        case .compact: .system(size: 10, weight: .medium)
        case .standard: .system(size: 11, weight: .medium)
        case .relaxed: .system(size: 12, weight: .medium)
        }
    }

    func textLineBudget(for mode: PhotoCardLayoutMode) -> Int {
        let height = contentSize.height

        switch mode {
        case .imageOnly:
            return 0
        case .fullBleedCenteredSplitText, .fullBleedBottomOverlay:
            if height < 84 { return 2 }
            if height < 132 { return 3 }
            if height < 188 { return 4 }
            return density == .relaxed ? 6 : 5
        case .topImageBottomText, .leadingImageTrailingText:
            if height < 118 { return 2 }
            if height < 176 { return 3 }
            return density == .relaxed ? 4 : 3
        }
    }

    func maxTitleLines(for mode: PhotoCardLayoutMode) -> Int {
        switch mode {
        case .fullBleedCenteredSplitText:
            density == .relaxed ? 2 : 1
        case .fullBleedBottomOverlay:
            density == .compact ? 1 : 2
        case .topImageBottomText, .leadingImageTrailingText:
            density == .compact ? 1 : 2
        case .imageOnly:
            0
        }
    }

    func maxDescriptionLines(for mode: PhotoCardLayoutMode) -> Int {
        switch mode {
        case .fullBleedCenteredSplitText:
            density == .relaxed ? 3 : 2
        case .fullBleedBottomOverlay:
            density == .compact ? 1 : 2
        case .topImageBottomText, .leadingImageTrailingText:
            density == .compact ? 1 : 2
        case .imageOnly:
            0
        }
    }

    var prefersTrailingAccessory: Bool {
        contentSize.width >= 170 && contentSize.height >= 72
    }
}

private struct PhotoCardResolvedText {
    var text: String?
    var displayLines: Int
    var isTruncated: Bool

    static let empty = PhotoCardResolvedText(text: nil, displayLines: 0, isTruncated: false)
}

private struct PhotoCardLayoutAnalyzer {
    let data: PhotoCardData
    let context: PhotoCardLayoutContext

    func resolve() -> PhotoCardLayoutReport {
        let centered = measureFullBleedCentered()
        if centered.cropFraction <= 0.26 && centered.titleLineLimit > 0 {
            return centered
        }

        let bottom = measureFullBleedBottom()
        if bottom.cropFraction <= 0.34 && bottom.titleLineLimit > 0 {
            var adjusted = bottom
            adjusted.fallbackReason = centered.cropFraction > 0.26
                ? "center crop \(Int((centered.cropFraction * 100).rounded()))%"
                : "center text budget"
            return adjusted
        }

        let separated = context.isWide ? measureLeadingImageTrailingText() : measureTopImageBottomText()
        if separated.titleLineLimit > 0 {
            var adjusted = separated
            adjusted.fallbackReason = bottom.cropFraction > 0.34
                ? "overlay crop \(Int((bottom.cropFraction * 100).rounded()))%"
                : "overlay text budget"
            return adjusted
        }

        return PhotoCardLayoutReport(
            mode: .imageOnly,
            titleFits: false,
            locationFits: false,
            descriptionFits: false,
            trailingFits: false,
            cropFraction: separated.cropFraction,
            fallbackReason: "text budget exhausted",
            titleLineLimit: 0,
            visibleDescriptionLines: 0,
            displayedDescriptionText: nil,
            displayedLocationText: nil,
            displayedTrailingText: nil
        )
    }

    private func measureFullBleedCentered() -> PhotoCardLayoutReport {
        let mode = PhotoCardLayoutMode.fullBleedCenteredSplitText
        let width = min(context.containerSize.width * 0.72, 280)
        let title = trimmed(data.aiDescription)
        let description = trimmed(data.descriptionText)
        let location = trimmed(data.locationName)
        let budget = context.textLineBudget(for: mode)
        let secondarySource = !description.isEmpty ? description : location
        let titleMaxLines = allowedTitleLines(for: mode, budget: budget, hasSecondary: !secondarySource.isEmpty)
        let titleMeasure = resolvedText(
            title,
            width: width,
            font: titleUIFont(centered: true),
            maxLines: titleMaxLines
        )
        let remaining = max(budget - titleMeasure.displayLines, 0)
        let secondaryMeasure = resolvedText(
            secondarySource,
            width: width,
            font: bodyUIFont(centered: true),
            maxLines: min(context.maxDescriptionLines(for: mode), remaining)
        )

        return PhotoCardLayoutReport(
            mode: mode,
            titleFits: !title.isEmpty ? !titleMeasure.isTruncated : true,
            locationFits: location.isEmpty ? true : (description.isEmpty ? !secondaryMeasure.isTruncated : secondaryMeasure.text == nil),
            descriptionFits: description.isEmpty ? true : !secondaryMeasure.isTruncated,
            trailingFits: true,
            cropFraction: estimatedCrop(),
            fallbackReason: titleMeasure.isTruncated || secondaryMeasure.isTruncated ? "center text truncated" : "ok",
            titleLineLimit: titleMeasure.displayLines,
            visibleDescriptionLines: secondaryMeasure.displayLines,
            displayedDescriptionText: secondaryMeasure.text,
            displayedLocationText: nil,
            displayedTrailingText: nil
        )
    }

    private func measureFullBleedBottom() -> PhotoCardLayoutReport {
        let mode = PhotoCardLayoutMode.fullBleedBottomOverlay
        let width = max(context.containerSize.width - context.overlayPadding * 2, 44)
        let title = trimmed(data.aiDescription)
        let description = trimmed(data.descriptionText)
        let location = trimmed(data.locationName)
        let trailing = trimmed(data.trailingInfoText)
        let budget = context.textLineBudget(for: mode)
        let trailingCandidates = (!trailing.isEmpty && context.prefersTrailingAccessory) ? [true, false] : [false]

        for showTrailing in trailingCandidates {
            let textWidth = showTrailing ? width * 0.62 : width
            let titleMaxLines = allowedTitleLines(for: mode, budget: budget, hasSecondary: !description.isEmpty || !location.isEmpty)
            let titleMeasure = resolvedText(
                title,
                width: textWidth,
                font: titleUIFont(centered: false),
                maxLines: titleMaxLines
            )
            var remaining = max(budget - titleMeasure.displayLines, 0)
            let descriptionMeasure = resolvedText(
                description,
                width: textWidth,
                font: bodyUIFont(centered: false),
                maxLines: min(context.maxDescriptionLines(for: mode), remaining)
            )
            remaining = max(remaining - descriptionMeasure.displayLines, 0)
            let locationMeasure = resolvedText(
                location,
                width: textWidth,
                font: metaUIFont,
                maxLines: remaining > 0 ? 1 : 0
            )
            let trailingFits = !showTrailing || fits(text: trailing, width: width * 0.28, font: trailingUIFont, lines: 1)

            if !showTrailing || trailingFits {
                return PhotoCardLayoutReport(
                    mode: mode,
                    titleFits: !title.isEmpty ? !titleMeasure.isTruncated : true,
                    locationFits: location.isEmpty ? true : !locationMeasure.isTruncated,
                    descriptionFits: description.isEmpty ? true : !descriptionMeasure.isTruncated,
                    trailingFits: trailingFits,
                    cropFraction: estimatedCrop(),
                    fallbackReason: titleMeasure.isTruncated || descriptionMeasure.isTruncated || locationMeasure.isTruncated
                        ? "bottom text truncated"
                        : "ok",
                    titleLineLimit: titleMeasure.displayLines,
                    visibleDescriptionLines: descriptionMeasure.displayLines,
                    displayedDescriptionText: descriptionMeasure.text,
                    displayedLocationText: locationMeasure.text,
                    displayedTrailingText: showTrailing ? trailing : nil
                )
            }
        }

        return emptyReport(for: mode, cropFraction: estimatedCrop(), reason: "bottom accessory overflow")
    }

    private func measureTopImageBottomText() -> PhotoCardLayoutReport {
        let mode = PhotoCardLayoutMode.topImageBottomText
        let width = max(context.containerSize.width - context.separatedPadding * 2, 44)
        return measureSeparatedText(mode: mode, width: width, locationWidth: width * 0.68, trailingWidth: width * 0.26)
    }

    private func measureLeadingImageTrailingText() -> PhotoCardLayoutReport {
        let mode = PhotoCardLayoutMode.leadingImageTrailingText
        let width = max(context.containerSize.width - context.leadingSeparatedImageWidth - context.separatedPadding * 2, 44)
        return measureSeparatedText(mode: mode, width: width, locationWidth: width * 0.68, trailingWidth: width * 0.28)
    }

    private func measureSeparatedText(
        mode: PhotoCardLayoutMode,
        width: CGFloat,
        locationWidth: CGFloat,
        trailingWidth: CGFloat
    ) -> PhotoCardLayoutReport {
        let title = trimmed(data.aiDescription)
        let description = trimmed(data.descriptionText)
        let location = trimmed(data.locationName)
        let trailing = trimmed(data.trailingInfoText)
        let budget = context.textLineBudget(for: mode)
        let trailingCandidates = (!trailing.isEmpty && context.prefersTrailingAccessory) ? [true, false] : [false]

        for showTrailing in trailingCandidates {
            let titleMaxLines = allowedTitleLines(for: mode, budget: budget, hasSecondary: !description.isEmpty || !location.isEmpty)
            let titleMeasure = resolvedText(title, width: width, font: separatedTitleUIFont, maxLines: titleMaxLines)
            var remaining = max(budget - titleMeasure.displayLines, 0)
            let descriptionMeasure = resolvedText(
                description,
                width: width,
                font: separatedBodyUIFont,
                maxLines: min(context.maxDescriptionLines(for: mode), remaining)
            )
            remaining = max(remaining - descriptionMeasure.displayLines, 0)
            let locationMeasure = resolvedText(
                location,
                width: showTrailing ? locationWidth : width,
                font: metaUIFont,
                maxLines: remaining > 0 ? 1 : 0
            )
            let trailingFits = !showTrailing || fits(text: trailing, width: trailingWidth, font: metaUIFont, lines: 1)

            if !showTrailing || trailingFits {
                return PhotoCardLayoutReport(
                    mode: mode,
                    titleFits: !title.isEmpty ? !titleMeasure.isTruncated : true,
                    locationFits: location.isEmpty ? true : !locationMeasure.isTruncated,
                    descriptionFits: description.isEmpty ? true : !descriptionMeasure.isTruncated,
                    trailingFits: trailingFits,
                    cropFraction: 0,
                    fallbackReason: titleMeasure.isTruncated || descriptionMeasure.isTruncated || locationMeasure.isTruncated
                        ? "separated text truncated"
                        : "ok",
                    titleLineLimit: titleMeasure.displayLines,
                    visibleDescriptionLines: descriptionMeasure.displayLines,
                    displayedDescriptionText: descriptionMeasure.text,
                    displayedLocationText: locationMeasure.text,
                    displayedTrailingText: showTrailing ? trailing : nil
                )
            }
        }

        return PhotoCardLayoutReport(
            mode: mode,
            titleFits: false,
            locationFits: false,
            descriptionFits: false,
            trailingFits: false,
            cropFraction: 0,
            fallbackReason: "separated accessory overflow",
            titleLineLimit: 0,
            visibleDescriptionLines: 0,
            displayedDescriptionText: nil,
            displayedLocationText: nil,
            displayedTrailingText: nil
        )
    }

    private func allowedTitleLines(for mode: PhotoCardLayoutMode, budget: Int, hasSecondary: Bool) -> Int {
        guard budget > 0 else { return 0 }
        let base = context.maxTitleLines(for: mode)

        if hasSecondary {
            return min(base, max(1, budget - 1))
        }

        return min(base, budget)
    }

    private func resolvedText(_ text: String, width: CGFloat, font: UIFont, maxLines: Int) -> PhotoCardResolvedText {
        guard !text.isEmpty, maxLines > 0 else { return .empty }
        let requiredLines = requiredLineCount(text: text, width: width, font: font)
        let displayLines = min(max(requiredLines, 1), maxLines)
        return PhotoCardResolvedText(
            text: text,
            displayLines: displayLines,
            isTruncated: requiredLines > maxLines
        )
    }

    private func requiredLineCount(text: String, width: CGFloat, font: UIFont) -> Int {
        guard !text.isEmpty else { return 0 }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let rect = NSAttributedString(string: text, attributes: attributes).boundingRect(
            with: CGSize(width: max(width, 1), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return max(Int(ceil(rect.height / max(font.lineHeight, 1))), 1)
    }

    private func emptyReport(for mode: PhotoCardLayoutMode, cropFraction: CGFloat, reason: String) -> PhotoCardLayoutReport {
        PhotoCardLayoutReport(
            mode: mode,
            titleFits: false,
            locationFits: false,
            descriptionFits: false,
            trailingFits: false,
            cropFraction: cropFraction,
            fallbackReason: reason,
            titleLineLimit: 0,
            visibleDescriptionLines: 0,
            displayedDescriptionText: nil,
            displayedLocationText: nil,
            displayedTrailingText: nil
        )
    }

    private func fits(text: String, width: CGFloat, font: UIFont, lines: Int) -> Bool {
        guard !text.isEmpty else { return true }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let rect = NSAttributedString(string: text, attributes: attributes).boundingRect(
            with: CGSize(width: max(width, 1), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let measuredHeight = ceil(rect.height)
        let allowedHeight = ceil(font.lineHeight * CGFloat(max(lines, 1)))
        return measuredHeight <= allowedHeight + 1
    }

    private func estimatedCrop() -> CGFloat {
        guard let image = data.images.first, image.size.height > 0 else { return 0 }
        let imageRatio = image.size.width / image.size.height
        let containerRatio = max(context.containerSize.width / max(context.containerSize.height, 1), 0.01)

        if imageRatio > containerRatio {
            return max(0, 1 - (containerRatio / imageRatio))
        } else {
            return max(0, 1 - (imageRatio / containerRatio))
        }
    }

    private var metaUIFont: UIFont {
        switch context.density {
        case .compact: .systemFont(ofSize: 10, weight: .medium)
        case .standard: .systemFont(ofSize: 11, weight: .medium)
        case .relaxed: .systemFont(ofSize: 12, weight: .medium)
        }
    }

    private var trailingUIFont: UIFont {
        switch context.density {
        case .compact: .systemFont(ofSize: 20, weight: .bold)
        case .standard: .systemFont(ofSize: 28, weight: .bold)
        case .relaxed: .systemFont(ofSize: 34, weight: .bold)
        }
    }

    private var separatedTitleUIFont: UIFont {
        switch context.density {
        case .compact: .systemFont(ofSize: 14, weight: .semibold)
        case .standard: .systemFont(ofSize: 16, weight: .semibold)
        case .relaxed: .systemFont(ofSize: 18, weight: .semibold)
        }
    }

    private var separatedBodyUIFont: UIFont {
        switch context.density {
        case .compact: .systemFont(ofSize: 11)
        case .standard: .systemFont(ofSize: 12)
        case .relaxed: .systemFont(ofSize: 13)
        }
    }

    private func titleUIFont(centered: Bool) -> UIFont {
        switch context.density {
        case .compact:
            return .systemFont(ofSize: centered ? 16 : 15, weight: .bold)
        case .standard:
            return .systemFont(ofSize: centered ? 20 : 18, weight: .bold)
        case .relaxed:
            return .systemFont(ofSize: centered ? 28 : 22, weight: .bold)
        }
    }

    private func bodyUIFont(centered: Bool) -> UIFont {
        switch context.density {
        case .compact:
            return .systemFont(ofSize: centered ? 11 : 11, weight: .medium)
        case .standard:
            return .systemFont(ofSize: centered ? 13 : 12, weight: .medium)
        case .relaxed:
            return .systemFont(ofSize: centered ? 15 : 13, weight: .medium)
        }
    }

    private func trimmed(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
