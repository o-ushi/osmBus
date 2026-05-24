import CoreLocation
import SwiftUI
import UIKit

struct SavedPlacesView: View {
    let currentDestination: Destination?
    var isEmbedded = false
    let onSelectDestination: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PlanStore.self) private var planStore
    @State private var savedPlaces: [SavedPlace] = []
    @State private var showingEditor = false
    @State private var editingPlace: SavedPlace?
    @State private var registrationFeedback: RegistrationFeedback?

    private enum RegistrationFeedback: Equatable {
        case saved(String)
        case duplicate(String)
        case limitReached(String)

        var message: String {
            switch self {
            case .saved(let message), .duplicate(let message), .limitReached(let message):
                return message
            }
        }

        var usesWarningStyle: Bool {
            switch self {
            case .duplicate, .limitReached:
                return true
            case .saved:
                return false
            }
        }
    }

    var body: some View {
        Group {
            if isEmbedded {
                savedPlacesList
            } else {
                NavigationStack {
                    savedPlacesList
                }
            }
        }
        .preferredColorScheme(.light)
        .tint(.blue)
    }

    private var savedPlacesList: some View {
        List {
                if savedPlaces.isEmpty {
                    Section {
                        ContentUnavailableView(
                            AppLocaleString.text("osmBus_登録済みの場所なし", locale: locale),
                            systemImage: "mappin.and.ellipse",
                            description: Text(AppLocaleString.text("osmBus_登録済みの場所なし説明", locale: locale))
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(savedPlaces) { place in
                            SavedPlaceRow(
                                place: place,
                                isCurrentDestination: isCurrentDestination(place),
                                onSelect: {
                                    selectDestination(from: place)
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    beginEditing(place)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .accessibilityLabel(AppLocaleString.text("編集", locale: locale))
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deletePlaces)
                    } header: {
                        Text(AppLocaleString.text("登録済みの場所", locale: locale))
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppLocaleString.text("osmBus_登録済みフッター", locale: locale))
                                .foregroundStyle(SavedPlaceFormStyle.footerText)
                            if planStore.isFree {
                                Text(AppLocaleString.text("osmBus_登録地_FREE上限", locale: locale))
                                    .foregroundStyle(SavedPlaceFormStyle.footerText)
                            }
                        }
                    }
                }

                if let currentDestination {
                    Section {
                        CurrentDestinationRegisterRow(destination: currentDestination) {
                            registerCurrentDestinationDirectly(currentDestination)
                        }
                    } header: {
                        Text(AppLocaleString.text("現在の目的地", locale: locale))
                    } footer: {
                        Text(AppLocaleString.text("osmBus_長押し登録フッター", locale: locale))
                            .foregroundStyle(SavedPlaceFormStyle.footerText)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .navigationTitle(
                AppLocaleString.text(isEmbedded ? "登録済みの場所" : "場所を登録", locale: locale)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isEmbedded {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                        }
                        .foregroundStyle(.blue)
                        .accessibilityLabel(AppLocaleString.text("閉じる", locale: locale))
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        beginAddingPlace()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundStyle(planStore.canAddSavedPlace ? .blue : Color(UIColor.tertiaryLabel))
                    .disabled(!planStore.canAddSavedPlace)
                    .accessibilityLabel(AppLocaleString.text("osmBus_場所を追加", locale: locale))
                }
                if !savedPlaces.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                SavedPlaceEditorView(
                    place: editingPlace,
                    prefillDestination: nil
                ) { saved in
                    if let editingPlace,
                       savedPlaces.contains(where: { $0.id == editingPlace.id }) {
                        SavedPlaceStore.update(saved)
                    } else if SavedPlaceStore.add(saved) {
                        showRegistrationFeedback(.saved(AppLocaleString.formatted("osmBus_登録完了_%@", locale: locale, saved.label)))
                    } else {
                        showRegistrationFeedback(.limitReached(AppLocaleString.text("osmBus_登録件数上限", locale: locale)))
                    }
                    reloadPlaces()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(\.locale, locale)
            }
            .onAppear {
                reloadPlaces()
            }
            .onDisappear {
                resetEditorState()
            }
            .overlay(alignment: .bottom) {
                if let registrationFeedback {
                    Text(registrationFeedback.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            (registrationFeedback.usesWarningStyle ? Color.orange : Color.green).gradient,
                            in: Capsule()
                        )
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: registrationFeedback)
    }

    private func reloadPlaces() {
        savedPlaces = SavedPlaceStore.loadAll()
    }

    private func deletePlaces(at offsets: IndexSet) {
        for index in offsets {
            SavedPlaceStore.delete(id: savedPlaces[index].id)
        }
        reloadPlaces()
    }

    private func selectDestination(from place: SavedPlace) {
        onSelectDestination(place.makeDestination())
        if !isEmbedded {
            dismiss()
        }
    }

    private func beginAddingPlace() {
        guard planStore.canAddSavedPlace else {
            showRegistrationFeedback(.limitReached(AppLocaleString.text("osmBus_登録件数上限", locale: locale)))
            return
        }
        resetEditorState()
        showingEditor = true
    }

    private func beginEditing(_ place: SavedPlace) {
        editingPlace = place
        showingEditor = true
    }

    private func registerCurrentDestinationDirectly(_ destination: Destination) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if savedPlace(matching: destination) != nil {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showRegistrationFeedback(.duplicate(AppLocaleString.text("osmBus_重複登録", locale: locale)))
            return
        }

        let place = SavedPlace.from(destination: destination, label: destination.name)
        guard SavedPlaceStore.add(place) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showRegistrationFeedback(.limitReached(AppLocaleString.text("osmBus_登録件数上限", locale: locale)))
            return
        }
        reloadPlaces()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showRegistrationFeedback(.saved(AppLocaleString.formatted("osmBus_登録完了_%@", locale: locale, destination.name)))
    }

    private func showRegistrationFeedback(_ feedback: RegistrationFeedback) {
        registrationFeedback = feedback
        let message = feedback.message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if registrationFeedback?.message == message {
                registrationFeedback = nil
            }
        }
    }

    private func resetEditorState() {
        editingPlace = nil
    }

    private func savedPlace(matching destination: Destination) -> SavedPlace? {
        savedPlaces.first { SavedPlace.matches($0, destination: destination) }
    }

    private func isCurrentDestination(_ place: SavedPlace) -> Bool {
        guard let currentDestination else { return false }
        return SavedPlace.matches(place, destination: currentDestination)
            && place.label == currentDestination.name
    }
}

private enum SavedPlaceFormStyle {
    static let footerText = Color(UIColor.secondaryLabel)
    static let hintText = Color(UIColor.systemBlue)
    static let chipSelectedBackground = Color.blue
    static let chipSelectedForeground = Color.white
    static let chipBackground = Color(UIColor.systemGray5)
    static let chipForeground = Color(UIColor.label)
}

private struct CurrentDestinationRegisterRow: View {
    let destination: Destination
    let onRegister: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(destination.name)
                .font(.headline)
                .foregroundStyle(Color.primary)

            if let subtitle = destination.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }

            Label(AppLocaleString.text("osmBus_長押しで登録", locale: locale), systemImage: "hand.tap.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SavedPlaceFormStyle.hintText)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.45, perform: onRegister)
    }
}

