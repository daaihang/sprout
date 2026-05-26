import Foundation

nonisolated func captureWeatherTemperatureTitle(_ temperatureCelsius: Double) -> String {
    String(format: String(localized: "capture.card.weather.temperature.format"), temperatureCelsius)
}

nonisolated func captureWeatherMetadata(humidity: Double, windSpeedKmh: Double, uvIndex: Int) -> String {
    String(
        format: String(localized: "capture.card.weather.metadata.format"),
        humidity * 100,
        windSpeedKmh,
        uvIndex
    )
}

enum CaptureWeatherVisualStyle: String, CaseIterable, Hashable, Sendable, Identifiable {
    case sunny
    case clearNight
    case cloudy
    case rain
    case heavyRain
    case snow
    case thunderstorm
    case fog
    case wind
    case hot
    case cold
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sunny: return String(localized: "capture.card.weather.sunny")
        case .clearNight: return String(localized: "capture.card.weather.clearNight")
        case .cloudy: return String(localized: "capture.card.weather.cloudy")
        case .rain: return String(localized: "capture.card.weather.rain")
        case .heavyRain: return String(localized: "capture.card.weather.heavyRain")
        case .snow: return String(localized: "capture.card.weather.snow")
        case .thunderstorm: return String(localized: "capture.card.weather.thunderstorm")
        case .fog: return String(localized: "capture.card.weather.fog")
        case .wind: return String(localized: "capture.card.weather.wind")
        case .hot: return String(localized: "capture.card.weather.hot")
        case .cold: return String(localized: "capture.card.weather.cold")
        case .unknown: return String(localized: "capture.card.weather.unknown")
        }
    }

    var symbolName: String {
        switch self {
        case .sunny:
            return "sun.max.fill"
        case .clearNight:
            return "moon.stars.fill"
        case .cloudy:
            return "cloud.fill"
        case .rain:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .fog:
            return "cloud.fog.fill"
        case .wind:
            return "wind"
        case .hot:
            return "thermometer.sun.fill"
        case .cold:
            return "thermometer.low"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var symbolMotion: CaptureWeatherSymbolMotion {
        switch self {
        case .sunny, .hot, .fog, .thunderstorm:
            return .pulse
        case .clearNight:
            return .scale
        case .rain, .heavyRain, .snow:
            return .variableColor
        case .wind:
            return .wiggle
        case .cloudy, .cold:
            return .bounce
        case .unknown:
            return .none
        }
    }

    var motionPattern: CaptureWeatherMotionPattern {
        switch self {
        case .sunny, .hot:
            return .sunGlow
        case .clearNight:
            return .nightTwinkle
        case .rain:
            return .rainFall
        case .heavyRain:
            return .heavyRainFall
        case .snow, .cold:
            return .snowDrift
        case .thunderstorm:
            return .thunderstorm
        case .fog, .cloudy:
            return .fogDrift
        case .wind:
            return .windFlow
        case .unknown:
            return .staticPattern
        }
    }

    func resolvedMotionPattern(reduceMotion: Bool) -> CaptureWeatherMotionPattern {
        reduceMotion ? .staticPattern : motionPattern
    }

    var atmosphereSpec: CaptureWeatherAtmosphereSpec {
        CaptureWeatherAtmosphereSpec(
            style: self,
            palette: atmospherePalette,
            motionPattern: motionPattern,
            intensity: atmosphereIntensity
        )
    }

    func resolvedAtmosphereSpec(reduceMotion: Bool) -> CaptureWeatherAtmosphereSpec {
        var spec = atmosphereSpec
        if reduceMotion {
            spec.motionPattern = .staticPattern
            spec.intensity = min(spec.intensity, 0.42)
        }
        return spec
    }

    private var atmospherePalette: CaptureWeatherAtmospherePalette {
        switch self {
        case .sunny:
            return .warmLight
        case .clearNight:
            return .night
        case .cloudy:
            return .softCloud
        case .rain:
            return .coolRain
        case .heavyRain, .thunderstorm:
            return .storm
        case .snow, .cold:
            return .frost
        case .fog:
            return .fog
        case .wind:
            return .wind
        case .hot:
            return .heat
        case .unknown:
            return .neutral
        }
    }

    private var atmosphereIntensity: Double {
        switch self {
        case .sunny, .clearNight, .cloudy, .fog, .wind:
            return 0.62
        case .rain, .snow:
            return 0.72
        case .heavyRain, .thunderstorm, .hot, .cold:
            return 0.86
        case .unknown:
            return 0.36
        }
    }

    nonisolated static func resolve(
        conditionCode: String?,
        condition: String? = nil,
        temperatureCelsius: Double? = nil,
        windSpeedKmh: Double? = nil,
        isDaylight: Bool? = nil
    ) -> CaptureWeatherVisualStyle {
        if let style = resolveOfficialConditionCode(conditionCode, isDaylight: isDaylight) {
            return style
        }
        return resolve(
            condition: condition,
            temperatureCelsius: temperatureCelsius,
            windSpeedKmh: windSpeedKmh,
            isNight: isDaylight == false
        )
    }

    nonisolated static func resolve(
        condition: String?,
        temperatureCelsius: Double? = nil,
        windSpeedKmh: Double? = nil,
        isNight: Bool = false
    ) -> CaptureWeatherVisualStyle {
        let value = condition?.lowercased() ?? ""

        if value.contains("thunder") || value.contains("storm") || value.contains("雷") || value.contains("台风") || value.contains("飓风") || value.contains("冰雹") {
            return .thunderstorm
        }
        if value.contains("heavy rain") || value.contains("downpour") || value.contains("暴雨") || value.contains("大雨") {
            return .heavyRain
        }
        if value.contains("snow") || value.contains("sleet") || value.contains("雪") || value.contains("雨夹雪") || value.contains("冻雨") {
            return .snow
        }
        if value.contains("rain") || value.contains("shower") || value.contains("drizzle") || value.contains("雨") || value.contains("阵雨") {
            return .rain
        }
        if value.contains("fog") || value.contains("mist") || value.contains("haze") || value.contains("雾") || value.contains("霾") || value.contains("烟") {
            return .fog
        }
        if value.contains("wind") || value.contains("breezy") || value.contains("风") || (windSpeedKmh ?? 0) >= 40 {
            return .wind
        }
        if value.contains("hot") || value.contains("炎热") {
            return .hot
        }
        if let temperatureCelsius, temperatureCelsius >= 32 {
            return .hot
        }
        if value.contains("frigid") || value.contains("cold") || value.contains("寒冷") {
            return .cold
        }
        if let temperatureCelsius, temperatureCelsius <= 2 {
            return .cold
        }
        if value.contains("cloud") || value.contains("overcast") || value.contains("多云") || value.contains("阴") {
            return .cloudy
        }
        if value.contains("clear") || value.contains("sun") || value.contains("fair") || value.contains("晴") || value.contains("无云") {
            return isNight ? .clearNight : .sunny
        }
        return isNight ? .clearNight : .unknown
    }

    private nonisolated static func resolveOfficialConditionCode(
        _ conditionCode: String?,
        isDaylight: Bool?
    ) -> CaptureWeatherVisualStyle? {
        guard let normalized = conditionCode?.normalizedWeatherConditionCode else { return nil }
        switch normalized {
        case "clear", "mostlyclear":
            return isDaylight == false ? .clearNight : .sunny
        case "partlycloudy", "mostlycloudy", "cloudy":
            return .cloudy
        case "foggy", "haze", "smoky", "blowingdust":
            return .fog
        case "breezy", "windy":
            return .wind
        case "drizzle", "rain", "sunshowers":
            return .rain
        case "heavyrain":
            return .heavyRain
        case "isolatedthunderstorms", "scatteredthunderstorms", "strongstorms", "thunderstorms", "tropicalstorm", "hurricane", "hail":
            return .thunderstorm
        case "flurries", "sleet", "snow", "sunflurries", "wintrymix", "blizzard", "blowingsnow", "freezingdrizzle", "freezingrain", "heavysnow":
            return .snow
        case "hot":
            return .hot
        case "frigid":
            return .cold
        default:
            return nil
        }
    }
}

enum CaptureWeatherSymbolMotion: String, Hashable, Sendable {
    case none
    case pulse
    case variableColor
    case wiggle
    case bounce
    case scale
}

enum CaptureWeatherSymbolMotionLevel: String, CaseIterable, Hashable, Sendable, Identifiable {
    case staticOnly
    case subtle
    case enhanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .staticOnly:
            return String(localized: "capture.card.motion.static")
        case .subtle:
            return String(localized: "capture.card.motion.subtle")
        case .enhanced:
            return String(localized: "capture.card.motion.enhanced")
        }
    }
}

enum CaptureWeatherMotionPattern: String, Hashable, Sendable {
    case staticPattern
    case sunGlow
    case nightTwinkle
    case rainFall
    case heavyRainFall
    case snowDrift
    case thunderstorm
    case fogDrift
    case windFlow
}

enum CaptureWeatherAtmospherePalette: String, Hashable, Sendable {
    case warmLight
    case night
    case softCloud
    case coolRain
    case storm
    case frost
    case fog
    case wind
    case heat
    case neutral
}

struct CaptureWeatherAtmosphereSpec: Hashable, Sendable {
    let style: CaptureWeatherVisualStyle
    let palette: CaptureWeatherAtmospherePalette
    var motionPattern: CaptureWeatherMotionPattern
    var intensity: Double
}


private extension String {
    nonisolated var normalizedWeatherConditionCode: String? {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return normalized.isEmpty ? nil : String(normalized)
    }
}
