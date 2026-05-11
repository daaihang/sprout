import SwiftUI
import Combine
import WeatherKit
import CoreLocation

enum WeatherCondition: String, CaseIterable, Codable {
    case sunny, partlyCloudy, cloudy, rainy, stormy, snowy, windy, foggy

    var sfSymbol: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .stormy: return "cloud.bolt.fill"
        case .snowy: return "snowflake"
        case .windy: return "wind"
        case .foggy: return "cloud.fog.fill"
        }
    }

    var label: String {
        switch self {
        case .sunny: return localizedString("weather.condition.sunny", default: "Sunny")
        case .partlyCloudy: return localizedString("weather.condition.partly_cloudy", default: "Partly Cloudy")
        case .cloudy: return localizedString("weather.condition.cloudy", default: "Cloudy")
        case .rainy: return localizedString("weather.condition.rainy", default: "Rainy")
        case .stormy: return localizedString("weather.condition.stormy", default: "Stormy")
        case .snowy: return localizedString("weather.condition.snowy", default: "Snowy")
        case .windy: return localizedString("weather.condition.windy", default: "Windy")
        case .foggy: return localizedString("weather.condition.foggy", default: "Foggy")
        }
    }

    var color: Color {
        switch self {
        case .sunny: return Color(red: 1.0, green: 0.72, blue: 0.0)
        case .partlyCloudy: return Color(red: 0.95, green: 0.80, blue: 0.2)
        case .cloudy: return Color(white: 0.55)
        case .rainy: return Color(red: 0.3, green: 0.5, blue: 0.9)
        case .stormy: return Color(red: 0.3, green: 0.2, blue: 0.7)
        case .snowy: return Color(red: 0.5, green: 0.85, blue: 1.0)
        case .windy: return Color(red: 0.2, green: 0.7, blue: 0.65)
        case .foggy: return Color(white: 0.6)
        }
    }
}

struct WeatherCardData {
    var location: String = ""
    var coordinate: CLLocationCoordinate2D?
    var temperature: Double = 22
    var feelsLike: Double = 20
    var condition: WeatherCondition = .sunny
    var humidity: Int = 60
    var high: Double = 25
    var low: Double = 18
    var observedAt: Date?
    var source: WeatherSnapshotSource = .manual
    var liveData: LiveWeatherData?

    var isEmpty: Bool { location.isEmpty }
    var tempString: String { "\(Int(temperature))°" }
    var highLowString: String { "H:\(Int(high))°  L:\(Int(low))°" }
    var liveSummary: String? {
        guard let liveData else { return nil }
        return localizedString("weather.current", default: "Now %d° %@", arguments: [Int(liveData.temperature), liveData.condition.label])
    }
}

struct LiveWeatherData: Equatable {
    var temperature: Double
    var condition: WeatherCondition
    var fetchedAt: Date
}

enum WeatherSnapshotSource: String, Codable {
    case currentLocationAuto = "current_location_auto"
    case manual
}

extension WeatherCondition {
    init(from weatherKitCondition: WeatherKit.WeatherCondition) {
        switch weatherKitCondition {
        case .clear, .mostlyClear, .hot: self = .sunny
        case .partlyCloudy: self = .partlyCloudy
        case .cloudy, .mostlyCloudy: self = .cloudy
        case .rain, .drizzle, .heavyRain, .isolatedThunderstorms, .scatteredThunderstorms: self = .rainy
        case .thunderstorms: self = .stormy
        case .snow, .heavySnow, .flurries, .blizzard, .blowingSnow, .freezingDrizzle, .freezingRain, .sleet, .wintryMix: self = .snowy
        case .windy, .blowingDust: self = .windy
        case .foggy, .haze, .smoky: self = .foggy
        default: self = .cloudy
        }
    }
}

