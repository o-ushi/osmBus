import SwiftUI
import UIKit

/// トップ画面のバス番号表（方向 × 乗換）。タップ＝ルート図、長押し＝乗車/降車トグル（Step 5）。
struct BusNumberTableView: View {
    let routes: [ParsedTransitRoute]
    let loadState: MainViewModel.TransitRoutesLoadState
    let ridingBusNumber: String?
    var originLatitude: Double? = nil
    var originLongitude: Double? = nil
    var destinationLatitude: Double? = nil
    var destinationLongitude: Double? = nil
    let onReload: () -> Void
    let onTapBusNumber: (Int, String) -> Void
    let onLongPressBusNumber: (Int, String) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.busCardStyle) private var cardStyle
    @AppStorage(BusNumberTableSortMode.storageKey) private var sortModeRaw =
        BusNumberTableSortMode.byDirection.rawValue
    @AppStorage(BusNumberTableDistanceMetric.storageKey) private var distanceMetricRaw =
        BusNumberTableDistanceMetric.walkPriority.rawValue

    private var sortMode: BusNumberTableSortMode {
        BusNumberTableSortMode(rawValue: sortModeRaw) ?? .byDirection
    }

    /// 距離基準 (byDistance) のときだけ使う距離の測り方。
    private var distanceMetric: BusNumberTableDistanceMetric {
        BusNumberTableDistanceMetric(rawValue: distanceMetricRaw) ?? .walkPriority
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            // 表タイトル・再読み込みは固定。候補が多く欄が画面下に切れるときは
            // 表の中身だけをスクロールして隠れた番号を見られるようにする。
            ScrollView(.vertical, showsIndicators: true) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
            .accessibilityLabel(AppLocaleString.text("もう一度試す", locale: locale))
        }
    }

    @ViewBuilder
    private var content: some View {
        // 蓄積データベースに何かあれば、直近の読込状態が失敗中でもそれを優先して表示する。
        if !routes.isEmpty {
            table
        } else {
            switch loadState {
            case .idle:
                statusText(AppLocaleString.text("目的地を設定", locale: locale))
            case .loading:
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
        switch sortMode {
        case .byDirection:
            directionGrid
        case .byDistance:
            flatList(order: .directionFirst)
        case .byTransferCount:
            flatList(order: .transferFirst)
        }
    }

    // MARK: - 設定1: 方向基準 (既定・従来仕様)

    @ViewBuilder
    private var directionGrid: some View {
        if directionRows.isEmpty {
            statusText(AppLocaleString.text("ルートなし", locale: locale))
        } else {
            Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    columnHeaderIcon("safari", accessibilityKey: "方向")
                    columnHeader(icon: "arrow.triangle.swap", digits: "0", accessibilityKey: "直通")
                    columnHeader(icon: "arrow.triangle.swap", digits: "1", accessibilityKey: "乗換1")
                    columnHeader(icon: "arrow.triangle.swap", digits: "2+", accessibilityKey: "乗換2+")
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

    private func columnHeaderIcon(_ systemName: String, accessibilityKey: String) -> some View {
        Image(systemName: systemName)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityLabel(AppLocaleString.text(accessibilityKey, locale: locale))
    }

    private func columnHeader(icon systemName: String, digits: String, accessibilityKey: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(digits)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocaleString.text(accessibilityKey, locale: locale))
    }

    @ViewBuilder
    private func busNumberCell(_ entries: [BusNumberEntry], categoryKey: String) -> some View {
        if entries.isEmpty {
            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entries) { entry in
                    TransitBusLineBadgeLabel(
                        text: entry.number,
                        isRidingBus: ridingBusNumber.map { entry.number.uppercased() == $0.uppercased() } ?? false,
                        font: .subheadline.weight(.bold),
                        horizontalPadding: 10,
                        verticalPadding: 5,
                        cornerRadius: 8
                    )
                    .onTapGesture {
                        onTapBusNumber(entry.routeIndex, entry.number)
                    }
                    .onLongPressGesture {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onLongPressBusNumber(entry.routeIndex, entry.number)
                    }
                    .accessibilityLabel(
                        "\(AppLocaleString.text(categoryKey, locale: locale)) \(entry.number)"
                    )
                    .accessibilityHint(AppLocaleString.text("バス番号表_操作ヒント", locale: locale))
                }
            }
        }
    }

    // MARK: - 行の組み立て

    private struct DirectionRow: Identifiable {
        let direction: String
        let direct: [BusNumberEntry]
        let oneTransfer: [BusNumberEntry]
        let multiTransfer: [BusNumberEntry]

        var id: String { direction }
    }

    /// ルート群を (方向, 乗換カテゴリ) に振り分け、各セルへ乗車すべきバス番号(そのルートの
    /// 最初のバスレグ)を積む。同じ番号が複数ルートにあっても1回だけ出す。
    /// セル内は「乗車徒歩 + 乗換徒歩(合計) + 降車徒歩」の合計が短い順。同じなら
    /// バス乗車距離(道なり)が短い順。
    private var directionRows: [DirectionRow] {
        var directionOrder: [String] = []
        var direct: [String: [BusNumberEntry]] = [:]
        var oneTransfer: [String: [BusNumberEntry]] = [:]
        var multiTransfer: [String: [BusNumberEntry]] = [:]

        for (routeIndex, route) in routes.enumerated() {
            let busNumbers = GoogleRoutesAPIService.transitBusLineBadgeLabels(for: route)
            guard let firstBusNumber = busNumbers.first,
                  let direction = GoogleRoutesAPIService.routeDirectionText(for: route, locale: locale) else {
                continue
            }
            if !directionOrder.contains(direction) {
                directionOrder.append(direction)
            }

            let entry = BusNumberEntry(
                routeIndex: routeIndex,
                number: firstBusNumber,
                totalWalkDistanceMeters: totalWalkDistanceMeters(for: route),
                busRideDistanceMeters: busRideDistanceMeters(for: route)
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
                direct: sortedEntries(direct[direction] ?? []),
                oneTransfer: sortedEntries(oneTransfer[direction] ?? []),
                multiTransfer: sortedEntries(multiTransfer[direction] ?? [])
            )
        }
    }

    private struct BusNumberEntry: Identifiable {
        let routeIndex: Int
        let number: String
        let totalWalkDistanceMeters: Double?
        let busRideDistanceMeters: Double?

        var id: String { "\(routeIndex)-\(number)" }
    }

    /// 乗車徒歩(出発地→最初のバスの乗車停) + 乗換徒歩(バスレグ間、合計) +
    /// 降車徒歩(最後のバスの降車停→目的地)。座標が欠けたら nil (そのエントリはセル内で後ろへ)。
    private func totalWalkDistanceMeters(for route: ParsedTransitRoute) -> Double? {
        guard let boarding = boardingWalkDistanceMeters(for: route),
              let transfers = transferWalkDistanceMeters(for: route),
              let alighting = alightingWalkDistanceMeters(for: route) else { return nil }
        return boarding + transfers + alighting
    }

    private func boardingWalkDistanceMeters(for route: ParsedTransitRoute) -> Double? {
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

    private func alightingWalkDistanceMeters(for route: ParsedTransitRoute) -> Double? {
        guard let destinationLatitude, let destinationLongitude else { return nil }
        guard let step = route.steps.last(where: { GoogleRoutesAPIService.isBusStep($0) }) else { return nil }
        let stop = step.arrivalStopLocation ?? step.polylineCoordinates.last
        guard let stop else { return nil }
        return GoogleRoutesAPIService.distanceMeters(
            fromLatitude: stop.latitude,
            fromLongitude: stop.longitude,
            toLatitude: destinationLatitude,
            toLongitude: destinationLongitude
        )
    }

    /// 乗換のたびに歩く距離(直線)の合計。バスレグが1つ(乗換なし)なら 0。
    /// 乗換前後のバス停座標が欠けたら nil。
    private func transferWalkDistanceMeters(for route: ParsedTransitRoute) -> Double? {
        let busSteps = route.steps.filter { GoogleRoutesAPIService.isBusStep($0) }
        guard busSteps.count >= 2 else { return 0 }

        var total = 0.0
        for index in 1..<busSteps.count {
            guard let alightStop = busSteps[index - 1].arrivalStopLocation ?? busSteps[index - 1].polylineCoordinates.last,
                  let boardStop = busSteps[index].departureStopLocation ?? busSteps[index].polylineCoordinates.first else {
                return nil
            }
            total += GoogleRoutesAPIService.distanceMeters(
                fromLatitude: alightStop.latitude,
                fromLongitude: alightStop.longitude,
                toLatitude: boardStop.latitude,
                toLongitude: boardStop.longitude
            )
        }
        return total
    }

    /// バスで移動する距離(道なり)。各バスレグのポリライン長の合計。
    private func busRideDistanceMeters(for route: ParsedTransitRoute) -> Double? {
        let busSteps = route.steps.filter { GoogleRoutesAPIService.isBusStep($0) }
        guard !busSteps.isEmpty else { return nil }
        return busSteps.reduce(0) { $0 + GoogleRoutesAPIService.polylineLength($1.polylineCoordinates) }
    }

    /// 徒歩合計が短い方を優先。同じなら、バス移動距離が短い方を優先。
    private func isBetter(_ a: BusNumberEntry, than b: BusNumberEntry) -> Bool {
        isBetterDistance(
            walkA: a.totalWalkDistanceMeters, rideA: a.busRideDistanceMeters,
            walkB: b.totalWalkDistanceMeters, rideB: b.busRideDistanceMeters
        )
    }

    private func isBetterDistance(walkA: Double?, rideA: Double?, walkB: Double?, rideB: Double?) -> Bool {
        let wa = walkA ?? .infinity
        let wb = walkB ?? .infinity
        if wa != wb { return wa < wb }
        return (rideA ?? .infinity) < (rideB ?? .infinity)
    }

    private func appendNearest(_ entry: BusNumberEntry, forKey key: String, in dict: inout [String: [BusNumberEntry]]) {
        var list = dict[key] ?? []
        if let index = list.firstIndex(where: { $0.number == entry.number }) {
            if isBetter(entry, than: list[index]) {
                list[index] = entry
            }
        } else {
            list.append(entry)
        }
        dict[key] = list
    }

    private func sortedEntries(_ entries: [BusNumberEntry]) -> [BusNumberEntry] {
        entries.sorted { isBetter($0, than: $1) }
    }

    // MARK: - 設定2・3: 距離基準 / 乗換回数基準 (方向でグループ化しないフラット表示)

    private enum TransferCategory: Int {
        case direct = 0
        case oneTransfer = 1
        case multiTransfer = 2

        var categoryKey: String {
            switch self {
            case .direct: return "直通"
            case .oneTransfer: return "乗換1"
            case .multiTransfer: return "乗換2+"
            }
        }

        var digits: String {
            switch self {
            case .direct: return "0"
            case .oneTransfer: return "1"
            case .multiTransfer: return "2+"
            }
        }
    }

    private struct FlatEntry: Identifiable {
        let routeIndex: Int
        let direction: String
        let category: TransferCategory
        /// そのルートの全レグのバス番号(乗換があれば複数)。
        let busNumbers: [String]
        let totalWalkDistanceMeters: Double?
        let busRideDistanceMeters: Double?

        var firstNumber: String { busNumbers.first ?? "" }
        var id: String { "\(routeIndex)-\(firstNumber)" }
    }

    private enum FlatColumnOrder: Equatable {
        case directionFirst
        case transferFirst
    }

    /// 方向×最初のバス番号×乗換カテゴリごとに最も距離が短いルートを1つ残したフラットな一覧。
    /// (直通ボタンの「1番号1つ」ルールは維持しつつ、方向でのグループ化はしない)
    private var flatEntries: [FlatEntry] {
        var dedup: [String: FlatEntry] = [:]
        var order: [String] = []

        for (routeIndex, route) in routes.enumerated() {
            let busNumbers = GoogleRoutesAPIService.transitBusLineBadgeLabels(for: route)
            guard let firstBusNumber = busNumbers.first,
                  let direction = GoogleRoutesAPIService.routeDirectionText(for: route, locale: locale) else {
                continue
            }

            let category: TransferCategory
            switch busNumbers.count {
            case 1: category = .direct
            case 2: category = .oneTransfer
            default: category = .multiTransfer
            }

            let candidate = FlatEntry(
                routeIndex: routeIndex,
                direction: direction,
                category: category,
                busNumbers: busNumbers,
                totalWalkDistanceMeters: totalWalkDistanceMeters(for: route),
                busRideDistanceMeters: busRideDistanceMeters(for: route)
            )

            let key = "\(direction)|\(category.rawValue)|\(firstBusNumber)"
            if let existing = dedup[key] {
                if isBetterDistance(
                    walkA: candidate.totalWalkDistanceMeters, rideA: candidate.busRideDistanceMeters,
                    walkB: existing.totalWalkDistanceMeters, rideB: existing.busRideDistanceMeters
                ) {
                    dedup[key] = candidate
                }
            } else {
                dedup[key] = candidate
                order.append(key)
            }
        }

        return order.compactMap { dedup[$0] }
    }

    private func sortedFlatEntries(order: FlatColumnOrder) -> [FlatEntry] {
        flatEntries.sorted { a, b in
            if order == .transferFirst, a.category.rawValue != b.category.rawValue {
                return a.category.rawValue < b.category.rawValue
            }
            // 距離基準 (directionFirst) のときだけ、設定で選んだ測り方を使う。
            // 乗換回数基準内のタイブレークは常に歩行距離優先。
            if order == .directionFirst, distanceMetric == .totalDistance {
                return combinedDistanceMeters(a) < combinedDistanceMeters(b)
            }
            return isBetterDistance(
                walkA: a.totalWalkDistanceMeters, rideA: a.busRideDistanceMeters,
                walkB: b.totalWalkDistanceMeters, rideB: b.busRideDistanceMeters
            )
        }
    }

    /// バス移動距離(道なり) + 徒歩合計。どちらか欠けたら .infinity (後ろへ)。
    private func combinedDistanceMeters(_ entry: FlatEntry) -> Double {
        guard let walk = entry.totalWalkDistanceMeters, let ride = entry.busRideDistanceMeters else {
            return .infinity
        }
        return walk + ride
    }

    @ViewBuilder
    private func flatList(order: FlatColumnOrder) -> some View {
        let entries = sortedFlatEntries(order: order)
        if entries.isEmpty {
            statusText(AppLocaleString.text("ルートなし", locale: locale))
        } else {
            Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    if order == .directionFirst {
                        columnHeaderIcon("safari", accessibilityKey: "方向")
                        columnHeaderIcon("arrow.triangle.swap", accessibilityKey: "乗換回数")
                    } else {
                        columnHeaderIcon("arrow.triangle.swap", accessibilityKey: "乗換回数")
                        columnHeaderIcon("safari", accessibilityKey: "方向")
                    }
                    flatHeaderText("バス番号")
                }
                Divider().gridCellColumns(3)

                ForEach(entries) { entry in
                    GridRow {
                        if order == .directionFirst {
                            flatDirectionText(entry.direction)
                            flatTransferCountIcon(entry.category)
                        } else {
                            flatTransferCountIcon(entry.category)
                            flatDirectionText(entry.direction)
                        }
                        flatBusNumberChain(entry)
                    }
                    Divider().gridCellColumns(3)
                }
            }
        }
    }

    private func flatHeaderText(_ key: String) -> some View {
        Text(AppLocaleString.text(key, locale: locale))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func flatDirectionText(_ direction: String) -> some View {
        Text(direction)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .accessibilityLabel(AppLocaleString.formatted("方向バッジ_%@", locale: locale, direction))
    }

    private func flatTransferCountIcon(_ category: TransferCategory) -> some View {
        columnHeader(icon: "arrow.triangle.swap", digits: category.digits, accessibilityKey: category.categoryKey)
    }

    private func flatBusNumberChain(_ entry: FlatEntry) -> some View {
        TransitBusLineBadgesRow(
            lines: entry.busNumbers,
            ridingBusNumber: ridingBusNumber,
            font: .subheadline.weight(.bold),
            badgeHorizontalPadding: 10,
            badgeVerticalPadding: 5,
            onTap: { _ in onTapBusNumber(entry.routeIndex, entry.firstNumber) },
            onLongPress: { line in onLongPressBusNumber(entry.routeIndex, line) }
        )
        .accessibilityLabel(
            "\(AppLocaleString.text(entry.category.categoryKey, locale: locale)) \(entry.busNumbers.joined(separator: " → "))"
        )
        .accessibilityHint(AppLocaleString.text("バス番号表_操作ヒント", locale: locale))
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
            onTapBusNumber: { _, _ in },
            onLongPressBusNumber: { _, _ in }
        )
        .padding()
    }
}
