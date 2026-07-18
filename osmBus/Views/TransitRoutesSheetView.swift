import SwiftUI
import UIKit

struct TransitRoutesSheetView: View {
    let destinationName: String
    let destination: Destination?
    let originLatitude: Double?
    let originLongitude: Double?
    let loadState: MainViewModel.TransitRoutesLoadState
    let routes: [ParsedTransitRoute]
    var ridingBusNumber: String? = nil
    let onReload: () -> Void
    var onSelectRidingBus: ((Int, String) -> Void)? = nil

    @Environment(\.locale) private var locale
    @State private var mapSelection: TransitRouteMapSelection?

    var body: some View {
        NavigationStack {
            Group {
                // 蓄積データベースに何か候補があれば、直近の更新が読込中・失敗中でも
                // それを優先して表示する(位置情報の変化のたびに一時的に見えなくなるのを防ぐ)。
                if !routes.isEmpty {
                    routesList
                } else {
                    switch loadState {
                    case .idle, .loading:
                        loadingView
                    case .failed(let message):
                        failedView(message: message)
                    case .loaded:
                        failedView(message: AppLocaleString.text("ルートなし", locale: locale))
                    }
                }
            }
            .navigationTitle(AppLocaleString.text("経路一覧", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                    destination: destination,
                    ridingBusNumber: ridingBusNumber,
                    allRoutes: routes,
                    routeOptionCount: routes.count,
                    onSelectRidingBus: { routeIndex, busNumber in
                        onSelectRidingBus?(routeIndex, busNumber)
                    }
                )
                // 乗車中バスの切り替え時、地図のキャッシュ済みポリライン・ピンを
                // 作り直させるため、乗車バス番号が変わったら別ビューとして再生成する。
                .id("\(selection.id)-\(ridingBusNumber ?? "")")
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
            Text(AppLocaleString.text("経路読込中", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(message: String) -> some View {
        ContentUnavailableView {
            Label(AppLocaleString.text("経路一覧", locale: locale), systemImage: "exclamationmark.triangle")
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
                        ? AppLocaleString.text("経路一覧フッター_地図", locale: locale)
                        : AppLocaleString.text("経路一覧フッター", locale: locale)
                )
            }

            Section(AppLocaleString.text("経路候補", locale: locale)) {
                ForEach(Array(routes.enumerated()), id: \.offset) { index, route in
                    RouteCandidateRow(
                        index: index,
                        route: route,
                        locale: locale,
                        ridingBusNumber: ridingBusNumber,
                        onLongPressBusNumber: { busNumber in
                            onSelectRidingBus?(index, busNumber)
                        }
                    )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openRouteMap(at: index, route: route)
                        }
                        .accessibilityHint(
                            canShowRouteMap && GoogleRoutesAPIService.routeHasMapGeometry(route)
                                ? AppLocaleString.text("タップで地図", locale: locale)
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

private struct RouteCandidateRow: View {
    let index: Int
    let route: ParsedTransitRoute
    let locale: Locale
    var ridingBusNumber: String? = nil
    var onLongPressBusNumber: ((String) -> Void)? = nil

    private var busLines: [String] {
        GoogleRoutesAPIService.transitBusLineBadgeLabels(for: route)
    }

    private var fullBusLines: [String] {
        GoogleRoutesAPIService.transitBusLineLabels(for: route)
    }

    private var otherTransitLines: [String] {
        GoogleRoutesAPIService.transitOtherTransitLineLabels(for: route)
    }

    private var directionBadge: String? {
        GoogleRoutesAPIService.routeDirectionBadge(for: route, locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                primaryLineDisplay
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(GoogleRoutesAPIService.displayDuration(for: route, locale: locale))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            metadataRow

            if !otherTransitLines.isEmpty {
                otherTransitRow
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var primaryLineDisplay: some View {
        if busLines.isEmpty {
            Text(GoogleRoutesAPIService.transitLineSummary(for: route))
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            busLineBadges
        }
    }

    private var busLineBadges: some View {
        let lines = busLines
        let fontSize: CGFloat = lines.count >= 3 ? 20 : (lines.count == 2 ? 24 : 28)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { badgeIndex, line in
                    if badgeIndex > 0 {
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }

                    busLineBadge(text: line, fontSize: fontSize)
                        .accessibilityLabel(fullBusLineAccessibilityLabel(at: badgeIndex, compact: line))
                        .onLongPressGesture {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onLongPressBusNumber?(line)
                        }
                }
            }
        }
    }

    private func busLineBadge(text: String, fontSize: CGFloat) -> some View {
        let isRiding = ridingBusNumber.map { text.uppercased() == $0.uppercased() } ?? false
        return Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isRiding ? Color.orange : AppTheme.brandBlue,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
    }

    private func fullBusLineAccessibilityLabel(at index: Int, compact: String) -> String {
        guard index < fullBusLines.count else { return compact }
        let full = fullBusLines[index]
        return full == compact ? full : "\(compact), \(full)"
    }

    private var metadataRow: some View {
        HStack(spacing: 6) {
            Text(AppLocaleString.formatted("経路番号_%d", locale: locale, index + 1))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("·")
                .font(.caption)
                .foregroundStyle(.quaternary)

            if let fare = GoogleRoutesAPIService.displayFare(for: route) {
                Label(fare, systemImage: "yensign.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            } else {
                Text(AppLocaleString.text("運賃不明", locale: locale))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let badge = directionBadge {
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.quaternary)

                Label(badge, systemImage: "location.north.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private var otherTransitRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.branch")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(otherTransitLines.joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
