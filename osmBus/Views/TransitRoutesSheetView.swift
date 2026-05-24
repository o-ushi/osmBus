import SwiftUI
import UIKit

struct TransitRoutesSheetView: View {
    let destinationName: String
    let destination: Destination?
    let originLatitude: Double?
    let originLongitude: Double?
    let loadState: MainViewModel.TransitRoutesLoadState
    let routes: [ParsedTransitRoute]
    let onReload: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var mapSelection: TransitRouteMapSelection?

    var body: some View {
        NavigationStack {
            Group {
                switch loadState {
                case .idle, .loading:
                    loadingView
                case .failed(let message):
                    failedView(message: message)
                case .loaded:
                    if routes.isEmpty {
                        failedView(message: AppLocaleString.text("osmBus_ルートなし", locale: locale))
                    } else {
                        routesList
                    }
                }
            }
            .navigationTitle(AppLocaleString.text("osmBus_経路一覧", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(AppLocaleString.text("閉じる", locale: locale))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onReload) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(loadState == .loading)
                    .accessibilityLabel(AppLocaleString.text("もう一度試す", locale: locale))
                }
            }
        }
        .presentationDragIndicator(.visible)
        .sheet(item: $mapSelection) { selection in
            if let origin = originCoordinate, let destination {
                TransitRouteMapView(
                    routeIndex: selection.id,
                    route: selection.route,
                    origin: origin,
                    destination: destination
                )
                .environment(\.locale, locale)
            }
        }
    }

    private var originCoordinate: RouteCoordinate? {
        guard let originLatitude, let originLongitude else { return nil }
        return RouteCoordinate(latitude: originLatitude, longitude: originLongitude)
    }

    private var canShowRouteMap: Bool {
        originCoordinate != nil && destination != nil
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(AppLocaleString.text("osmBus_経路読込中", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(message: String) -> some View {
        ContentUnavailableView {
            Label(AppLocaleString.text("osmBus_経路一覧", locale: locale), systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(AppLocaleString.text("もう一度試す", locale: locale))
        }
    }

    private var routesList: some View {
        List {
            Section {
                Text(destinationName)
                    .font(.headline)
            } header: {
                Text(AppLocaleString.text("現在の目的地", locale: locale))
            } footer: {
                Text(
                    canShowRouteMap
                        ? AppLocaleString.text("osmBus_経路一覧フッター_地図", locale: locale)
                        : AppLocaleString.text("osmBus_経路一覧フッター", locale: locale)
                )
            }

            Section(AppLocaleString.text("osmBus_経路候補", locale: locale)) {
                ForEach(Array(routes.enumerated()), id: \.offset) { index, route in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(AppLocaleString.formatted("osmBus_経路番号_%d", locale: locale, index + 1))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(GoogleRoutesAPIService.displayDuration(for: route, locale: locale))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Text(GoogleRoutesAPIService.transitLineSummary(for: route))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let fare = GoogleRoutesAPIService.displayFare(for: route) {
                            Label(fare, systemImage: "yensign.circle")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(AppLocaleString.text("osmBus_運賃不明", locale: locale))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.45) {
                        openRouteMap(at: index, route: route)
                    }
                    .accessibilityHint(
                        canShowRouteMap && GoogleRoutesAPIService.routeHasMapGeometry(route)
                            ? AppLocaleString.text("osmBus_長押しで地図", locale: locale)
                            : ""
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func openRouteMap(at index: Int, route: ParsedTransitRoute) {
        guard canShowRouteMap, GoogleRoutesAPIService.routeHasMapGeometry(route) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        mapSelection = TransitRouteMapSelection(id: index, route: route)
    }
}
