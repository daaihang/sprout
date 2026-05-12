import SwiftUI
import PhotosUI
import UIKit
import MusicKit

extension CardDebugView {
    @ViewBuilder
    var photoControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                Label(
                    selectedPhotoItems.isEmpty
                        ? t("common.debug.select_photos", "Select Photos")
                        : t("common.debug.selected_photos", "Selected %@ Photos", selectedPhotoItems.count),
                    systemImage: "photo.on.rectangle.angled"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .onChange(of: selectedPhotoItems) { _, newItems in
                loadImages(from: newItems)
            }

            if isLoadingImages {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            TextField(t("common.location_name", "Location Name"), text: $photoData.locationName)
            TextField(t("common.title", "Title"), text: Binding(
                get: { photoData.aiDescription ?? "" },
                set: { photoData.aiDescription = $0 }
            ))
            TextField(t("common.description", "Description"), text: $photoData.descriptionText, axis: .vertical)
            TextField(t("common.debug.trailing_info", "Trailing Info"), text: $photoData.trailingInfoText)

            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                selectedPhotoItems = []
                photoData = PhotoCardData()
            }
        }
    }

    @ViewBuilder
    var mapControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            Button {
                isShowingMapSheet = true
            } label: {
                Label(t("common.debug.edit_location", "Edit Location"), systemImage: "map")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)

            TextField(t("common.location_name", "Location Name"), text: $mapData.locationName)
            TextField(t("common.description", "Description"), text: $mapData.descriptionText, axis: .vertical)

            if let coordinate = mapData.coordinate {
                LabeledContent("Lat") { Text(String(format: "%.4f", coordinate.latitude)) }
                LabeledContent("Lng") { Text(String(format: "%.4f", coordinate.longitude)) }
            } else {
                ContentUnavailableView(
                    t("common.location_name", "Location Name"),
                    systemImage: "mappin.slash",
                    description: Text(t("common.debug.edit_location", "Edit Location"))
                )
            }

            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                mapData = MapCardData()
            }
        }
    }

    @ViewBuilder
    var musicControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            HStack {
                Label(musicAuthStatusText, systemImage: musicAuthStatusIcon)
                    .foregroundStyle(musicAuthStatusColor)
                Spacer()
                if musicService.authorizationStatus == .notDetermined {
                    Button(t("common.request_permission", "Request Permission")) {
                        Task { await musicService.requestAuthorization() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if musicService.authorizationStatus == .denied {
                    Button(t("common.open_settings", "Open Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Button {
                isShowingMusicSheet = true
            } label: {
                Label(t("common.debug.search_add_music", "Search and Add Music"), systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)

            Button {
                Task { await musicService.refreshNowPlaying() }
            } label: {
                Label(t("common.debug.refresh_now_playing", "Refresh Now Playing"), systemImage: "arrow.clockwise")
            }
            .disabled(musicService.authorizationStatus != .authorized)

            if let nowPlaying = musicService.nowPlayingData {
                LabeledContent(t("common.title", "Title"), value: nowPlaying.trackName)
                LabeledContent(t("common.author", "Author"), value: nowPlaying.artistName)
                if !nowPlaying.albumName.isEmpty {
                    LabeledContent(t("common.album", "Album"), value: nowPlaying.albumName)
                }

                Button {
                    withAnimation {
                        musicData = nowPlaying
                    }
                } label: {
                    Label(t("common.add", "Add"), systemImage: "plus.circle.fill")
                }
            } else {
                ContentUnavailableView(
                    t("common.debug.no_music_playing", "No music is currently playing"),
                    systemImage: "music.note.slash"
                )
            }

            if !musicData.isEmpty {
                Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                    withAnimation {
                        musicData = MusicCardData()
                    }
                }
            }
        }
    }

    @ViewBuilder
    var audioControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            TextField(t("common.title", "Title"), text: $audioData.title)

            VStack(alignment: .leading, spacing: 8) {
                Text(t("common.description", "Description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $audioData.transcriptPreview)
                    .frame(minHeight: 120)
            }

            TextField(t("common.duration_text", "Duration Text"), text: $audioData.durationText)

            Button(t("common.debug.short_recording", "Short Recording")) {
                audioData.audioData = makeSampleAudioData(duration: 1.2, frequency: 520)
                audioData.durationText = "00:01"
            }

            Button(t("common.debug.long_recording", "Long Recording")) {
                audioData.audioData = makeSampleAudioData(duration: 4.8, frequency: 760)
                audioData.durationText = "00:05"
            }

            Button(t("common.debug.clear_transcript", "Clear Transcript")) {
                audioData.transcriptPreview = ""
            }

            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                audioData = AudioCardData()
            }
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else {
            photoData.imagesData = []
            return
        }

        isLoadingImages = true
        Task {
            var loadedData: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loadedData.append(data)
                }
            }
            await MainActor.run {
                photoData.imagesData = loadedData
                isLoadingImages = false
            }
        }
    }
}
