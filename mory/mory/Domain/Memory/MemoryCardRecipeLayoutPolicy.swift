import Foundation

enum MemoryCardContentDensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case compact
    case regular
    case expanded

    var id: String { rawValue }
}

enum MemoryCardRecipeLayoutPolicy {
    static func defaultDensity(for recipe: MemoryCardVisualRecipe) -> MemoryCardContentDensity {
        switch recipe {
        case .weatherStamp, .affectCard, .statusNote, .cassette, .vinyl, .taskNote:
            return .compact
        case .notebook:
            return .expanded
        case .polaroid, .filmFrame, .livePhotoPrint, .mapTicket, .linkNote, .personCard, .bundlePacket:
            return .regular
        }
    }

    static func supportedDensities(for recipe: MemoryCardVisualRecipe) -> [MemoryCardContentDensity] {
        switch recipe {
        case .notebook:
            return [.regular, .expanded]
        case .weatherStamp, .affectCard, .statusNote:
            return [.compact, .regular]
        default:
            return MemoryCardContentDensity.allCases
        }
    }

    static func normalizedDensity(
        _ density: MemoryCardContentDensity?,
        for recipe: MemoryCardVisualRecipe
    ) -> MemoryCardContentDensity {
        guard let density else {
            return defaultDensity(for: recipe)
        }
        return supportedDensities(for: recipe).contains(density) ? density : defaultDensity(for: recipe)
    }

    static func supportedVariants(
        for recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity
    ) -> [MemoryCardVisualVariant] {
        guard recipe == .weatherStamp else {
            return [.automatic]
        }

        switch normalizedDensity(density, for: recipe) {
        case .compact:
            return [.automatic, .weatherIcon, .weatherTemperature, .weatherHumidity, .weatherWind]
        case .regular:
            return [.automatic, .weatherIconTemperature]
        case .expanded:
            return [.automatic, .weatherFullMetrics]
        }
    }

    static func defaultVariant(
        for recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity
    ) -> MemoryCardVisualVariant {
        guard recipe == .weatherStamp else {
            return .automatic
        }

        switch normalizedDensity(density, for: recipe) {
        case .compact:
            return .weatherIcon
        case .regular:
            return .weatherIconTemperature
        case .expanded:
            return .weatherFullMetrics
        }
    }

    static func normalizedVariant(
        _ variant: MemoryCardVisualVariant?,
        for recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity? = nil
    ) -> MemoryCardVisualVariant? {
        let resolvedDensity = normalizedDensity(density, for: recipe)
        guard let variant, variant != .automatic else {
            return nil
        }
        if supportedVariants(for: recipe, density: resolvedDensity).contains(variant) {
            return variant
        }
        let fallback = defaultVariant(for: recipe, density: resolvedDensity)
        return fallback == .automatic ? nil : fallback
    }

    static func resolvedVariant(
        _ variant: MemoryCardVisualVariant?,
        for recipe: MemoryCardVisualRecipe,
        density: MemoryCardContentDensity? = nil
    ) -> MemoryCardVisualVariant {
        let resolvedDensity = normalizedDensity(density, for: recipe)
        if let normalized = normalizedVariant(variant, for: recipe, density: resolvedDensity) {
            return normalized
        }
        return defaultVariant(for: recipe, density: resolvedDensity)
    }
}