@MainActor
class WeatherDataService: ObservableObject {
    private let service = WeatherService()
    private let locationManager = CLLocationManager()
    private var delegateBridge: LocationDelegate?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = locationManager.authorizationStatus
        let delegateBridge = LocationDelegate(service: self)
        self.delegateBridge = delegateBridge
        locationManager.delegate = delegateBridge
    }

    func requestLocationPermission() { locationManager.requestWhenInUseAuthorization() }
    func updateAuthorizationStatus(_ status: CLAuthorizationStatus) { authorizationStatus = status }
    func getCurrentLocation() -> CLLocation? { locationManager.location }
    func hasUsableAuthorization() -> Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func fetchWeather(for location: CLLocation) async throws -> WeatherCardData {
        let weather = try await service.weather(for: location)
        let locationName = await reverseGeocodedLocationName(for: location)

        let current = weather.currentWeather
        return WeatherCardData(
            location: locationName,
            coordinate: location.coordinate,
            temperature: current.temperature.value,
            feelsLike: current.apparentTemperature.value,
            condition: WeatherCondition(from: current.condition),
            humidity: Int(current.humidity * 100),
            high: weather.dailyForecast.first?.highTemperature.value ?? current.temperature.value,
            low: weather.dailyForecast.first?.lowTemperature.value ?? current.temperature.value,
            observedAt: Date(),
            source: .currentLocationAuto
        )
    }

    func fetchLiveWeather(for coordinate: CLLocationCoordinate2D) async throws -> LiveWeatherData {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let weather = try await service.weather(for: location)
        let current = weather.currentWeather
        return LiveWeatherData(
            temperature: current.temperature.value,
            condition: WeatherCondition(from: current.condition),
            fetchedAt: Date()
        )
    }

    func errorMessage(for error: Error) -> String {
        let nsError = error as NSError
        let description = nsError.localizedDescription.lowercased()
        let debugDescription = (nsError.userInfo[NSDebugDescriptionErrorKey] as? String)?.lowercased() ?? ""
        let combined = description + " " + debugDescription

        if combined.contains("weatherkit.authservice") || combined.contains("xpcconnectionfailed") {
            return localizedString("weather.error.auth", default: "WeatherKit auth service is unavailable. Confirm WeatherKit is enabled for the App ID and target, and try again on device if needed.")
        }

        if combined.contains("network") || combined.contains("internet") {
            return localizedString("weather.error.network", default: "Network is unavailable, so weather cannot be loaded right now.")
        }

        if nsError.domain == kCLErrorDomain as String {
            return localizedString("weather.error.location", default: "Location is unavailable, so weather for your current position cannot be loaded.")
        }

        return localizedString("weather.error.generic", default: "Unable to load weather right now. Please try again later.")
    }

    private func reverseGeocodedLocationName(for location: CLLocation) async -> String {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                if let locality = placemark.locality, !locality.isEmpty {
                    if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
                        return "\(administrativeArea) \(locality)"
                    }
                    return locality
                }

                if let administrativeArea = placemark.administrativeArea, !administrativeArea.isEmpty {
                    return administrativeArea
                }

                if let name = placemark.name, !name.isEmpty {
                    return name
                }
            }
        } catch {
            print("Reverse geocode failed: \(error)")
        }

        return formattedCoordinate(location.coordinate)
    }

    private func formattedCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    weak var service: WeatherDataService?
    init(service: WeatherDataService) { self.service = service }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.service?.updateAuthorizationStatus(manager.authorizationStatus) }
    }
}

struct WeatherCard: View {
    var data: WeatherCardData?
    var onTap: (() -> Void)?

    @StateObject private var weatherService = WeatherDataService()
    @State private var cardData: WeatherCardData?
    @State private var isLoading = false
    @State private var hasAttemptedLiveRefresh = false
    @State private var weatherErrorMessage: String?

