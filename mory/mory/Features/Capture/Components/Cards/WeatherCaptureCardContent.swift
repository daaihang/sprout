import SwiftUI

struct WeatherCaptureCardContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let common: CaptureCardCommonDisplay
    let payload: CaptureWeatherCardPayload
    let accent: Color
    let context: CaptureCardRenderContext
    let reduceMotionOverride: Bool?
    let symbolMotionLevel: CaptureWeatherSymbolMotionLevel
    let atmosphereIntensityScale: Double
    let highContrast: Bool

    var body: some View {
        if context.isSimple {
            CaptureCardCapsuleRow(
                iconName: payload.symbolName?.trimmedOrNil ?? weatherStyle.symbolName,
                title: common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.weather"),
                subtitle: common.detail.trimmedOrNil,
                accent: accent
            )
            .background {
                WeatherAtmosphereView(
                    spec: weatherAtmosphereSpec,
                    isReduceMotionEnabled: resolvedReduceMotion
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(common.title?.trimmedOrNil ?? String(localized: "capture.card.kind.weather"))
                        .font(.system(size: 35, weight: .bold, design: .rounded))
                        .foregroundStyle(legibility.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 8)
                    weatherIcon
                }

                Text(common.detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(legibility.secondaryText)
                    .lineLimit(context.metrics.detailLineLimit)
                    .multilineTextAlignment(.leading)
            }
            .padding(context.metrics.padding.edgeInsets)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .shadow(color: legibility.shadow, radius: 3, y: 1)
            .background {
                WeatherAtmosphereView(
                    spec: weatherAtmosphereSpec,
                    isReduceMotionEnabled: resolvedReduceMotion
                )
            }
        }
    }

    private var weatherStyle: CaptureWeatherVisualStyle {
        payload.style ?? .resolve(
            conditionCode: payload.conditionCode,
            condition: [common.title, common.detail].compactMap { $0 }.joined(separator: " "),
            isDaylight: payload.isDaylight
        )
    }

    private var legibility: CaptureCardLegibility {
        CaptureCardLegibility.weather(style: weatherStyle, highContrast: highContrast)
    }

    @ViewBuilder
    private var weatherIcon: some View {
        switch resolvedSymbolMotion {
        case .none:
            weatherIconBase
        case .pulse:
            weatherIconBase.symbolEffect(.pulse, options: .repeating, isActive: !resolvedReduceMotion)
        case .variableColor:
            weatherIconBase.symbolEffect(.variableColor, options: .repeating, isActive: !resolvedReduceMotion)
        case .wiggle:
            weatherIconBase.symbolEffect(.wiggle, options: .repeating, isActive: !resolvedReduceMotion)
        case .bounce:
            weatherIconBase.symbolEffect(.bounce, options: .repeating, isActive: !resolvedReduceMotion)
        case .scale:
            weatherIconBase.symbolEffect(.scale, options: .repeating, isActive: !resolvedReduceMotion)
        }
    }

    private var weatherIconBase: some View {
        Image(systemName: payload.symbolName?.trimmedOrNil ?? weatherStyle.symbolName)
            .font(.system(size: 27, weight: .semibold))
            .symbolRenderingMode(.multicolor)
            .frame(width: 32, height: 32)
    }

    private var resolvedReduceMotion: Bool {
        reduceMotionOverride ?? reduceMotion
    }

    private var weatherAtmosphereSpec: CaptureWeatherAtmosphereSpec {
        var spec = weatherStyle.resolvedAtmosphereSpec(reduceMotion: resolvedReduceMotion)
        spec.intensity = min(1, max(0.2, spec.intensity * atmosphereIntensityScale))
        return spec
    }

    private var resolvedSymbolMotion: CaptureWeatherSymbolMotion {
        guard !resolvedReduceMotion else { return .none }
        switch symbolMotionLevel {
        case .staticOnly:
            return .none
        case .subtle:
            switch weatherStyle {
            case .sunny, .hot, .clearNight:
                return .scale
            case .fog, .cloudy, .cold:
                return .pulse
            case .rain, .heavyRain, .snow, .thunderstorm, .wind, .unknown:
                return .none
            }
        case .enhanced:
            return weatherStyle.symbolMotion
        }
    }
}
