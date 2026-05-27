import SwiftUI
import UIKit

struct MapTicketCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CapturePlaceCardPayload
    let accent: Color

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
                    .lineLimit(2)

                Text(common.detail)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.38))
                    .lineLimit(2)

                Spacer(minLength: 0)

                Text(coordinateText)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.42))
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 142, height: 128, alignment: .leading)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.weather"))
                    .font(.system(size: 33, weight: .black, design: .rounded))
                    .foregroundStyle(stampInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Spacer(minLength: 6)

                Image(systemName: payload.symbolName?.trimmedOrNil ?? weatherStyle.symbolName)
                    .font(.system(size: 27, weight: .bold))
                    .symbolRenderingMode(.multicolor)
            }

            Text(common.detail)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(stampInk.opacity(0.78))
                .lineLimit(2)

            HStack(spacing: 5) {
                ForEach(metricTokens, id: \.self) { token in
                    Text(token)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(stampInk.opacity(0.75))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(stampInk.opacity(0.08), in: Capsule())
                }
            }
        }
        .padding(13)
        .frame(width: 178, height: 132, alignment: .leading)
        .background(stampPaper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(stampInk.opacity(0.36), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
        .rotationEffect(.degrees(-2))
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
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

    private var stampPaper: Color {
        Color(red: 0.95, green: 0.97, blue: 0.93)
    }

    private var metricTokens: [String] {
        let raw = common.metadata?.trimmedOrNil
        let parts = raw?.components(separatedBy: " · ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
        return Array((parts.isEmpty ? ["WEATHER", "LOCAL"] : parts).prefix(3))
    }
}

struct LinkNoteCaptureCardContent: View {
    let common: CaptureCardCommonDisplay
    let payload: CaptureLinkCardPayload
    let accent: Color

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
                .lineLimit(2)

            Text(common.detail)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.38))
                .lineLimit(3)

            Spacer(minLength: 0)

            Text(common.metadata?.trimmedOrNil ?? hostText)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.45))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(13)
        .frame(width: 214, height: 148, alignment: .leading)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: common.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(accent)

                Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.todo"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.18))
                    .lineLimit(2)
                    .strikethrough(common.isSelected, color: Color(white: 0.35))
            }

            Text(common.detail)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.38))
                .lineLimit(4)

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(width: 174, height: 136, alignment: .leading)
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
