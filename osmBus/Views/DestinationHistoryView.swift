import SwiftUI

struct DestinationHistoryView: View {
    let currentDestination: Destination?
    var isEmbedded = false
    var showsSavedRouteTrips = false
    let onSelectDestination: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(PlanStore.self) private var planStore
    @State private var entries: [DestinationHistoryEntry] = []
    @State private var savedTrips: [SavedRouteTrip] = []
    @State private var showsClearConfirmation = false

    var body: some View {
        Group {
            if isEmbedded {
                historyList
            } else {
                NavigationStack {
                    historyList
                }
            }
        }
        .environment(\.locale, locale)
        .lightSheetChrome()
    }

    private var historyList: some View {
        List {
            if entries.isEmpty, savedTrips.isEmpty {
                Section {
                    ContentUnavailableView(
                        AppLocaleString.text("履歴がありません", locale: locale),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(AppLocaleString.text("目的地を設定すると、ここに履歴として表示されます。", locale: locale))
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                if !entries.isEmpty {
                    destinationHistorySection
                }

                if showsSavedRoutesSection, !savedTrips.isEmpty {
                    savedRoutesSection
                }

                if !entries.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            showsClearConfirmation = true
                        } label: {
                            Label(
                                AppLocaleString.text("履歴を消去", locale: locale),
                                systemImage: "trash"
                            )
                        }
                    } footer: {
                        Text(AppLocaleString.text("履歴消去フッター", locale: locale))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle(AppLocaleString.text("履歴", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .hiddenBackButtonWithSwipe()
        .confirmationDialog(
            AppLocaleString.text("履歴をすべて消去しますか？", locale: locale),
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocaleString.text("履歴を消去", locale: locale), role: .destructive) {
                DestinationHistoryStore.clearAll()
                reloadEntries()
            }
            Button(AppLocaleString.text("キャンセル", locale: locale), role: .cancel) {}
        } message: {
            Text(AppLocaleString.text("この操作は取り消せません。", locale: locale))
        }
        .onAppear {
            reloadEntries()
        }
    }

    private var showsSavedRoutesSection: Bool { showsSavedRouteTrips }

    private var destinationHistorySection: some View {
        Section {
            ForEach(entries) { entry in
                Button {
                    selectDestination(entry.destination)
                } label: {
                    DestinationHistoryRow(
                        entry: entry,
                        isCurrentDestination: isCurrentDestination(entry.destination)
                    )
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(AppLocaleString.text("目的地の履歴", locale: locale))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocaleString.text("タップすると、その目的地を設定します。", locale: locale))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                if planStore.isFree {
                    Text(AppLocaleString.formatted("履歴_FREE上限", locale: locale, PlanStore.freeItemLimit))
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
            }
        }
    }

    private var savedRoutesSection: some View {
        Section {
            ForEach(savedTrips) { trip in
                NavigationLink {
                    SavedRoutesBrowseView(
                        trip: trip,
                        onUseDestination: {
                            selectDestination(trip.destination)
                        }
                    )
                } label: {
                    SavedRouteTripRow(
                        trip: trip,
                        isCurrentDestination: isCurrentDestination(trip.destination)
                    )
                }
            }
        } header: {
            Text(AppLocaleString.text("検索したルート", locale: locale))
        } footer: {
            Text(AppLocaleString.text("検索したルート_フッター", locale: locale))
                .foregroundStyle(Color(UIColor.secondaryLabel))
        }
    }

    private func reloadEntries() {
        entries = DestinationHistoryStore.loadAll()
        savedTrips = TransitRouteArchive.listedTrips()
    }

    private func selectDestination(_ destination: Destination) {
        onSelectDestination(destination)
        if !isEmbedded {
            dismiss()
        }
    }

    private func isCurrentDestination(_ destination: Destination) -> Bool {
        guard let currentDestination else { return false }
        return DestinationHistoryStore.matches(currentDestination, destination)
    }
}

private struct DestinationHistoryRow: View {
    let entry: DestinationHistoryEntry
    let isCurrentDestination: Bool

    @Environment(\.locale) private var locale

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.destination.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let subtitle = entry.destination.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(Self.relativeFormatter.localizedString(for: entry.setAt, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
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
        .padding(.vertical, 2)
    }
}

private struct SavedRouteTripRow: View {
    let trip: SavedRouteTrip
    let isCurrentDestination: Bool

    @Environment(\.locale) private var locale

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvefill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.destination.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(
                    AppLocaleString.formatted("経路件数_%d", locale: locale, trip.routeCount)
                    + " · "
                    + trip.linePreview(separator: locale.identifier.hasPrefix("ja") ? "、" : ", ")
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

                Text(Self.relativeFormatter.localizedString(for: trip.updatedAt, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }

            Spacer(minLength: 8)

            if isCurrentDestination {
                Text(AppLocaleString.text("設定中", locale: locale))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SavedRoutesBrowseView: View {
    let trip: SavedRouteTrip
    let onUseDestination: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        List {
            Section {
                Button(action: onUseDestination) {
                    Label(
                        AppLocaleString.text("この目的地を設定", locale: locale),
                        systemImage: "mappin.circle.fill"
                    )
                }
            }

            Section(AppLocaleString.text("経路候補", locale: locale)) {
                ForEach(Array(trip.routes.enumerated()), id: \.offset) { index, route in
                    let origin = Self.originCoordinate(for: route)
                    if let origin {
                        NavigationLink {
                            TransitRouteMapView(
                                routeIndex: index,
                                route: route,
                                origin: origin,
                                destination: trip.destination,
                                allRoutes: trip.routes,
                                routeOptionCount: trip.routes.count
                            )
                            .environment(\.locale, locale)
                            .environment(SharedMapsTrialStore.shared)
                        } label: {
                            savedRouteRow(route)
                        }
                    } else {
                        savedRouteRow(route)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(trip.destination.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func savedRouteRow(_ route: ParsedTransitRoute) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(GoogleRoutesAPIService.transitLineSummary(for: route))
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(GoogleRoutesAPIService.displayDuration(for: route, locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private static func originCoordinate(for route: ParsedTransitRoute) -> RouteCoordinate? {
        if let location = route.steps.first(where: { $0.departureStopLocation != nil })?.departureStopLocation {
            return location
        }
        return route.steps.first(where: { !$0.polylineCoordinates.isEmpty })?.polylineCoordinates.first
    }
}

#Preview {
    DestinationHistoryView(currentDestination: nil, onSelectDestination: { _ in })
        .environment(PlanStore.shared)
        .environment(\.locale, Locale(identifier: "ja"))
}
