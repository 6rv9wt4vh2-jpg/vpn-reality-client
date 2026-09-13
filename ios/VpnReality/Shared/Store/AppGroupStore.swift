import Foundation

/// Persist profiles in the App Group container so App ↔ Extension share state.
final class AppGroupStore: @unchecked Sendable {
    static let shared = AppGroupStore()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    private var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        )
    }

    private var profilesURL: URL? {
        containerURL?.appendingPathComponent(AppConstants.profilesFileName)
    }

    func load() -> ProfilesStoreFile {
        // Prefer file in App Group; fall back to suite UserDefaults; then empty.
        if let url = profilesURL, FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url),
           let store = try? decoder.decode(ProfilesStoreFile.self, from: data) {
            return store
        }
        if let data = defaults?.data(forKey: "profilesStore"),
           let store = try? decoder.decode(ProfilesStoreFile.self, from: data) {
            return store
        }
        return ProfilesStoreFile()
    }

    func save(_ store: ProfilesStoreFile) throws {
        let data = try encoder.encode(store)
        if let url = profilesURL {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        }
        defaults?.set(data, forKey: "profilesStore")
        defaults?.set(store.activeId, forKey: AppConstants.activeProfileIDKey)
        defaults?.synchronize()
    }

    func activeProfile() -> VlessProfile? {
        let store = load()
        guard let id = store.activeId else { return store.profiles.first }
        return store.profiles.first { $0.id == id } ?? store.profiles.first
    }

    func setActive(id: String?) throws {
        var store = load()
        store.activeId = id
        try save(store)
    }

    func upsert(_ profile: VlessProfile) throws {
        var store = load()
        if let idx = store.profiles.firstIndex(where: { $0.id == profile.id }) {
            store.profiles[idx] = profile
        } else {
            store.profiles.append(profile)
        }
        if store.activeId == nil {
            store.activeId = profile.id
        }
        try save(store)
    }

    func delete(id: String) throws {
        var store = load()
        store.profiles.removeAll { $0.id == id }
        if store.activeId == id {
            store.activeId = store.profiles.first?.id
        }
        try save(store)
    }

    /// Write generated xray JSON for the extension to read.
    func writeRuntimeConfigJSON(_ json: String) throws {
        guard let url = containerURL?.appendingPathComponent("runtime-config.json") else {
            throw NSError(domain: "AppGroupStore", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "App Group container unavailable. Set App Group ID in Xcode.",
            ])
        }
        try json.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    func readRuntimeConfigJSON() -> String? {
        guard let url = containerURL?.appendingPathComponent("runtime-config.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
