import CoreLocation
import Foundation

struct BusRouteListItem: Identifiable, Hashable {
    let relationId: Int
    let ref: String
    let name: String
    let from: String?
    let to: String?
    let hasGeometry: Bool

    var id: Int { relationId }

    var directionText: String? {
        if let from, let to, !from.isEmpty, !to.isEmpty {
            return "\(from) → \(to)"
        }
        return name != ref ? name : nil
    }
}

/// 現在地周辺のバス路線を端末に置く。番号検索と一覧はここを見る。
enum BusRouteCatalogStore {
    private static let fileName = "bus-route-catalog.json"
    private static let lock = NSLock()
    private static var cachedSnapshot: Snapshot?

    struct Summary: Equatable {
        var routeCount: Int
        var geometryCount: Int
        var syncedAt: Date?
    }

    private struct Snapshot: Codable {
        var syncedAt: Date?
        var routes: [Record]
    }

    struct Record: Codable {
        var relationId: Int
        var ref: String
        var name: String
        var from: String?
        var to: String?
        var osmTimestamp: String?
        var stops: [BusLineMapStore.Record.Stop]
        var polylineSegments: [[RouteCoordinate]]
        var hasGeometry: Bool
    }

    static func summary() -> Summary {
        guard ThirdPartyDataConsent.isGranted else {
            return Summary(routeCount: 0, geometryCount: 0, syncedAt: nil)
        }
        lock.lock()
        defer { lock.unlock() }
        let snapshot = load()
        return Summary(
            routeCount: snapshot.routes.count,
            geometryCount: snapshot.routes.filter(\.hasGeometry).count,
            syncedAt: snapshot.syncedAt
        )
    }

    static func listItems() -> [BusRouteListItem] {
        guard ThirdPartyDataConsent.isGranted else { return [] }
        lock.lock()
        let routes = load().routes
        lock.unlock()
        return routes.map(listItem).sorted(by: sortList)
    }

    static func matching(_ query: String) -> [BusRouteListItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return listItems().filter { matches(item: $0, query: trimmed) }
    }

    static func detail(forRelationId relationId: Int) -> BusRouteDetail? {
        guard ThirdPartyDataConsent.isGranted else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let record = load().routes.first(where: { $0.relationId == relationId && $0.hasGeometry }) else {
            return nil
        }
        return detail(from: record)
    }

    static func candidate(forRelationId relationId: Int) -> BusRouteCandidate? {
        guard ThirdPartyDataConsent.isGranted else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let record = load().routes.first(where: { $0.relationId == relationId }) else { return nil }
        return BusRouteCandidate(
            id: record.relationId,
            ref: record.ref,
            name: record.name,
            from: record.from,
            to: record.to
        )
    }

    /// 見出しを取り込み、時刻が変わった路線は形状を捨てて取り直せるようにする。
    /// 今回の範囲から消えた路線は `dropMissing` のときだけ除く。
    static func applyTags(_ tags: [BusRouteCatalogTag], dropMissing: Bool) -> (pendingIDs: [Int], changedCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        var snapshot = load()
        var byID = Dictionary(uniqueKeysWithValues: snapshot.routes.map { ($0.relationId, $0) })
        let freshIDs = Set(tags.map(\.id))
        var changed = 0

        for tag in tags {
            if var existing = byID[tag.id] {
                let timestampChanged = existing.osmTimestamp != tag.timestamp
                existing.ref = tag.ref
                existing.name = tag.name
                existing.from = tag.from
                existing.to = tag.to
                if timestampChanged || !existing.hasGeometry {
                    if existing.hasGeometry { changed += 1 }
                    existing.osmTimestamp = tag.timestamp
                    existing.hasGeometry = false
                    existing.stops = []
                    existing.polylineSegments = []
                }
                byID[tag.id] = existing
            } else {
                changed += 1
                byID[tag.id] = Record(
                    relationId: tag.id,
                    ref: tag.ref,
                    name: tag.name,
                    from: tag.from,
                    to: tag.to,
                    osmTimestamp: tag.timestamp,
                    stops: [],
                    polylineSegments: [],
                    hasGeometry: false
                )
            }
        }

        if dropMissing {
            for id in byID.keys where !freshIDs.contains(id) {
                byID.removeValue(forKey: id)
                changed += 1
            }
        }

        snapshot.routes = Array(byID.values)
        snapshot.syncedAt = Date()
        save(snapshot)
        let pending = snapshot.routes.filter { !$0.hasGeometry }.map(\.relationId)
        return (pending, changed)
    }

    static func saveDetail(_ detail: BusRouteDetail, timestamp: String?) {
        lock.lock()
        defer { lock.unlock() }
        var snapshot = load()
        let record = record(from: detail, timestamp: timestamp, previous: snapshot.routes.first { $0.relationId == detail.candidate.id })
        snapshot.routes.removeAll { $0.relationId == record.relationId }
        snapshot.routes.append(record)
        save(snapshot)
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        cachedSnapshot = nil
        try? FileManager.default.removeItem(at: fileURL())
    }

    private static func record(
        from detail: BusRouteDetail,
        timestamp: String?,
        previous: Record?
    ) -> Record {
        Record(
            relationId: detail.candidate.id,
            ref: detail.candidate.ref,
            name: detail.candidate.name,
            from: detail.candidate.from,
            to: detail.candidate.to,
            osmTimestamp: timestamp ?? previous?.osmTimestamp,
            stops: detail.stops.map {
                BusLineMapStore.Record.Stop(
                    id: $0.id,
                    name: $0.name,
                    latitude: $0.coordinate.latitude,
                    longitude: $0.coordinate.longitude
                )
            },
            polylineSegments: detail.polylineSegments.map { segment in
                segment.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
            },
            hasGeometry: true
        )
    }

