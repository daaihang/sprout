import SwiftUI
import UIKit

struct MapTicketCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePlaceCardPayload
    let accent: Color
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .mapTicket, sizeToken: .card)

    var body: some View {
        HStack(spacing: 0) {
            mapStub
                .frame(width: 92, height: 128)

            VStack(alignment: .leading, spacing: 7) {
                Text("MAP TICKET")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent.opacity(0.78))
                    .tracking(1.1)

                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.place"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.18))
                    .lineLimit(metrics.titleLineLimit)

                Text(common.detail)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.38))
                    .lineLimit(metrics.detailLineLimit)

                Spacer(minLength: 0)

                Text(coordinateText)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.42))
                    .lineLimit(metrics.metadataLineLimit)
            }
            .padding(metrics.padding.edgeInsets)
            .frame(width: metrics.preferredSize.width - 92, height: metrics.preferredSize.height, alignment: .leading)
        }
        .background(ticketPaper, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(alignment: .leading) {
            ticketPerforation
                .offset(x: 88)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.brown.opacity(0.16), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.09), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    @ViewBuilder
    private var mapStub: some View {
        if let data = payload.mapSnapshotData, !payload.isPrivacyEnabled, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.08))
                .clipped()
        } else {
            ZStack {
                accent.opacity(0.12)
                mapGrid
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, accent)
            }
        }
    }

    private var mapGrid: some View {
        Canvas { context, size in
            let stroke = StrokeStyle(lineWidth: 1)
            for x in stride(from: 8.0, through: Double(size.width), by: 18.0) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x - 12, y: size.height))
                context.stroke(path, with: .color(accent.opacity(0.18)), style: stroke)
            }
            for y in stride(from: 10.0, through: Double(size.height), by: 20.0) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y + 10))
                context.stroke(path, with: .color(accent.opacity(0.18)), style: stroke)
            }
        }
    }

    private var ticketPaper: Color {
        Color(red: 0.96, green: 0.93, blue: 0.84)
    }

    private var ticketPerforation: some View {
        VStack(spacing: 5) {
            ForEach(0..<15, id: \.self) { _ in
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private var coordinateText: String {
        if let latitude = payload.latitude, let longitude = payload.longitude {
            return String(format: "%.4f, %.4f", latitude, longitude)
        }
        return common.metadata?.trimmedOrNil ?? "No coordinates"
    }
}

struct WeatherStampCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureWeatherCardPayload
    let accent: Color
    var sizeToken: MemoryCardSizeToken = .stamp
    var density: MemoryCardContentDensity = .compact
    var variant: MemoryCardVisualVariant?
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .weatherStamp, sizeToken: .stamp)

    var body: some View {
        Group {
            switch normalizedSize {
            case .stamp:
                stampLayout
            case .strip:
                stripLayout
            case .card:
                cardLayout
            }
        }
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height, alignment: .center)
    }

    private var weatherStyle: CaptureWeatherVisualStyle {
        payload.style ?? .resolve(
            conditionCode: payload.conditionCode,
            condition: [common.title, common.detail].compactMap { $0 }.joined(separator: " "),
            isDaylight: payload.isDaylight
        )
    }

    private var stampInk: Color {
        switch weatherStyle {
        case .sunny, .hot:
            return .orange
        case .rain, .heavyRain, .thunderstorm:
            return .blue
        case .snow, .cold:
            return .cyan
        case .clearNight:
            return .indigo
        case .fog, .cloudy, .wind, .unknown:
            return accent
        }
    }

    private var normalizedSize: MemoryCardSizeToken {
        MemoryCardRecipeLayoutPolicy.normalizedSize(sizeToken, for: .weatherStamp)
    }

    private var resolvedVariant: MemoryCardVisualVariant {
        MemoryCardRecipeLayoutPolicy.resolvedVariant(
            variant,
            for: .weatherStamp,
            size: normalizedSize
        )
    }

    private var symbolName: String {
        payload.symbolName?.trimmedOrNil ?? weatherStyle.symbolName
    }

    private var temperatureToken: String {
        common.title?.trimmedOrNil
            ?? metadataTokens.first(where: { $0.contains("°") })
            ?? "--"
    }

    private var temperatureValueAndUnit: (value: String, unit: String?) {
        let token = temperatureToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return ("--", nil) }

        let noSpace = token.replacingOccurrences(of: " ", with: "")
        if let degreeIndex = noSpace.firstIndex(of: "°") {
            let value = String(noSpace[..<degreeIndex])
            let unit = String(noSpace[degreeIndex...])
            return (value.isEmpty ? token : value, unit.isEmpty ? nil : unit)
        }

        var numberPrefix = ""
        for character in noSpace {
            if character.isNumber || character == "-" || character == "+" || character == "." {
                numberPrefix.append(character)
            } else {
                break
            }
        }
        if !numberPrefix.isEmpty {
            let unit = String(noSpace.dropFirst(numberPrefix.count))
            return (numberPrefix, unit.isEmpty ? nil : unit)
        }
        return (token, nil)
    }

    private var humidityToken: String? {
        metadataToken(
            containingAny: ["humidity", "湿", "%"]
        )
    }

    private var windToken: String? {
        metadataToken(
            containingAny: ["wind", "风", "km/h", "m/s"]
        )
    }

    private var uvToken: String? {
        metadataToken(containingAny: ["uv"])
    }

    private var metadataTokens: [String] {
        let raw = common.metadata?.trimmedOrNil ?? ""
        return raw
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func metadataToken(containingAny needles: [String]) -> String? {
        metadataTokens.first { token in
            let normalized = token.lowercased()
            return needles.contains { needle in
                normalized.contains(needle.lowercased())
            }
        }
    }

    private var stampLayout: some View {
        stampCore
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 2)
            .shadow(color: .black.opacity(0.05), radius: 1, y: 0.5)
    }

    @ViewBuilder
    private var stampCore: some View {
        switch resolvedVariant {
        case .weatherIcon, .automatic:
            Image(systemName: symbolName)
                .font(.system(size: 23, weight: .bold))
                .symbolRenderingMode(.multicolor)
        case .weatherTemperature:
            temperatureDisplay(valueFont: 26, unitFont: 10)
        case .weatherHumidity:
            Text(humidityToken ?? "--")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(stampInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .weatherWind:
            Text(windToken ?? "--")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(stampInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .weatherIconTemperature:
            HStack(spacing: 4) {
                Image(systemName: symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .symbolRenderingMode(.multicolor)
                Text(temperatureToken)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(stampInk)
            }
        case .weatherFullMetrics:
            VStack(spacing: 2) {
                Text(temperatureToken)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(stampInk)
                Text(humidityToken ?? windToken ?? "--")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(stampInk.opacity(0.78))
                    .lineLimit(1)
            }
        }
    }

    private var stripLayout: some View {
        HStack(spacing: 7) {
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.multicolor)
            temperatureDisplay(valueFont: 21, unitFont: 10)
        }
        .padding(metrics.padding.edgeInsets)
        .frame(maxWidth: metrics.preferredSize.width - 12, alignment: .center)
        .background(stampInk.opacity(0.08), in: Capsule())
        .overlay {
            Capsule()
                .stroke(stampInk.opacity(0.42), lineWidth: 1.2)
        }
    }

    private var cardLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbolName)
                    .font(.system(size: 23, weight: .bold))
                    .symbolRenderingMode(.multicolor)
                temperatureDisplay(valueFont: 31, unitFont: 12)
                Spacer(minLength: 0)
            }

            Text(common.detail)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(stampInk.opacity(0.8))
                .lineLimit(metrics.detailLineLimit)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                if let humidityToken {
                    metricChip(humidityToken)
                }
                if let windToken {
                    metricChip(windToken)
                }
                if let uvToken {
                    metricChip(uvToken)
                }
            }
        }
        .padding(metrics.padding.edgeInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(red: 0.95, green: 0.97, blue: 0.93), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(stampInk.opacity(0.36), style: StrokeStyle(lineWidth: 1.3, dash: [5, 4]))
        }
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func metricChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(stampInk.opacity(0.78))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(stampInk.opacity(0.09), in: Capsule())
    }

    private func temperatureDisplay(valueFont: CGFloat, unitFont: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(temperatureValueAndUnit.value)
                .font(.system(size: valueFont, weight: .black, design: .rounded))
                .foregroundStyle(stampInk)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            if let unit = temperatureValueAndUnit.unit {
                Text(unit)
                    .font(.system(size: unitFont, weight: .bold, design: .rounded))
                    .foregroundStyle(stampInk.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct LinkNoteCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureLinkCardPayload
    let accent: Color
    var sizeToken: MemoryCardSizeToken = .card
    var density: MemoryCardContentDensity = .regular
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .linkNote, sizeToken: .card)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                favicon
                Text(hostText)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent.opacity(0.82))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.link"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.18))
                .lineLimit(metrics.titleLineLimit)

            Text(common.detail)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.38))
                .lineLimit(metrics.detailLineLimit)

            Spacer(minLength: 0)

            Text(common.metadata?.trimmedOrNil ?? hostText)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.45))
                .lineLimit(metrics.metadataLineLimit)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(metrics.padding.edgeInsets)
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height, alignment: .leading)
        .background(notePaper, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(accent.opacity(0.55))
                .frame(height: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.05), radius: 7, y: 4)
    }

    private var favicon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(accent.opacity(0.14))
            Image(systemName: "link")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent)
        }
        .frame(width: 24, height: 24)
    }

    private var hostText: String {
        common.metadata?.trimmedOrNil ?? "web clipping"
    }

    private var notePaper: Color {
        Color(red: 0.97, green: 0.96, blue: 0.91)
    }
}

struct TaskNoteCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureTodoCardPayload
    let accent: Color
    var metrics: MemoryCardObjectMetrics = .resolve(recipe: .taskNote, sizeToken: .strip)

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: common.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(accent)

                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.todo"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.18))
                    .lineLimit(metrics.titleLineLimit)
                    .strikethrough(common.isSelected, color: Color(white: 0.35))
            }

            Text(common.detail)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.38))
                .lineLimit(metrics.detailLineLimit)

            Spacer(minLength: 0)
        }
        .padding(metrics.padding.edgeInsets)
        .frame(width: metrics.preferredSize.width, height: metrics.preferredSize.height, alignment: .leading)
        .background(checklistPaper, in: TornSlipShape())
        .overlay {
            TornSlipShape()
                .stroke(Color.brown.opacity(0.14), lineWidth: 0.8)
        }
        .overlay(alignment: .top) {
            tornEdge
        }
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    private var checklistPaper: Color {
        Color(red: 0.99, green: 0.97, blue: 0.84)
    }

    private var tornEdge: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { _ in
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 5, height: 5)
            }
        }
        .offset(y: -2)
    }
}

private struct TornSlipShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + 3))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
        path.addLine(to: CGPoint(x: rect.minX + 4, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
