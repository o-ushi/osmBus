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

/// メイン画面の乗車判定で確定した路線に合わせて OSM 候補を絞り込むためのヒント。
struct BoardingRouteMatchHint: Sendable {
    let preferredRef: String
    let headsign: String?
    let departureStopName: String?
    let arrivalStopName: String?
}

struct BusStop: Identifiable {
    let id: Int
    let name: String
    let coordinate: CLLocationCoordinate2D
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
        radiusMeters: Int = 80_000
    ) async throws -> [BusRouteCandidate] {
        guard ThirdPartyDataConsent.isGranted else { throw OverpassError.consentRequired }
        let pattern = buildRefPattern(ref)
        let query = """
        [out:json][timeout:30];
        relation["type"="route"]["route"~"bus|trolleybus"]["ref"~"\(pattern)"](around:\(radiusMeters),\(coord.latitude),\(coord.longitude));
        out tags;
        """
        let data = try await post(query)
        return try parseCandidates(from: data)
    }

    /// 路線IDからポリライン＋バス停の完全データを取得。
    static func fetchRouteDetail(_ candidate: BusRouteCandidate) async throws -> BusRouteDetail {
        guard ThirdPartyDataConsent.isGranted else { throw OverpassError.consentRequired }
        let query = """
        [out:json][timeout:60];
        relation(\(candidate.id));
        out body;
        >;
        out body;
        """
        let data = try await post(query)
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

    private static func post(_ query: String) async throws -> Data {
        var lastError: Error = OverpassError.network(URLError(.timedOut))
        for endpoint in endpoints {
            do {
                return try await postTo(endpoint, query: query)
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

    private static func postTo(_ endpoint: URL, query: String) async throws -> Data {
        var req = URLRequest(url: endpoint, timeoutInterval: 60)
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

    private static func parseDetail(
        from data: Data,
        candidate: BusRouteCandidate
    ) throws -> BusRouteDetail {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw OverpassError.parse }
        try checkOverpassRemark(json)
        guard let elements = json["elements"] as? [[String: Any]]
        else { throw OverpassError.parse }

        var nodeCoords: [Int: CLLocationCoordinate2D] = [:]
        var nodeNames: [Int: String] = [:]
        var wayNodes: [Int: [Int]] = [:]
        var relation: [String: Any]?

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
                if relation == nil { relation = el }
            default:
                break
            }
        }

        guard
            let rel = relation,
            let members = rel["members"] as? [[String: Any]]
        else { throw OverpassError.parse }

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

    /// メイン画面で確定済みの乗車路線に最も合う候補を返す。一意に決まらなければ nil。
    static func pickResolvedCandidate(
        from candidates: [BusRouteCandidate],
        hint: BoardingRouteMatchHint?
    ) -> BusRouteCandidate? {
        guard !candidates.isEmpty else { return nil }
        guard let hint else {
            return candidates.count == 1 ? candidates[0] : nil
        }

        let refMatches = candidates.filter {
            $0.ref.caseInsensitiveCompare(hint.preferredRef) == .orderedSame
        }
        let pool = refMatches.isEmpty ? candidates : refMatches
        if pool.count == 1 { return pool[0] }

        let ranked = pool.sorted {
            scoreCandidate($0, hint: hint) > scoreCandidate($1, hint: hint)
        }
        guard let best = ranked.first, ranked.count > 1 else { return ranked.first }

        let bestScore = scoreCandidate(best, hint: hint)
        let secondScore = scoreCandidate(ranked[1], hint: hint)
        if bestScore > 0, bestScore > secondScore {
            return best
        }
        return nil
    }

    private static func scoreCandidate(_ candidate: BusRouteCandidate, hint: BoardingRouteMatchHint) -> Int {
        var score = 0
        if candidate.ref.caseInsensitiveCompare(hint.preferredRef) == .orderedSame {
            score += 20
        }
        if let to = candidate.to {
            if let headsign = hint.headsign {
                score += normalizedMatchScore(to, headsign)
            }
            if let arrival = hint.arrivalStopName {
                score += normalizedMatchScore(to, arrival) / 2
            }
        }
        if let from = candidate.from, let departure = hint.departureStopName {
            score += normalizedMatchScore(from, departure)
        }
        return score
    }

    private static func normalizedMatchScore(_ a: String, _ b: String) -> Int {
        let x = a.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let y = b.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        if x == y { return 10 }
        if x.contains(y) || y.contains(x) { return 6 }
        return 0
    }
}
