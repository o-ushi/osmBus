import CoreLocation
import Foundation
import MapKit

enum DestinationSearchService {
    struct Candidate: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let subtitle: String?
        let coordinate: CLLocationCoordinate2D
    }

    enum SearchError: LocalizedError {
        case emptyQuery
        case queryTooShort
        case noResults

        var errorDescription: String? {
            switch self {
            case .emptyQuery:
                return AppLocaleString.currentText("osmBus_検索_空入力")
            case .queryTooShort:
                return AppLocaleString.currentText("osmBus_検索_2文字以上")
            case .noResults:
                return AppLocaleString.currentText("見つかりませんでした。別のキーワードで試してください。")
            }
        }
    }

    static func searchPlaces(query: String) async throws -> [Candidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SearchError.emptyQuery }
        guard trimmed.count >= 2 else { throw SearchError.queryTooShort }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]

        let response = try await MKLocalSearch(request: request).start()
        let items = response.mapItems
        guard !items.isEmpty else { throw SearchError.noResults }

        return items.map { item in
            let name = item.name ?? item.placemark.name ?? trimmed
            return Candidate(
                name: name,
                subtitle: subtitle(for: item.placemark),
                coordinate: item.placemark.coordinate
            )
        }
    }

    private static func subtitle(for placemark: MKPlacemark) -> String? {
        let parts = [
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea,
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }
}