private struct SavedPlaceRow: View {
    let place: SavedPlace
    let isCurrentDestination: Bool
    let onSelect: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: place.label))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(place.label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(place.detailLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if isCurrentDestination {
                    Text(AppLocaleString.text("設定中", locale: locale))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
        }
        .buttonStyle(.plain)
    }

    private func iconName(for label: String) -> String {
        switch label {
        case AppLocaleString.text("自宅", locale: locale):
            return "house.fill"
        case AppLocaleString.text("会社", locale: locale):
            return "building.2.fill"
        case AppLocaleString.text("学校", locale: locale):
            return "graduationcap.fill"
        default:
            return "mappin.circle.fill"
        }
    }
}

private struct SavedPlaceEditorView: View {
    let place: SavedPlace?
    let prefillDestination: Destination?
    let onSave: (SavedPlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var focusedField: FocusField?

    @State private var label = ""
    @State private var searchText = ""
    @State private var candidates: [DestinationSearchService.Candidate] = []
    @State private var selectedCandidate: DestinationSearchService.Candidate?
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private enum FocusField: Hashable {
        case label
        case search
    }

    private let quickLabelKeys = ["自宅", "会社", "学校"]

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedLabel.isEmpty && selectedCandidate != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AppLocaleString.text("osmBus_表示名プレースホルダー", locale: locale), text: $label)
                        .focused($focusedField, equals: .label)
                        .foregroundStyle(.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickLabelKeys, id: \.self) { quickLabel in
                                Button(AppLocaleString.text(quickLabel, locale: locale)) {
                                    label = quickLabel
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(
                                    trimmedLabel == quickLabel
                                        ? SavedPlaceFormStyle.chipSelectedForeground
                                        : SavedPlaceFormStyle.chipForeground
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    trimmedLabel == quickLabel
                                        ? SavedPlaceFormStyle.chipSelectedBackground
                                        : SavedPlaceFormStyle.chipBackground,
                                    in: Capsule()
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text(AppLocaleString.text("名前", locale: locale))
                } footer: {
                    Text(AppLocaleString.text("osmBus_名前フッター", locale: locale))
                        .foregroundStyle(SavedPlaceFormStyle.footerText)
                }

                Section {
                    if let selectedCandidate {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedCandidate.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            if let subtitle = selectedCandidate.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Button(role: .destructive) {
                                self.selectedCandidate = nil
                                searchText = ""
                                candidates = []
                                focusedField = .search
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            .accessibilityLabel(AppLocaleString.text("osmBus_場所を選び直す", locale: locale))
                        }
                    } else {
                        TextField(AppLocaleString.text("駅名・住所・施設名", locale: locale), text: $searchText)
                            .focused($focusedField, equals: .search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.primary)
                            .submitLabel(.search)
                            .onSubmit {
                                scheduleSearch(for: searchText, immediate: true)
                            }

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
                                    ? AppLocaleString.text("osmBus_検索ヒント", locale: locale)
                                    : AppLocaleString.text("候補がありません", locale: locale)
                            )
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(candidates) { candidate in
                                Button {
                                    selectedCandidate = candidate
                                    searchText = candidate.name
                                    candidates = []
                                    focusedField = nil
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(candidate.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        if let subtitle = candidate.subtitle, !subtitle.isEmpty {
                                            Text(subtitle)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text(AppLocaleString.text("場所", locale: locale))
                } footer: {
                    Text(AppLocaleString.text("osmBus_場所フッター", locale: locale))
                        .foregroundStyle(SavedPlaceFormStyle.footerText)
                }
            }
            .scrollContentBackground(.visible)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(
                AppLocaleString.text(
                    place == nil ? "osmBus_場所を追加" : "osmBus_場所を編集",
                    locale: locale
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(.blue)
                    .accessibilityLabel(AppLocaleString.text("キャンセル", locale: locale))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        savePlace()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? .blue : Color(UIColor.tertiaryLabel))
                    .disabled(!canSave)
                    .accessibilityLabel(AppLocaleString.text("保存", locale: locale))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .foregroundStyle(.blue)
                    .accessibilityLabel(AppLocaleString.text("完了", locale: locale))
                }
            }
            .onAppear {
                loadInitialState()
            }
            .onChange(of: searchText) { _, newValue in
                guard selectedCandidate == nil else { return }
                scheduleSearch(for: newValue)
            }
        }
        .environment(\.locale, locale)
        .preferredColorScheme(.light)
        .tint(.blue)
    }

    private func loadInitialState() {
        if let place {
            label = place.label
            selectedCandidate = DestinationSearchService.Candidate(
                name: place.placeName,
                subtitle: place.subtitle,
                coordinate: .init(latitude: place.latitude, longitude: place.longitude)
            )
            searchText = place.placeName
            return
        }

        if let prefillDestination {
            selectedCandidate = DestinationSearchService.Candidate(
                name: prefillDestination.name,
                subtitle: prefillDestination.subtitle,
                coordinate: .init(
                    latitude: prefillDestination.latitude,
                    longitude: prefillDestination.longitude
                )
            )
            searchText = prefillDestination.name
            focusedField = .label
        }
    }

    private func savePlace() {
        guard let selectedCandidate, !trimmedLabel.isEmpty else { return }

        let saved = SavedPlace(
            id: place?.id ?? UUID(),
            label: trimmedLabel,
            placeName: selectedCandidate.name,
            subtitle: selectedCandidate.subtitle,
            latitude: selectedCandidate.coordinate.latitude,
            longitude: selectedCandidate.coordinate.longitude
        )
        onSave(saved)
        dismiss()
    }

    private func scheduleSearch(for query: String, immediate: Bool = false) {
        searchTask?.cancel()
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            candidates = []
            errorMessage = nil
            isSearching = false
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            candidates = try await DestinationSearchService.searchPlaces(query: trimmed)
        } catch {
            candidates = []
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }
}

#Preview {
    SavedPlacesView(currentDestination: nil, onSelectDestination: { _ in })
}
