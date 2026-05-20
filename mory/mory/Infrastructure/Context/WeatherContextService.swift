import Foundation
import WeatherKit
import CoreLocation

final class WeatherContextService: Sendable {

    func captureCurrentWeather(location: CLLocation) async -> CaptureArtifactDraft? {
        guard let weather = try? await WeatherService.shared.weather(for: location) else { return nil }
        let current = weather.currentWeather

        return .weather(
            condition: current.condition.description,
            temperatureCelsius: current.temperature.converted(to: .celsius).value,
            humidity: current.humidity,
            windSpeedKmh: current.wind.speed.converted(to: .kilometersPerHour).value,
            uvIndex: current.uvIndex.value,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            conditionCode: current.condition.rawValue,
            symbolName: current.symbolName,
            isDaylight: current.isDaylight
        )
    }
}