    private static func detail(from record: Record) -> BusRouteDetail {
        BusRouteDetail(
            candidate: BusRouteCandidate(
                id: record.relationId,
                ref: record.ref,
                name: record.name,
                from: record.from,
                to: record.to
            ),
            polylineSegments: record.polylineSegments.map { segment in
                segment.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            },
            stops: record.stops.map {
                BusStop(
                    id: $0.id,
                    name: $0.name,
                    coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                )
            }
        )
    }

    private static func listItem(_ record: Record) -> BusRouteListItem {
        BusRouteListItem(
            relationId: record.relationId,
            ref: record.ref,
            name: record.name,
            from: record.from,
            to: record.to,
            hasGeometry: record.hasGeometry
        )
    }

    private static func sortList(_ lhs: BusRouteListItem, _ rhs: BusRouteListItem) -> Bool {
        let refOrder = lhs.ref.localizedStandardCompare(rhs.ref)
        if refOrder != .orderedSame { return refOrder == .orderedAscending }
        return (lhs.from ?? "") < (rhs.from ?? "")
    }

    static func matches(item: BusRouteListItem, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !needle.isEmpty else { return false }
        let ref = item.ref.uppercased()
        if needle.allSatisfy(\.isNumber) {
            return ref.range(of: "^[A-Z]*\(needle)[A-Z]*$", options: .regularExpression) != nil
        }
        if needle.last?.isNumber == true {
            let pattern = "^\(NSRegularExpression.escapedPattern(for: needle))[A-Z]*$"
            return ref.range(of: pattern, options: .regularExpression) != nil
        }
        return ref == needle || ref.hasPrefix(needle)
    }

    private static func load() -> Snapshot {
        if let cachedSnapshot { return cachedSnapshot }
        guard let data = try? Data(contentsOf: fileURL()),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            let empty = Snapshot(syncedAt: nil, routes: [])
            cachedSnapshot = empty
            return empty
        }
        cachedSnapshot = snapshot
        return snapshot
    }

    private static func save(_ snapshot: Snapshot) {
        cachedSnapshot = snapshot
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL(), options: [.atomic])
    }

    private static func fileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("osmBus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }
}

@MainActor
final class BusRouteCatalogDownloader: ObservableObject {
    static let shared = BusRouteCatalogDownloader()

    enum Activity: Equatable {
        case idle
        case working(done: Int, total: Int)
        case message(String)
        case failed(String)
    }

    @Published private(set) var activity: Activity = .idle
    private var task: Task<Void, Never>?

    func downloadAll(near coordinate: CLLocationCoordinate2D) {
        start(near: coordinate, dropMissing: false)
    }

    func update(near coordinate: CLLocationCoordinate2D) {
        start(near: coordinate, dropMissing: true)
    }

    private func start(near coordinate: CLLocationCoordinate2D, dropMissing: Bool) {
        task?.cancel()
        activity = .working(done: 0, total: 0)
        task = Task { [weak self] in
            await self?.run(near: coordinate, dropMissing: dropMissing)
        }
    }

    private func run(near coordinate: CLLocationCoordinate2D, dropMissing: Bool) async {
        do {
            let tags = try await OverpassAPIService.fetchBusRouteCatalog(near: coordinate)
            guard !Task.isCancelled else { return }
            if tags.isEmpty {
                activity = .failed(AppLocaleString.currentText("Overpass_路線なし"))
                return
            }
            let applied = BusRouteCatalogStore.applyTags(tags, dropMissing: dropMissing)
            if dropMissing, applied.changedCount == 0, applied.pendingIDs.isEmpty {
                activity = .message(AppLocaleString.currentText("設定_路線_更新なし"))
                return
            }
            let timestamps = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.timestamp) })
            try await downloadGeometry(ids: applied.pendingIDs, timestamps: timestamps)
            guard !Task.isCancelled else { return }
            let count = BusRouteCatalogStore.summary().geometryCount
            let key = dropMissing ? "設定_路線_更新完了_%d" : "設定_路線_完了_%d"
            activity = .message(AppLocaleString.currentFormatted(key, count))
        } catch {
            guard !Task.isCancelled else { return }
            activity = .failed(AppLocaleString.userFacingError(error))
        }
    }

    private func downloadGeometry(ids: [Int], timestamps: [Int: String?]) async throws {
        let pending = ids.compactMap { BusRouteCatalogStore.candidate(forRelationId: $0) }
        let total = pending.count
        activity = .working(done: 0, total: total)
        guard total > 0 else { return }

        var done = 0
        var index = 0
        while index < pending.count {
            if Task.isCancelled { return }
            let end = min(index + 4, pending.count)
            let chunk = Array(pending[index..<end])
            let details = try await detailsAllowingSplit(chunk)
            for detail in details {
                BusRouteCatalogStore.saveDetail(detail, timestamp: timestamps[detail.candidate.id] ?? nil)
                BusLineMapStore.remember(detail)
            }
            done += chunk.count
            activity = .working(done: done, total: total)
            index = end
            if index < pending.count {
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    private func detailsAllowingSplit(_ candidates: [BusRouteCandidate]) async throws -> [BusRouteDetail] {
        do {
            return try await OverpassAPIService.fetchRouteDetails(candidates)
        } catch {
            if candidates.count == 1 { throw error }
            var collected: [BusRouteDetail] = []
            for candidate in candidates {
                if Task.isCancelled { return collected }
                if let detail = try? await OverpassAPIService.fetchRouteDetail(candidate) {
                    collected.append(detail)
                }
            }
            return collected
        }
    }
}
