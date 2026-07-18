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
        case consentRequired
        case emptyQuery
        case queryTooShort
        case noResults

        var errorDescription: String? {
            switch self {
            case .consentRequired:
                return ThirdPartyDataConsent.requiredMessage
            case .emptyQuery:
                return AppLocaleString.currentText("検索_空入力")
            case .queryTooShort:
                return AppLocaleString.currentText("検索_2文字以上")
            case .noResults:
                return AppLocaleString.currentText("見つかりませんでした。別のキーワードで試してください。")
            }
        }
    }

    static func searchPlaces(query: String) async throws -> [Candidate] {
        guard ThirdPartyDataConsent.isGranted else { throw SearchError.consentRequired }
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

    struct PlaceSearchOutcome {
        let candidates: [Candidate]
        let errorMessage: String?
        let isSearching: Bool
    }

    @MainActor
    static func performPlaceSearch(query: String) async -> PlaceSearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return PlaceSearchOutcome(candidates: [], errorMessage: nil, isSearching: false)
        }

        do {
            let results = try await searchPlaces(query: trimmed)
            return PlaceSearchOutcome(candidates: results, errorMessage: nil, isSearching: false)
        } catch let error as SearchError {
            return PlaceSearchOutcome(candidates: [], errorMessage: error.localizedDescription, isSearching: false)
        } catch {
            return PlaceSearchOutcome(
                candidates: [],
                errorMessage: AppLocaleString.currentText("検索_失敗"),
                isSearching: false
            )
        }
    }
}

/// 目的地検索のデバウンス付きスケジューラ。
@MainActor
final class DebouncedPlaceSearch {
    private var searchTask: Task<Void, Never>?
    private let debounceNanoseconds: UInt64

    init(debounceMilliseconds: UInt64 = 350) {
        debounceNanoseconds = debounceMilliseconds * 1_000_000
    }

    func schedule(query: String, immediate: Bool = false, perform: @escaping (String) async -> Void) {
        searchTask?.cancel()
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            await perform(query)
        }
    }

    func cancel() {
        searchTask?.cancel()
    }
}
