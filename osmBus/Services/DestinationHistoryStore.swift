import Foundation

struct DestinationHistoryEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let destination: Destination
    let setAt: Date

    init(id: UUID = UUID(), destination: Destination, setAt: Date = Date()) {
        self.id = id
        self.destination = destination
        self.setAt = setAt
    }
}

enum DestinationHistoryStore {
    private static let userDefaultsKey = "destination.history"

    static func loadAll() -> [DestinationHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let entries = try? JSONDecoder().decode([DestinationHistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    static func saveAll(_ entries: [DestinationHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    static func add(_ destination: Destination) {
        let limit = PlanStore.shared.historyLimit
        var entries = loadAll()
        entries.removeAll { matches($0.destination, destination) }
        entries.insert(DestinationHistoryEntry(destination: destination), at: 0)
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
        }
        saveAll(entries)
    }

    static func trim(to count: Int) {
        var entries = loadAll()
        guard entries.count > count else { return }
        entries = Array(entries.prefix(count))
        saveAll(entries)
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    static func matches(_ lhs: Destination, _ rhs: Destination) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.00001
            && abs(lhs.longitude - rhs.longitude) < 0.00001
    }
}
