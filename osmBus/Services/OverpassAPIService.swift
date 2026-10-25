import CoreLocation
import Foundation

// MARK: - Domain Models

struct BusRouteCandidate: Identifiable, Hashable {
    let id: Int
    let ref: String
    let name: String
    let from: String?
    let to: String?

    var directionLabel: String? {
        guard let f = from, let t = to, !f.isEmpty, !t.isEmpty else { return nil }
        return "\(f) → \(t)"
    }
}

struct BusStop: Identifiable {
    let id: Int
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct BusRouteCatalogTag: Hashable {
    let id: Int
    let ref: String
    let name: String
    let from: String?
    let to: String?
    let timestamp: String?
}

struct BusRouteDetail {
    let candidate: BusRouteCandidate
    let polylineSegments: [[CLLocationCoordinate2D]]
    let stops: [BusStop]
}

// MARK: - Errors

enum OverpassError: LocalizedError {
    case consentRequired
    case noLocation
    case network(Error)
    case parse
    case noResults
    case serverTimeout
    case serverProcessing
    case serverHTTP(String)

    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return ThirdPartyDataConsent.requiredMessage
        case .noLocation:
            return AppLocaleString.currentText("Overpass_現在地なし")
        case .network:
            return AppLocaleString.currentText("Overpass_通信エラー")
        case .parse:
            return AppLocaleString.currentText("Overpass_解析失敗")
        case .noResults:
            return AppLocaleString.currentText("Overpass_路線なし")
        case .serverTimeout:
            return AppLocaleString.currentText("Overpass_タイムアウト")
        case .serverProcessing:
            return AppLocaleString.currentText("Overpass_サーバー処理")
        case .serverHTTP(let msg):
            return AppLocaleString.currentFormatted("Overpass_サーバー_%@", msg)
        }
    }
}

// MARK: - Service

enum OverpassAPIService {
    private static let endpoints: [URL] = [
        URL(string: "https://overpass-api.de/api/interpreter")!,
        URL(string: "https://overpass.kumi.systems/api/interpreter")!,
        URL(string: "https://maps.mail.ru/osm/tools/overpass/api/interpreter")!,
    ]

    /// 路線番号で候補を検索。タグのみ取得するため高速。
    static func searchCandidates(
        ref: String,
        near coord: CLLocationCoordinate2D,
        radiusMeters: Int = 80_000,
        timeoutSeconds: TimeInterval = 30,
        maxEndpoints: Int = 3
    ) async throws -> [BusRouteCandidate] {
        guard ThirdPartyDataConsent.isGranted else { throw OverpassError.consentRequired }
        let pattern = buildRefPattern(ref)
        let queryTimeout = max(5, Int(timeoutSeconds.rounded(.down)))
        let query = """
        [out:json][timeout:\(queryTimeout)];
        relation["type"="route"]["route"~"bus|trolleybus"]["ref"~"\(pattern)"](around:\(radiusMeters),\(coord.latitude),\(coord.longitude));
        out tags;
        """
        let data = try await post(query, timeoutSeconds: timeoutSeconds, maxEndpoints: maxEndpoints)
        return try parseCandidates(from: data)
    }

    /// 現在地の周辺にあるバス路線の見出しだけを取る。形状は含まない。
    static func fetchBusRouteCatalog(
        near coord: CLLocationCoordinate2D,
        radiusMeters: Int = 80_000
    ) async throws -> [BusRouteCatalogTag] {
        guard ThirdPartyDataConsent.isGranted else { throw OverpassError.consentRequired }
        let query = """
        [out:json][timeout:90];
        relation["type"="route"]["route"~"bus|trolleybus"](around:\(radiusMeters),\(coord.latitude),\(coord.longitude));
        out tags meta;
        """
        let data = try await post(query, timeoutSeconds: 100, maxEndpoints: 3)
        return try parseCatalogTags(from: data)
    }

    /// 複数路線の形状と停留所を一度に取る。
    static func fetchRouteDetails(
        _ candidates: [BusRouteCandidate],
        timeoutSeconds: TimeInterval = 90
    ) async throws -> [BusRouteDetail] {
        guard ThirdPartyDataConsent.isGranted else { throw OverpassError.consentRequired }
        guard !candidates.isEmpty else { return [] }
        let ids = candidates.map { String($0.id) }.joined(separator: ",")
        let queryTimeout = max(5, Int(timeoutSeconds.rounded(.down)))
        let query = """
        [out:json][timeout:\(queryTimeout)];
        relation(id:\(ids));
        out body;
        >;
        out body;
        """
        let data = try await post(query, timeoutSeconds: timeoutSeconds + 10, maxEndpoints: 3)
        return try parseDetails(from: data, candidates: candidates)
    }

