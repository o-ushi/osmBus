import Foundation

enum DestinationStore {
    private static let userDefaultsKey = "destination.current"

    static func load() -> Destination? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Destination.self, from: data)
    }

    static func save(_ destination: Destination?) {
        guard let destination else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(destination) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
