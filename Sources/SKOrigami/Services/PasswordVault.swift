import Foundation

final class PasswordVault {
    private let storageKey = "passwordRecords"

    func load() -> [PasswordRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([PasswordRecord].self, from: data)) ?? []
    }

    func save(_ records: [PasswordRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
