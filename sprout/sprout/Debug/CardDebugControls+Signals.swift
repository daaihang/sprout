import SwiftUI
import CoreLocation

extension CardDebugView {
    @ViewBuilder
    var weatherControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            Button {
                fetchCurrentWeather()
            } label: {
                Label(
                    isFetchingWeather
                        ? t("common.debug.fetching", "Fetching...")
                        : t("common.debug.fetch_current_weather", "Fetch Current Weather"),
                    systemImage: "cloud.sun.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(isFetchingWeather)

            TextField(t("common.city_name", "City Name"), text: $weatherData.location)

            LabeledContent(t("common.temperature", "Temperature")) {
                Stepper("\(Int(weatherData.temperature))°C", value: $weatherData.temperature, in: -40...50)
            }

            LabeledContent(t("common.feels_like", "Feels Like")) {
                Stepper("\(Int(weatherData.feelsLike))°C", value: $weatherData.feelsLike, in: -40...50)
            }

            LabeledContent(t("common.humidity_percent", "Humidity %d%%", weatherData.humidity)) {
                Slider(
                    value: Binding(
                        get: { Double(weatherData.humidity) },
                        set: { weatherData.humidity = Int($0) }
                    ),
                    in: 0...100,
                    step: 5
                )
                .frame(maxWidth: 160)
            }

            Picker(t("common.weather_condition", "Weather Condition"), selection: $weatherData.condition) {
                ForEach(WeatherCondition.allCases, id: \.self) { condition in
                    Label(condition.label, systemImage: condition.sfSymbol).tag(condition)
                }
            }

            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                weatherData = WeatherCardData()
            }
        }
    }

    @ViewBuilder
    var activityControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            Picker(t("common.debug.activity_type", "Activity Type"), selection: $activityData.type) {
                ForEach(ActivityType.allCases, id: \.self) { type in
                    Label(type.label, systemImage: type.sfSymbol).tag(type)
                }
            }

            LabeledContent(t("common.value", "Value")) {
                Stepper(
                    "\(activityData.formattedValue) \(activityData.type.defaultUnit)",
                    value: $activityData.value,
                    in: 0...50_000,
                    step: activityData.type == .steps ? 500 : 0.5
                )
            }

            LabeledContent(t("common.goal", "Goal")) {
                Stepper(
                    activityData.goal > 0
                        ? (activityData.goal.truncatingRemainder(dividingBy: 1) == 0
                            ? String(format: "%.0f", activityData.goal)
                            : String(format: "%.1f", activityData.goal))
                        : t("common.debug.no_goal", "No Goal"),
                    value: $activityData.goal,
                    in: 0...50_000,
                    step: activityData.type == .steps ? 1_000 : 1
                )
            }

            LabeledContent(t("common.duration", "Duration")) {
                Stepper(
                    activityData.durationMinutes > 0
                        ? "\(activityData.durationMinutes) min"
                        : t("common.debug.not_recorded", "Not Recorded"),
                    value: $activityData.durationMinutes,
                    in: 0...300,
                    step: 5
                )
            }

            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                activityData = ActivityCardData()
            }
        }

        Section {
            Button("步数 8500") {
                activityData = ActivityCardData(type: .steps, value: 8500, goal: 10_000)
            }
            Button("跑步 5km") {
                activityData = ActivityCardData(type: .running, value: 5.2, goal: 5, durationMinutes: 32)
            }
            Button("睡眠 7.5h") {
                activityData = ActivityCardData(type: .sleep, value: 7.5, goal: 8, durationMinutes: 450)
            }
        }
    }

    @ViewBuilder
    var emotionControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            Picker(
                t("common.debug.select_mood", "Select Mood"),
                selection: Binding(
                    get: { emotionData?.mood ?? .happy },
                    set: {
                        if emotionData == nil { emotionData = EmotionCardData() }
                        emotionData?.mood = $0
                    }
                )
            ) {
                ForEach(MoodType.allCases, id: \.self) { mood in
                    Text("\(mood.emoji) \(mood.label)").tag(mood)
                }
            }

            if emotionData != nil {
                LabeledContent(t("common.debug.intensity", "Intensity %d/5", emotionData?.intensity ?? 3)) {
                    Stepper(
                        "",
                        value: Binding(
                            get: { emotionData?.intensity ?? 3 },
                            set: { emotionData?.intensity = $0 }
                        ),
                        in: 1...5
                    )
                    .labelsHidden()
                }

                TextField(
                    t("common.note_optional", "Note (Optional)"),
                    text: Binding(
                        get: { emotionData?.note ?? "" },
                        set: { emotionData?.note = $0 }
                    ),
                    axis: .vertical
                )

                Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                    emotionData = nil
                }
            }
        }
    }

    @ViewBuilder
    var peopleControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            TextField(t("common.name", "Name"), text: $newPersonName)
            TextField(t("common.nickname", "Nickname"), text: $newPersonNickname)
            TextField(t("common.relationship", "Relationship"), text: $newPersonRelationship)

            Button {
                let item = PersonCardItem(
                    name: newPersonName,
                    nickname: newPersonNickname,
                    relationship: newPersonRelationship,
                    mentionCount: Int.random(in: 1...12)
                )
                peopleData.people.append(item)
                newPersonName = ""
                newPersonNickname = ""
                newPersonRelationship = ""
            } label: {
                Label(t("common.debug.add_person", "Add Person"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        Section {
            Button(t("common.debug.single_person_preset", "Single Person Preset")) {
                peopleData = PeopleCardData(
                    people: [PersonCardItem(name: "Mia", relationship: "Sister", mentionCount: 7)]
                )
            }
            Button(t("common.debug.multi_person_preset", "Multi Person Preset")) {
                peopleData = PeopleCardData(
                    people: [
                        PersonCardItem(name: "Mia", relationship: "Sister", mentionCount: 7),
                        PersonCardItem(name: "David", relationship: "Colleague", mentionCount: 4),
                        PersonCardItem(name: "Nora", relationship: "Friend", mentionCount: 9),
                        PersonCardItem(name: "Leo", relationship: "Partner", mentionCount: 12),
                    ]
                )
            }
        }

        Section(t("common.people", "People")) {
            if peopleData.people.isEmpty {
                ContentUnavailableView(
                    t("common.debug.add_person", "Add Person"),
                    systemImage: "person.badge.plus"
                )
            } else {
                ForEach(peopleData.people) { person in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.displayName)
                            if !person.relationship.isEmpty {
                                Text(person.relationship)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(person.mentionCount)")
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            peopleData.people.removeAll { $0.id == person.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                    peopleData = PeopleCardData()
                }
            }
        }
    }

    private func fetchCurrentWeather() {
        isFetchingWeather = true
        Task {
            defer { isFetchingWeather = false }
            if let location = weatherService.getCurrentLocation() {
                do {
                    weatherData = try await weatherService.fetchWeather(for: location)
                } catch {
                    print("Weather fetch error: \(error)")
                }
            } else if weatherService.authorizationStatus == .notDetermined {
                weatherService.requestLocationPermission()
            } else {
                weatherData.coordinate = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
            }
        }
    }
}
