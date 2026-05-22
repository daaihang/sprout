import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let initialSelection: CaptureArtifactDraft?
    let onSelect: (CaptureArtifactDraft) -> Void

    @State private var selectedDraft: CaptureArtifactDraft?
    @State private var isCapturingCurrentLocation = false
    @State private var searchQuery = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var selectedMapCoordinate: CLLocationCoordinate2D?
    @State private var errorMessage: String?
    @State private var locationService = LocationContextService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await captureCurrentLocation() }
                    } label: {
                        Label(
                            isCapturingCurrentLocation ? String(localized: "capture.location.currentLoading") : String(localized: "capture.location.useCurrent"),
                            systemImage: "location.fill"
                        )
                    }
                    .disabled(isCapturingCurrentLocation)

                    TextField("capture.location.searchPlaceholder", text: $searchQuery)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await searchLocations() }
                        }

                    Button {
                        Task { await searchLocations() }
                    } label: {
                        Label(isSearching ? String(localized: "capture.location.searching") : String(localized: "capture.location.search"), systemImage: "magnifyingglass")
                    }
                    .disabled(isSearching || searchQuery.trimmedOrNil == nil)

                    if isCapturingCurrentLocation || isSearching {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(isSearching ? String(localized: "capture.location.searching") : String(localized: "capture.location.currentLoading"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("capture.location.findHeader")
                } footer: {
                    Text("capture.location.pickerFooter")
                }

                if !searchResults.isEmpty {
                    Section("capture.location.resultsHeader") {
                        ForEach(searchResults) { result in
                            Button {
                                select(result.draft)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(result.title, systemImage: "mappin")
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    if let subtitle = result.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    MapReader { proxy in
                        Map(position: $mapCameraPosition) {
                            if let selectedMapCoordinate {
                                Marker(String(localized: "capture.location.selectedPoint"), coordinate: selectedMapCoordinate)
                            }
                        }
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture { point in
                            if let coordinate = proxy.convert(point, from: .local) {
                                selectMapCoordinate(coordinate)
                            }
                        }
                    }
                } header: {
                    Text("capture.location.mapHeader")
                } footer: {
                    Text("capture.location.mapFooter")
                }

                Section("capture.location.selectionHeader") {
                    if let selectedDraft {
                        Label(selectedDraft.captureSummary, systemImage: selectedDraft.captureIconName)
                            .font(.subheadline)
                            .lineLimit(4)
                    } else {
                        Text("capture.location.pickHint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("capture.location.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedDraft == nil {
                    selectedDraft = initialSelection
                    focusMap(on: initialSelection)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("capture.location.done") {
                        if let selectedDraft {
                            onSelect(selectedDraft)
                        }
                        dismiss()
                    }
                    .disabled(selectedDraft == nil)
                }
            }
        }
    }

    private func captureCurrentLocation() async {
        guard !isCapturingCurrentLocation else { return }
        isCapturingCurrentLocation = true
        errorMessage = nil
        defer { isCapturingCurrentLocation = false }

        if locationService.authorizationStatus == .notDetermined {
            locationService.requestPermission()
            try? await Task.sleep(for: .milliseconds(300))
        }

        guard let draft = await locationService.captureCurrentLocation() else {
            errorMessage = String(localized: "capture.location.currentUnavailable")
            return
        }
        select(draft)
    }

    private func searchLocations() async {
        guard let query = searchQuery.trimmedOrNil, !isSearching else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        if let location = await locationService.currentLocation() {
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 20_000,
                longitudinalMeters: 20_000
            )
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems.prefix(8).map(LocationSearchResult.init(mapItem:))
            if searchResults.isEmpty {
                errorMessage = String(localized: "capture.location.noResults")
            }
        } catch {
            searchResults = []
            errorMessage = error.localizedDescription
        }
    }

    private func select(_ draft: CaptureArtifactDraft) {
        selectedDraft = draft
        focusMap(on: draft)
    }

    private func selectMapCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let summary = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
        select(.location(
            title: String(localized: "capture.location.selectedPoint"),
            summary: summary,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
    }

    private func focusMap(on draft: CaptureArtifactDraft?) {
        guard case let .location(_, _, latitude, longitude, _) = draft,
              let latitude,
              let longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        selectedMapCoordinate = coordinate
        mapCameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 800,
            longitudinalMeters: 800
        ))
    }
}

private struct LocationSearchResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let draft: CaptureArtifactDraft

    init(mapItem: MKMapItem) {
        let fallbackTitle = String(localized: "capture.location.searchResult")
        let coordinate: CLLocationCoordinate2D
        let resolvedTitle: String
        let resolvedSubtitle: String?

        coordinate = mapItem.location.coordinate
        resolvedTitle = mapItem.name?.trimmedOrNil
            ?? mapItem.address?.shortAddress?.trimmedOrNil
            ?? mapItem.address?.fullAddress.trimmedOrNil
            ?? fallbackTitle
        resolvedSubtitle = mapItem.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)?.trimmedOrNil
            ?? mapItem.address?.fullAddress.trimmedOrNil

        self.title = resolvedTitle
        self.subtitle = resolvedSubtitle
        self.draft = .location(
            title: resolvedTitle,
            summary: resolvedSubtitle ?? String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}