    var body: some View {
        Group {
            if let displayData = cardData ?? data, !displayData.isEmpty {
                GeometryReader { geo in
                    contentView(displayData, metrics: CardLayoutMetrics(containerSize: geo.size))
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardBackground()
        .onTapGesture {
            onTap?()
        }
        .task { await fetchWeatherIfNeeded() }
        .onChange(of: weatherService.authorizationStatus) { _, status in
            if weatherService.hasUsableAuthorization() {
                Task { await refreshLiveWeatherIfNeeded(force: false) }
            }
        }
    }

    private func fetchWeatherIfNeeded() async {
        if let data, !data.isEmpty {
            cardData = data
            await refreshLiveWeatherIfNeeded(force: false)
        }
    }

    private func refreshLiveWeatherIfNeeded(force: Bool) async {
        guard var snapshot = cardData ?? data else { return }
        guard let coordinate = snapshot.coordinate else { return }
        guard shouldShowLiveWeather(for: snapshot) || force else { return }
        guard force || !hasAttemptedLiveRefresh else { return }

        if !weatherService.hasUsableAuthorization() {
            weatherService.requestLocationPermission()
            return
        }

        hasAttemptedLiveRefresh = true
        do {
            snapshot.liveData = try await weatherService.fetchLiveWeather(for: coordinate)
            cardData = snapshot
        } catch {
            weatherErrorMessage = weatherService.errorMessage(for: error)
            print("Live weather refresh error: \(error)")
        }
    }

    private func shouldShowLiveWeather(for snapshot: WeatherCardData) -> Bool {
        guard let observedAt = snapshot.observedAt else { return false }
        return Calendar.current.isDateInToday(observedAt)
    }

    @ViewBuilder
    private func contentView(_ data: WeatherCardData, metrics: CardLayoutMetrics) -> some View {
        if metrics.isCompactHeight {
            compactContent(data, metrics: metrics)
        } else if metrics.isMediumHeight || metrics.isCompactWidth {
            mediumContent(data, metrics: metrics)
        } else {
            expandedContent(data, metrics: metrics)
        }
    }

    private func compactContent(_ data: WeatherCardData, metrics: CardLayoutMetrics) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(compactLocationText(for: data))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(data.tempString)
                        .font(.system(size: metrics.isCompactWidth ? 24 : 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(data.condition.label)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: data.condition.sfSymbol)
                .font(.system(size: metrics.isCompactWidth ? 22 : 26))
                .foregroundStyle(data.condition.color)
                .symbolRenderingMode(.multicolor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func mediumContent(_ data: WeatherCardData, metrics: CardLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(compactLocationText(for: data))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(data.condition.label)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: data.condition.sfSymbol)
                    .font(.system(size: metrics.isWideWidth ? 32 : 28))
                    .foregroundStyle(data.condition.color)
                    .symbolRenderingMode(.multicolor)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(data.tempString)
                    .font(.system(size: metrics.isWideWidth ? 46 : 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(data.highLowString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(localizedString("weather.feels_like", default: "Feels like %d°", arguments: [Int(data.feelsLike)]))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.88))
                }
            }

            if let liveSummary = data.liveSummary {
                Text(liveSummary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
    }

    private func expandedContent(_ data: WeatherCardData, metrics: CardLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(data.location.isEmpty ? localizedString("weather.current_location", default: "Current Location") : data.location)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(data.condition.label)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: data.condition.sfSymbol)
                        .font(.system(size: metrics.isWideWidth ? 50 : 38))
                        .foregroundStyle(data.condition.color)
                        .symbolRenderingMode(.multicolor)
                    Text(data.highLowString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(data.tempString)
                .font(.system(size: metrics.isWideWidth ? 62 : 50, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 14) {
                compactMetric(systemImage: "thermometer.medium", text: localizedString("weather.feels_like", default: "Feels like %d°", arguments: [Int(data.feelsLike)]))
                compactMetric(systemImage: "humidity.fill", text: "\(data.humidity)%")
                Spacer(minLength: 0)
            }

            if let liveSummary = data.liveSummary {
                Text(liveSummary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let observedAt = data.observedAt {
                Text(localizedString("weather.observed_at", default: "Captured at %@", arguments: [observedAt.formatted(date: .omitted, time: .shortened)]))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.82))
                    .lineLimit(1)
            }

            if let weatherErrorMessage {
                Text(weatherErrorMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .padding(16)
    }

    private func compactMetric(systemImage: String, text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private func compactLocationText(for data: WeatherCardData) -> String {
        let base = data.location.isEmpty ? localizedString("weather.current_location", default: "Current Location") : data.location
        if base.count <= 10 {
            return base
        }
        return String(base.prefix(10))
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .symbolRenderingMode(.multicolor)
            }
            Text(localizedString("weather.placeholder", default: "Weather is captured when saved"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
