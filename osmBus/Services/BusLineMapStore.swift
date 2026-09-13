import CoreLocation
import Foundation

/// テンキーや OSM 路線図で一度取ったバス全線（停留所＋形状）を端末に溜める。
/// Google 案に無い番号の代替乗車は、まずこの地図で今の出発地と乗換停を判定する。
enum BusLineMapStore {
    private static let maxLines = 40
    private static let fileName = "bus-line-maps.json"
    private static let lock = NSLock()

    struct Record: Codable {
        var relationId: Int
        var ref: String
        var name: String
        var from: String?
        var to: String?
        var stops: [Stop]
        var polylineSegments: [[RouteCoordinate]]
        var lastUsedAt: Date

        struct Stop: Codable {
            var id: Int
            var name: String
            var latitude: Double
            var longitude: Double
        }
    }

    static func remember(_ detail: BusRouteDetail) {
        lock.lock()
        defer { lock.unlock() }
        var records = load()
        let record = Record(
            relationId: detail.candidate.id,
            ref: detail.candidate.ref,
            name: detail.candidate.name,
            from: detail.candidate.from,
            to: detail.candidate.to,
            stops: detail.stops.map {
                Record.Stop(
                    id: $0.id,
                    name: $0.name,
                    latitude: $0.coordinate.latitude,
                    longitude: $0.coordinate.longitude
                )
            },
            polylineSegments: detail.polylineSegments.map { segment in
                segment.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
            },
            lastUsedAt: Date()
        )
        records.removeAll { $0.relationId == record.relationId }
        records.append(record)
        save(records)
    }

    static func details(matching busNumber: String) -> [BusRouteDetail] {
        lock.lock()
        let records = load()
        lock.unlock()
        let variants = GoogleRoutesAPIService.busNumberVariants(busNumber)
        return records
            .filter { record in
                variants.contains { variant in
                    GoogleRoutesAPIService.containsBusNumber(record.ref, busNumber: variant)
                        || GoogleRoutesAPIService.containsBusNumber(record.name, busNumber: variant)
                }
            }
            .sorted { $0.lastUsedAt > $1.lastUsedAt }
            .map(detail(from:))
    }

    /// 一覧表示用。`lastUsedAt` 降順（`relationId` は `remember` 側で重複除去済み）。
    /// 同意撤回中は、以前取得済みの第三者(OSM)データをユーザー向け一覧に出さない。
    static func recentRecords() -> [Record] {
        guard ThirdPartyDataConsent.isGranted else { return [] }
        lock.lock()
        defer { lock.unlock() }
        return load().sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    static func detail(forRelationId relationId: Int) -> BusRouteDetail? {
        guard ThirdPartyDataConsent.isGranted else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let record = load().first(where: { $0.relationId == relationId }) else { return nil }
        return detail(from: record)
    }

    static func forget(relationId: Int) {
        lock.lock()
        defer { lock.unlock() }
        var records = load()
        records.removeAll { $0.relationId == relationId }
        save(records)
    }

    static func touch(relationId: Int) {
        lock.lock()
        defer { lock.unlock() }
        var records = load()
        guard let index = records.firstIndex(where: { $0.relationId == relationId }) else { return }
        records[index].lastUsedAt = Date()
        save(records)
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileURL())
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

    private static func load() -> [Record] {
        guard let data = try? Data(contentsOf: fileURL()) else { return [] }
        return (try? JSONDecoder().decode([Record].self, from: data)) ?? []
    }

    private static func save(_ records: [Record]) {
        var trimmed = records
        if trimmed.count > maxLines {
            trimmed.sort { $0.lastUsedAt > $1.lastUsedAt }
            trimmed = Array(trimmed.prefix(maxLines))
        }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        try? data.write(to: fileURL(), options: [.atomic])
    }

    private static func fileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("osmBus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }
}
