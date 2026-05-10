import SwiftUI
import MapKit
import CoreLocation

struct MapCardSheet: View {
    @Binding var data: MapCardData
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var locationManager = CLLocationManager()
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isSearching = false

    init(data: Binding<MapCardData>) {
        self._data = data
        let center = data.wrappedValue.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        self._selectedCoordinate = State(initialValue: center)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapFullScreen

                VStack(spacing: 0) {
                    searchBarSection
                    Spacer()
                    descriptionSection
                }
                .padding()
            }
            .navigationTitle("选择地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        data.coordinate = selectedCoordinate
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            locationManager.requestWhenInUseAuthorization()
            if let coord = data.coordinate {
                selectedCoordinate = coord
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 300,
                    longitudinalMeters: 300
                ))
            }
        }
    }

    @ViewBuilder
    private var mapFullScreen: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            Annotation("", coordinate: selectedCoordinate) {
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.red)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .offset(y: -5)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var searchBarSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索地点", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        searchLocations()
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchResults, id: \.self) { item in
                        Button {
                            selectSearchResult(item)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "未知地点")
                                        .foregroundColor(.primary)
                                    if let addr = item.placemark.title {
                                        Text(addr)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        Divider()
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxHeight: 200)
            }

            Button {
                useCurrentLocation()
            } label: {
                Label("使用当前地点", systemImage: "location.fill")
                    .font(.subheadline)
                    .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("地点名称", text: $data.locationName)
                .textFieldStyle(.roundedBorder)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            TextField("描述文字", text: $data.descriptionText)
                .textFieldStyle(.roundedBorder)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.bottom, 20)
    }

    private func searchLocations() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let response = response {
                    searchResults = response.mapItems
                }
            }
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        selectedCoordinate = coordinate
        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 300,
            longitudinalMeters: 300
        ))
        data.locationName = item.name ?? data.locationName
        searchText = ""
        searchResults = []
    }

    private func useCurrentLocation() {
        if let location = locationManager.location?.coordinate {
            selectedCoordinate = location
            cameraPosition = .region(MKCoordinateRegion(
                center: location,
                latitudinalMeters: 300,
                longitudinalMeters: 300
            ))
        }
    }
}
