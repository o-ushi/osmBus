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
    private static let keychainKey = "destination.history"
    /// 旧 UserDefaults 実装からの移行用（再インストールで履歴が消えないよう Keychain に移した）。
    private static let legacyUserDefaultsKey = "destination.history"

    static func loadAll() -> [DestinationHistoryEntry] {
        if let data = KeychainStore.load(key: keychainKey),
           let entries = try? JSONDecoder().decode([DestinationHistoryEntry].self, from: data) {
            return entries
        }
        if let legacyData = UserDefaults.standard.data(forKey: legacyUserDefaultsKey),
           let entries = try? JSONDecoder().decode([DestinationHistoryEntry].self, from: legacyData) {
            saveAll(entries)
            UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
            return entries
        }
        return []
    }

    static func saveAll(_ entries: [DestinationHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        KeychainStore.save(key: keychainKey, data: data)
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
        KeychainStore.delete(key: keychainKey)
        UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
    }

    static func matches(_ lhs: Destination, _ rhs: Destination) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.00001
            && abs(lhs.longitude - rhs.longitude) < 0.00001
    }
}
