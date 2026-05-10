import SwiftUI

enum WeatherCondition: String, CaseIterable {
    case sunny, partlyCloudy, cloudy, rainy, stormy, snowy, windy, foggy

    var sfSymbol: String {
        switch self {
        case .sunny:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .rainy:        return "cloud.rain.fill"
        case .stormy:       return "cloud.bolt.fill"
        case .snowy:        return "snowflake"
        case .windy:        return "wind"
        case .foggy:        return "cloud.fog.fill"
        }
    }

    var label: String {
        switch self {
        case .sunny:        return "晴天"
        case .partlyCloudy: return "多云转晴"
        case .cloudy:       return "多云"
        case .rainy:        return "雨天"
        case .stormy:       return "雷暴"
        case .snowy:        return "雪天"
        case .windy:        return "大风"
        case .foggy:        return "雾天"
        }
    }

    var color: Color {
        switch self {
        case .sunny:        return Color(red: 1.0, green: 0.72, blue: 0.0)
        case .partlyCloudy: return Color(red: 0.95, green: 0.80, blue: 0.2)
        case .cloudy:       return Color(white: 0.55)
        case .rainy:        return Color(red: 0.3, green: 0.5, blue: 0.9)
        case .stormy:       return Color(red: 0.3, green: 0.2, blue: 0.7)
        case .snowy:        return Color(red: 0.5, green: 0.85, blue: 1.0)
        case .windy:        return Color(red: 0.2, green: 0.7, blue: 0.65)
        case .foggy:        return Color(white: 0.6)
        }
    }
}

struct WeatherCardData {
    var location: String = ""
    var temperature: Double = 22
    var feelsLike: Double = 20
    var condition: WeatherCondition = .sunny
    var humidity: Int = 60
    var high: Double = 25
    var low: Double = 18

    var isEmpty: Bool { location.isEmpty }
    var tempString: String { "\(Int(temperature))°" }
    var highLowString: String { "H:\(Int(high))°  L:\(Int(low))°" }
}

struct WeatherCard: View {
    let size: CardSize
    var data: WeatherCardData?
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let data, !data.isEmpty {
                contentView(data)
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .cardBackground()
        .onTapGesture { onTap?() }
    }

    @ViewBuilder
    private func contentView(_ data: WeatherCardData) -> some View {
        if size == .w4h1 {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(data.tempString)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(data.condition.label)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: data.condition.sfSymbol)
                    .font(.system(size: 28))
                    .foregroundStyle(data.condition.color)
                    .symbolRenderingMode(.multicolor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else if size == .w4h2 {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(data.location)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(data.highLowString)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    Text(data.tempString)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: data.condition.sfSymbol)
                        .font(.system(size: 36))
                        .foregroundStyle(data.condition.color)
                        .symbolRenderingMode(.multicolor)
                        .padding(.bottom, 4)
                }
                Text(data.condition.label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(data.location)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Text(data.tempString)
                        .font(.system(size: 60, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: data.condition.sfSymbol)
                        .font(.system(size: 48))
                        .foregroundStyle(data.condition.color)
                        .symbolRenderingMode(.multicolor)
                        .padding(.bottom, 6)
                }
                Text(data.condition.label)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 16) {
                    Label("\(data.humidity)%", systemImage: "humidity.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Label("体感 \(Int(data.feelsLike))°", systemImage: "thermometer.medium")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(data.highLowString)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        VStack(spacing: size == .w4h1 ? 4 : 8) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: size == .w4h1 ? 22 : 32))
                .foregroundStyle(.secondary.opacity(0.4))
                .symbolRenderingMode(.multicolor)
            if size != .w4h1 {
                Text("点击添加天气")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WeatherCard_4x1: View {
    var data: WeatherCardData?
    var onTap: (() -> Void)?
    var body: some View { WeatherCard(size: .w4h1, data: data, onTap: onTap) }
}

struct WeatherCard_4x2: View {
    var data: WeatherCardData?
    var onTap: (() -> Void)?
    var body: some View { WeatherCard(size: .w4h2, data: data, onTap: onTap) }
}

struct WeatherCard_4x4: View {
    var data: WeatherCardData?
    var onTap: (() -> Void)?
    var body: some View { WeatherCard(size: .w4h4, data: data, onTap: onTap) }
}

#Preview {
    VStack(spacing: 12) {
        WeatherCard_4x1(data: WeatherCardData(location: "北京", temperature: 18, condition: .partlyCloudy))
        WeatherCard_4x2(data: WeatherCardData(location: "上海", temperature: 24, condition: .sunny, humidity: 55, high: 27, low: 19))
        WeatherCard_4x4(data: WeatherCardData(location: "成都", temperature: 16, feelsLike: 14, condition: .rainy, humidity: 82, high: 18, low: 12))
    }
    .frame(width: 393)
    .padding()
}
