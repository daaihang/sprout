import Foundation
import MapKit

struct PlaceContextService: ContextPlaceDraftProviding {
    func capturePlace(location: ContextLocationSnapshot) async -> PlaceContextCollection {
        let startedAt = Date()
        do {
            let mapItem = try await reverseGeocode(location: location)
            let formattedAddress = mapItem?.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
            let localitySummary = formattedAddress
                ?? mapItem?.addressRepresentations?.cityWithContext(.full)
                ?? mapItem?.address?.shortAddress
                ?? mapItem?.address?.fullAddress
                ?? location.coordinateSummary
            let draft = CaptureArtifactDraft.location(
                title: mapItem?.name,
                summary: localitySummary,
                latitude: location.latitude,
                longitude: location.longitude
            )
            return PlaceContextCollection(
                draft: draft,
                diagnostic: .success(.placeGeocoding, message: localitySummary, startedAt: startedAt)
            )
        } catch {
            return PlaceContextCollection(
                draft: Self.fallbackDraft(location: location),
                diagnostic: .failed(.placeGeocoding, error: error, startedAt: startedAt)
            )
        }
    }

    static func fallbackDraft(location: ContextLocationSnapshot) -> CaptureArtifactDraft {
        .location(
            title: nil,
            summary: location.coordinateSummary,
            latitude: location.latitude,
            longitude: location.longitude
        )
    }

    private func reverseGeocode(location: ContextLocationSnapshot) async throws -> MKMapItem? {
        guard let request = MKReverseGeocodingRequest(location: location.clLocation) else {
            return nil
        }
        return try await request.mapItems.first
    }
}