    /// 路線IDからポリライン＋バス停の完全データを取得。
    static func fetchRouteDetail(
        _ candidate: BusRouteCandidate,
        timeoutSeconds: TimeInterval = 60,
        maxEndpoints: Int = 3
    ) async throws -> BusRouteDetail {
        guard ThirdPartyDataConsent.isGranted else { throw OverpassError.consentRequired }
        let queryTimeout = max(5, Int(timeoutSeconds.rounded(.down)))
        let query = """
        [out:json][timeout:\(queryTimeout)];
        relation(\(candidate.id));
        out body;
        >;
        out body;
        """
        let data = try await post(query, timeoutSeconds: timeoutSeconds, maxEndpoints: maxEndpoints)
        return try parseDetail(from: data, candidate: candidate)
    }

    // MARK: - Internal helpers

    /// 純粋に数字だけの入力: "05" → "^[A-Za-z]*05[A-Za-z]*$"（E05, 05, 05A 等にマッチ）
    /// 数字で終わる英数字混在: "B0" → "^B0[A-Za-z]*$"
    /// 英字で終わる場合: "05A" → "^[A-Za-z]*05A$"
    /// ※ + は form-encoding で空白に化けるため [A-Za-z]* で代替する
    private static func buildRefPattern(_ ref: String) -> String {
        let escaped = ref
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "+", with: "\\+")
            .replacingOccurrences(of: "*", with: "\\*")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        let allDigits = ref.allSatisfy(\.isNumber)
        if allDigits {
            // 純粋数字入力: 先頭に英字プレフィックスも許す（E05, 05 両方ヒット）
            return "^[A-Za-z]*\(escaped)[A-Za-z]*$"
        }
        if ref.last?.isNumber == true {
            // 英字で始まり数字で終わる: 末尾に英字サフィックスを許す
            return "^\(escaped)[A-Za-z]*$"
        }
        return "^\(escaped)$"
    }

    private static func post(
        _ query: String,
        timeoutSeconds: TimeInterval = 60,
        maxEndpoints: Int = 3
    ) async throws -> Data {
        var lastError: Error = OverpassError.network(URLError(.timedOut))
        let servers = Array(endpoints.prefix(max(1, maxEndpoints)))
        for endpoint in servers {
            do {
                return try await postTo(endpoint, query: query, timeoutSeconds: timeoutSeconds)
            } catch let e as OverpassError {
                switch e {
                case .serverTimeout, .serverProcessing, .serverHTTP, .network:
                    lastError = e
                default:
                    throw e
                }
            } catch {
                lastError = OverpassError.network(error)
            }
        }
        throw lastError
    }

    private static func postTo(_ endpoint: URL, query: String, timeoutSeconds: TimeInterval) async throws -> Data {
        var req = URLRequest(url: endpoint, timeoutInterval: timeoutSeconds)
        req.httpMethod = "POST"
        var safeChars = CharacterSet.urlQueryAllowed
        safeChars.remove(charactersIn: "+")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: safeChars) ?? query
        req.httpBody = "data=\(encoded)".data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("osmBus iOS/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw OverpassError.serverHTTP("HTTP \(http.statusCode)")
            }
            return data
        } catch let e as OverpassError {
            throw e
        } catch {
            throw OverpassError.network(error)
        }
    }

    // MARK: - Parsing

    private static func parseCandidates(from data: Data) throws -> [BusRouteCandidate] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw OverpassError.parse }
        try checkOverpassRemark(json)
        guard let elements = json["elements"] as? [[String: Any]]
        else { throw OverpassError.parse }

        return elements.compactMap { el -> BusRouteCandidate? in
            guard
                let id = el["id"] as? Int,
                let tags = el["tags"] as? [String: String],
                let ref = tags["ref"]
            else { return nil }
            return BusRouteCandidate(
                id: id, ref: ref,
                name: tags["name"] ?? ref,
                from: tags["from"],
                to: tags["to"]
            )
        }
        .sorted { $0.ref.localizedStandardCompare($1.ref) == .orderedAscending }
    }

    private static func checkOverpassRemark(_ json: [String: Any]) throws {
        guard let remark = json["remark"] as? String, !remark.isEmpty else { return }
        let lower = remark.lowercased()
        if lower.contains("timeout") || lower.contains("out of time") || lower.contains("timed out") {
            throw OverpassError.serverTimeout
        }
        if lower.contains("runtime error") || lower.contains("error") {
            throw OverpassError.serverProcessing
        }
    }

    private static func parseCatalogTags(from data: Data) throws -> [BusRouteCatalogTag] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw OverpassError.parse }
        try checkOverpassRemark(json)
        guard let elements = json["elements"] as? [[String: Any]]
        else { throw OverpassError.parse }

        return elements.compactMap { el -> BusRouteCatalogTag? in
            guard
                el["type"] as? String == "relation",
                let id = el["id"] as? Int,
                let tags = el["tags"] as? [String: String],
                let ref = tags["ref"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                !ref.isEmpty
            else { return nil }
            return BusRouteCatalogTag(
                id: id,
                ref: ref,
                name: tags["name"] ?? ref,
                from: tags["from"],
                to: tags["to"],
                timestamp: el["timestamp"] as? String
            )
        }
    }

    private static func parseDetail(
        from data: Data,
        candidate: BusRouteCandidate
    ) throws -> BusRouteDetail {
        let details = try parseDetails(from: data, candidates: [candidate])
        guard let detail = details.first else { throw OverpassError.parse }
        return detail
    }

    private static func parseDetails(
        from data: Data,
        candidates: [BusRouteCandidate]
    ) throws -> [BusRouteDetail] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw OverpassError.parse }
        try checkOverpassRemark(json)
        guard let elements = json["elements"] as? [[String: Any]]
        else { throw OverpassError.parse }

        var nodeCoords: [Int: CLLocationCoordinate2D] = [:]
        var nodeNames: [Int: String] = [:]
        var wayNodes: [Int: [Int]] = [:]
        var relations: [Int: [String: Any]] = [:]

        for el in elements {
            guard let type = el["type"] as? String, let id = el["id"] as? Int else { continue }
            switch type {
            case "node":
                if let lat = el["lat"] as? Double, let lon = el["lon"] as? Double {
                    nodeCoords[id] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                if let tags = el["tags"] as? [String: String] {
                    nodeNames[id] = tags["name"] ?? tags["name:en"] ?? tags["name:vi"]
                }
            case "way":
                if let nodes = el["nodes"] as? [Int] {
                    wayNodes[id] = nodes
                }
            case "relation":
                relations[id] = el
            default:
                break
            }
        }

        return candidates.compactMap { candidate in
            guard let relation = relations[candidate.id] else { return nil }
            return detail(
                candidate: candidate,
                relation: relation,
                nodeCoords: nodeCoords,
                nodeNames: nodeNames,
                wayNodes: wayNodes
            )
        }
    }

    private static func detail(
        candidate: BusRouteCandidate,
        relation: [String: Any],
        nodeCoords: [Int: CLLocationCoordinate2D],
        nodeNames: [Int: String],
        wayNodes: [Int: [Int]]
    ) -> BusRouteDetail? {
        guard let members = relation["members"] as? [[String: Any]] else { return nil }

        let roadStopRoles: Set<String> = ["stop", "stop_entry_only", "stop_exit_only"]
        var orderedWayIDs: [Int] = []
        var stopNodeIDs: [Int] = []
        var platformNodeIDs: [Int] = []

        for member in members {
            guard
                let mtype = member["type"] as? String,
                let ref = member["ref"] as? Int
            else { continue }
            let role = member["role"] as? String ?? ""
            if mtype == "way" {
                orderedWayIDs.append(ref)
            } else if mtype == "node" {
                if roadStopRoles.contains(role) {
                    stopNodeIDs.append(ref)
                } else if role == "platform" {
                    platformNodeIDs.append(ref)
                }
            }
        }
        // road-side stop ノードを優先し、存在しない場合のみ platform ノードを使う
        let finalStopNodeIDs = stopNodeIDs.isEmpty ? platformNodeIDs : stopNodeIDs

        let segments: [[CLLocationCoordinate2D]] = orderedWayIDs.compactMap { wid in
            guard let nids = wayNodes[wid] else { return nil }
            let coords = nids.compactMap { nodeCoords[$0] }
            guard coords.count >= 2 else { return nil }
            return decimateCoordinates(coords)
        }

        var seen = Set<Int>()
        let stops: [BusStop] = finalStopNodeIDs.compactMap { nid in
            guard seen.insert(nid).inserted, let coord = nodeCoords[nid] else { return nil }
            return BusStop(id: nid, name: nodeNames[nid] ?? "Stop", coordinate: coord)
        }

        return BusRouteDetail(candidate: candidate, polylineSegments: segments, stops: stops)
    }

    /// OSM way の全ノードをそのまま描画するとメモリを大量消費するため、表示用に間引く。
    private static func decimateCoordinates(
        _ coordinates: [CLLocationCoordinate2D],
        maxPoints: Int = 400
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints else { return coordinates }
        let lastIndex = coordinates.count - 1
        return (0..<maxPoints).map { i in
            let index = min(lastIndex, (i * lastIndex) / (maxPoints - 1))
            return coordinates[index]
        }
    }

}
