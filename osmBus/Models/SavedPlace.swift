import Foundation

struct SavedPlace: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var label: String
    var placeName: String
    var subtitle: String?
    var latitude: Double
    var longitude: Double

    init(
        id: UUID = UUID(),
        label: String,
        placeName: String,
        subtitle: String?,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.label = label
        self.placeName = placeName
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
    }

    var detailLine: String {
        if placeName == label {
            return subtitle ?? placeName
        }
        if let subtitle, !subtitle.isEmpty {
            return "\(placeName) · \(subtitle)"
        }
        return placeName
    }

    func makeDestination() -> Destination {
        Destination(
            name: label,
            subtitle: detailLine == label ? subtitle : detailLine,
            latitude: latitude,
            longitude: longitude
        )
    }

    static func matches(_ place: SavedPlace, destination: Destination) -> Bool {
        abs(place.latitude - destination.latitude) < 0.00001
            && abs(place.longitude - destination.longitude) < 0.00001
    }

    static func from(destination: Destination, label: String) -> SavedPlace {
        SavedPlace(
            label: label,
            placeName: destination.name,
            subtitle: destination.subtitle,
            latitude: destination.latitude,
            longitude: destination.longitude
        )
    }
}

enum SavedPlaceStore {
    private static let userDefaultsKey = "savedPlaces.list"

    static func loadAll() -> [SavedPlace] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let places = try? JSONDecoder().decode([SavedPlace].self, from: data) else {
            return []
        }
        return places
    }

    static func saveAll(_ places: [SavedPlace]) {
        guard let data = try? JSONEncoder().encode(places) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    static func add(_ place: SavedPlace) -> Bool {
        var places = loadAll()
        guard places.count < PlanStore.shared.savedPlaceLimit else { return false }
        places.append(place)
        saveAll(places)
        return true
    }

    static func update(_ place: SavedPlace) {
        var places = loadAll()
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index] = place
        saveAll(places)
    }

    static func delete(id: UUID) {
        var places = loadAll()
        places.removeAll { $0.id == id }
        saveAll(places)
    }

    static func trim(to count: Int) {
        var places = loadAll()
        guard places.count > count else { return }
        places = Array(places.prefix(count))
        saveAll(places)
    }
}
