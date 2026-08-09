import SwiftUI

private enum DestinationInputRoute: Hashable {
    case history
    case savedPlaces
}

struct DestinationInputView: View {
    let currentDestination: Destination?
    let onSelect: (Destination) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var isSearchFocused: Bool

    @State private var searchText = ""
    @State private var candidates: [DestinationSearchService.Candidate] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var debouncedSearch = DebouncedPlaceSearch()

    var body: some View {
        NavigationStack {
            List {
                currentDestinationSection
                browseSection
                searchInputSection
                searchResultsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(AppLocaleString.text("目的地", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        isSearchFocused = false
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .foregroundStyle(.blue)
                    .accessibilityLabel(AppLocaleString.text("完了", locale: locale))
                }
            }
            .navigationDestination(for: DestinationInputRoute.self) { route in
                switch route {
                case .history:
                    DestinationHistoryView(
                        currentDestination: currentDestination,
                        isEmbedded: true,
                        onSelectDestination: finishSelection
                    )
                    .environment(\.locale, locale)
                case .savedPlaces:
                    SavedPlacesView(
                        currentDestination: currentDestination,
                        isEmbedded: true,
                        onSelectDestination: finishSelection
                    )
                    .environment(\.locale, locale)
                }
            }
            .onChange(of: searchText) { _, newValue in
                scheduleSearch(for: newValue)
            }
        }
        .environment(\.locale, locale)
        .lightSheetChrome()
    }

    @ViewBuilder
    private var currentDestinationSection: some View {
        Section {
            if let currentDestination {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentDestination.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let subtitle = currentDestination.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(role: .destructive) {
                    onClear()
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(AppLocaleString.text("目的地をクリア", locale: locale))
            } else {
                Text(AppLocaleString.text("目的地を設定", locale: locale))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(AppLocaleString.text("現在の目的地", locale: locale))
        }
    }

    private var browseSection: some View {
        Section {
            NavigationLink(value: DestinationInputRoute.history) {
                Label(
                    AppLocaleString.text("履歴から探す", locale: locale),
                    systemImage: "clock.arrow.circlepath"
                )
            }

            NavigationLink(value: DestinationInputRoute.savedPlaces) {
                Label(
                    AppLocaleString.text("登録地から探す", locale: locale),
                    systemImage: "mappin.and.ellipse"
                )
            }
        }
    }

    private var searchInputSection: some View {
        Section {
            TextField(
                AppLocaleString.text("駅名・住所・施設名", locale: locale),
                text: $searchText
            )
            .focused($isSearchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .onSubmit {
                scheduleSearch(for: searchText, immediate: true)
            }
        } header: {
            Text(AppLocaleString.text("検索入力", locale: locale))
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        Section {
            if isSearching {
                HStack {
                    ProgressView()
                    Text(AppLocaleString.text("検索中…", locale: locale))
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            } else if candidates.isEmpty {
                Text(
                    searchText.count < 2
                        ? AppLocaleString.text("検索ヒント", locale: locale)
                        : AppLocaleString.text("候補がありません", locale: locale)
                )
                .foregroundStyle(.secondary)
                .font(.subheadline)
            } else {
                ForEach(candidates) { candidate in
                    Button {
                        select(candidate)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            if let subtitle = candidate.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        } header: {
            Text(AppLocaleString.text("検索結果", locale: locale))
        }
    }

    private func finishSelection(_ destination: Destination) {
        onSelect(destination)
        dismiss()
    }

    private func select(_ candidate: DestinationSearchService.Candidate) {
        finishSelection(
            Destination(
                name: candidate.name,
                subtitle: candidate.subtitle,
                latitude: candidate.coordinate.latitude,
                longitude: candidate.coordinate.longitude
            )
        )
    }

    private func scheduleSearch(for query: String, immediate: Bool = false) {
        debouncedSearch.schedule(query: query, immediate: immediate) { query in
            await performSearch(query: query)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        isSearching = query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        errorMessage = nil

        let outcome = await DestinationSearchService.performPlaceSearch(query: query)
        candidates = outcome.candidates
        errorMessage = outcome.errorMessage
        isSearching = false
    }
}

#Preview {
    DestinationInputView(
        currentDestination: Destination(
            name: "東京駅",
            subtitle: "東京都千代田区",
            latitude: 35.681236,
            longitude: 139.767125
        ),
        onSelect: { _ in },
        onClear: {}
    )
    .environment(\.locale, Locale(identifier: "ja"))
}
