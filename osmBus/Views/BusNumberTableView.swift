import SwiftUI
import UIKit

/// トップ画面のバス番号表（方向 × 乗換）。タップ＝ルート図、長押し＝乗車/降車トグル（Step 5）。
struct BusNumberTableView: View {
    let routes: [ParsedTransitRoute]
    let loadState: MainViewModel.TransitRoutesLoadState
    let ridingBusNumber: String?
    var originLatitude: Double? = nil
    var originLongitude: Double? = nil
    let onReload: () -> Void
    let onTapBusNumber: (String) -> Void
    let onLongPressBusNumber: (String) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.busCardStyle) private var cardStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
        }
        .padding(AppTheme.cardPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BusCardBackground(style: cardStyle))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }

    private var header: some View {
        HStack {
            Text(AppLocaleString.text("バス番号表", locale: locale))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(loadState == .loading)
            .accessibilityLabel(AppLocaleString.text("もう一度試す", locale: locale))
        }
    }

    @ViewBuilder
    private var content: some View {
        // 蓄積データベースに何かあれば、直近の読込状態が失敗中でもそれを優先して表示する
        // (TransitRoutesSheetView と同じ方針)。
        if !routes.isEmpty {
            table
        } else {
            switch loadState {
            case .idle, .loading:
                statusText(AppLocaleString.text("経路読込中", locale: locale))
            case .failed(let message):
                statusText(message)
            case .loaded:
                statusText(AppLocaleString.text("ルートなし", locale: locale))
            }
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var table: some View {
        if directionRows.isEmpty {
            statusText(AppLocaleString.text("ルートなし", locale: locale))
        } else {
            Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    columnHeader("方向")
                    columnHeader("直通")
                    columnHeader("乗換1")
                    columnHeader("乗換2+")
                }
                Divider().gridCellColumns(4)

                ForEach(directionRows) { row in
                    GridRow {
                        Text(row.direction)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .accessibilityLabel(
                                AppLocaleString.formatted("方向バッジ_%@", locale: locale, row.direction)
                            )
                        busNumberCell(row.direct, categoryKey: "直通")
                        busNumberCell(row.oneTransfer, categoryKey: "乗換1")
                        busNumberCell(row.multiTransfer, categoryKey: "乗換2+")
                    }
                    Divider().gridCellColumns(4)
                }
            }
        }
    }

    private func columnHeader(_ key: String) -> some View {
        Text(AppLocaleString.text(key, locale: locale))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
    }

    @ViewBuilder
    private func busNumberCell(_ numbers: [String], categoryKey: String) -> some View {
        if numbers.isEmpty {
            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(numbers, id: \.self) { number in
                    TransitBusLineBadgeLabel(
                        text: number,
                        isRidingBus: ridingBusNumber.map { number.uppercased() == $0.uppercased() } ?? false,
                        font: .subheadline.weight(.bold),
                        horizontalPadding: 10,
                        verticalPadding: 5,
                        cornerRadius: 8
                    )
                    .onTapGesture {
                        onTapBusNumber(number)
                    }
                    .onLongPressGesture {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onLongPressBusNumber(number)
                    }
                    .accessibilityLabel(
                        "\(AppLocaleString.text(categoryKey, locale: locale)) \(number)"
                    )
                    .accessibilityHint(AppLocaleString.text("バス番号表_操作ヒント", locale: locale))
                }
            }
        }
    }

    // MARK: - 行の組み立て

    private struct DirectionRow: Identifiable {
        let direction: String
        let direct: [String]
        let oneTransfer: [String]
        let multiTransfer: [String]

        var id: String { direction }
    }

    /// ルート群を (方向, 乗換カテゴリ) に振り分け、各セルへ乗車すべきバス番号(そのルートの
    /// 最初のバスレグ)を積む。同じ番号が複数ルートにあっても1回だけ出す。
    /// セル内は現在地から乗車バス停が近い順。
    private var directionRows: [DirectionRow] {
        var directionOrder: [String] = []
        var direct: [String: [BusNumberEntry]] = [:]
        var oneTransfer: [String: [BusNumberEntry]] = [:]
        var multiTransfer: [String: [BusNumberEntry]] = [:]

        for route in routes {
            let busNumbers = GoogleRoutesAPIService.transitBusLineBadgeLabels(for: route)
            guard let firstBusNumber = busNumbers.first,
                  let direction = GoogleRoutesAPIService.routeDirectionText(for: route, locale: locale) else {
                continue
            }
            if !directionOrder.contains(direction) {
                directionOrder.append(direction)
            }

            let entry = BusNumberEntry(
                number: firstBusNumber,
                boardingDistanceMeters: boardingDistanceMeters(for: route)
            )
            switch busNumbers.count {
            case 1:
                appendNearest(entry, forKey: direction, in: &direct)
            case 2:
                appendNearest(entry, forKey: direction, in: &oneTransfer)
            default:
                appendNearest(entry, forKey: direction, in: &multiTransfer)
            }
        }

        return directionOrder.map { direction in
            DirectionRow(
                direction: direction,
                direct: sortedNumbers(direct[direction] ?? []),
                oneTransfer: sortedNumbers(oneTransfer[direction] ?? []),
                multiTransfer: sortedNumbers(multiTransfer[direction] ?? [])
            )
        }
    }

    private struct BusNumberEntry {
        let number: String
        let boardingDistanceMeters: Double?
    }

    private func boardingDistanceMeters(for route: ParsedTransitRoute) -> Double? {
        guard let originLatitude, let originLongitude else { return nil }
        guard let step = route.steps.first(where: { GoogleRoutesAPIService.isBusStep($0) }) else { return nil }
        let stop = step.departureStopLocation ?? step.polylineCoordinates.first
        guard let stop else { return nil }
        return GoogleRoutesAPIService.distanceMeters(
            fromLatitude: originLatitude,
            fromLongitude: originLongitude,
            toLatitude: stop.latitude,
            toLongitude: stop.longitude
        )
    }

    private func appendNearest(_ entry: BusNumberEntry, forKey key: String, in dict: inout [String: [BusNumberEntry]]) {
        var list = dict[key] ?? []
        if let index = list.firstIndex(where: { $0.number == entry.number }) {
            let existing = list[index].boardingDistanceMeters ?? .infinity
            let incoming = entry.boardingDistanceMeters ?? .infinity
            if incoming < existing {
                list[index] = entry
            }
        } else {
            list.append(entry)
        }
        dict[key] = list
    }

    private func sortedNumbers(_ entries: [BusNumberEntry]) -> [String] {
        entries
            .sorted { ($0.boardingDistanceMeters ?? .infinity) < ($1.boardingDistanceMeters ?? .infinity) }
            .map(\.number)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        BusNumberTableView(
            routes: [],
            loadState: .idle,
            ridingBusNumber: nil,
            onReload: {},
            onTapBusNumber: { _ in },
            onLongPressBusNumber: { _ in }
        )
        .padding()
    }
}
