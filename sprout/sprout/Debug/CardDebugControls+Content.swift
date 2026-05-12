import SwiftUI

extension CardDebugView {
    @ViewBuilder
    var linkControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            TextField(t("common.url", "URL"), text: $newLinkURL)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField(t("common.title", "Title"), text: $newLinkTitle)
            TextField(t("common.description", "Description"), text: $newLinkDescription, axis: .vertical)

            Button {
                addLink()
            } label: {
                Label(t("common.debug.add_link", "Add Link"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                linkData = LinkCardData()
                newLinkURL = ""
                newLinkTitle = ""
                newLinkDescription = ""
            }
        }

        Section(linkData.links.isEmpty ? t("common.none", "None") : t("common.link", "Link")) {
            if linkData.links.isEmpty {
                ContentUnavailableView(
                    t("common.debug.add_link", "Add Link"),
                    systemImage: "link.badge.plus"
                )
            } else {
                ForEach(linkData.links) { link in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.title.isEmpty ? link.domain : link.title)
                            Text(link.domain)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            withAnimation {
                                linkData.links.removeAll { $0.id == link.id }
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var quoteControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            TextField(t("common.author", "Author"), text: $quoteData.author)
            TextField(t("common.source", "Source"), text: $quoteData.source)

            VStack(alignment: .leading, spacing: 8) {
                Text(t("common.quote.content", "Quote Content"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $quoteData.quote)
                    .frame(minHeight: 120)
            }

            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                quoteData = QuoteCardData()
            }
        }

        Section(t("common.debug.preset_quotes", "Preset Quotes")) {
            ForEach(quotePresets, id: \.0) { quote, author in
                Button {
                    quoteData.quote = quote
                    quoteData.author = author
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quote)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if !author.isEmpty {
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    var todoControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            TextField(t("common.list_title_optional", "List Title (Optional)"), text: $todoData.title)

            HStack {
                TextField(t("common.item", "Item"), text: $newTodoText)
                    .submitLabel(.done)
                    .onSubmit { addTodoItem() }
                Button(t("common.add", "Add")) {
                    addTodoItem()
                }
                .disabled(newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        Section(t("common.debug.controls", "Debug Controls")) {
            if todoData.items.isEmpty {
                ContentUnavailableView(
                    t("common.item", "Item"),
                    systemImage: "checklist"
                )
            } else {
                ForEach($todoData.items) { $item in
                    HStack {
                        Button {
                            item.isDone.toggle()
                        } label: {
                            Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                                .foregroundStyle(item.isDone ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        Text(item.text)
                            .strikethrough(item.isDone)
                            .foregroundStyle(item.isDone ? .secondary : .primary)

                        Spacer()

                        Button(role: .destructive) {
                            todoData.items.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                LabeledContent(
                    t("common.debug.completed_count", "%d/%d completed", todoData.doneCount, todoData.totalCount),
                    value: ""
                )

                Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                    todoData = TodoCardData()
                    newTodoText = ""
                }
            }
        }
    }

    @ViewBuilder
    var bookControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            TextField(t("common.book_title", "Book Title"), text: $bookData.title)
            TextField(t("common.author", "Author"), text: $bookData.author)
            TextField(
                t("common.genre", "Genre"),
                text: Binding(
                    get: { bookData.genre ?? "" },
                    set: { bookData.genre = $0.isEmpty ? nil : $0 }
                )
            )

            Toggle(
                t("common.debug.set_reading_progress", "Set Reading Progress"),
                isOn: Binding(
                    get: { bookData.progress != nil },
                    set: { bookData.progress = $0 ? (bookData.progress ?? 0) : nil }
                )
            )

            if let progress = bookData.progress {
                LabeledContent(t("common.debug.progress", "Progress %d%%", Int(progress * 100))) {
                    Slider(value: Binding(get: { progress }, set: { bookData.progress = $0 }), in: 0...1)
                        .frame(maxWidth: 160)
                }
            }

            Picker(t("common.rating", "Rating"), selection: Binding(
                get: { bookData.rating ?? 0 },
                set: { bookData.rating = $0 == 0 ? nil : $0 }
            )) {
                Text("0").tag(0)
                ForEach(1...5, id: \.self) { star in
                    Text("\(star)").tag(star)
                }
            }
            .pickerStyle(.segmented)

            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                bookData = BookCardData()
            }
        }
    }

    @ViewBuilder
    var filmControlsSections: some View {
        Section(t("common.debug.controls", "Debug Controls")) {
            TextField(t("common.film_title", "Film Title"), text: $filmData.title)
            TextField(t("common.year", "Year"), text: $filmData.year)
                .keyboardType(.numberPad)
            TextField(
                t("common.director", "Director"),
                text: Binding(
                    get: { filmData.director ?? "" },
                    set: { filmData.director = $0.isEmpty ? nil : $0 }
                )
            )
            TextField(
                t("common.genre", "Genre"),
                text: Binding(
                    get: { filmData.genre ?? "" },
                    set: { filmData.genre = $0.isEmpty ? nil : $0 }
                )
            )

            Picker(t("common.rating", "Rating"), selection: Binding(
                get: { Int(filmData.rating ?? 0) },
                set: { filmData.rating = $0 == 0 ? nil : Double($0) }
            )) {
                Text("0").tag(0)
                ForEach(1...5, id: \.self) { star in
                    Text("\(star)").tag(star)
                }
            }
            .pickerStyle(.segmented)

            Toggle(t("common.debug.watched", "Watched"), isOn: $filmData.isWatched)

            Button(t("common.clear_data", "Clear Data"), role: .destructive) {
                filmData = FilmCardData()
            }
        }
    }

    private var quotePresets: [(String, String)] {
        [
            ("不积跬步，无以至千里；不积小流，无以成江海。", "荀子"),
            ("纸上得来终觉浅，绝知此事要躬行。", "陆游"),
            ("宝剑锋从磨砺出，梅花香自苦寒来。", ""),
            ("苟利国家生死以，岂因祸福避趋之。", "林则徐"),
        ]
    }

    private func addLink() {
        let trimmedURL = newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), !trimmedURL.isEmpty else { return }

        let item = LinkItem(url: url, title: newLinkTitle, description: newLinkDescription)
        withAnimation {
            linkData.links.append(item)
        }
        newLinkURL = ""
        newLinkTitle = ""
        newLinkDescription = ""
    }
}
