import Foundation
import Security
import VpnRealityCore

enum ProfileVaultError: LocalizedError {
    case encode(String)
    case keychain(OSStatus)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .encode(let message):
            return "Не удалось сохранить профиль: \(message)"
        case .keychain(let status):
            return "Keychain вернул ошибку \(status). Проверьте keychain-access-groups на приложении и расширении."
        case .invalid(let message):
            return message
        }
    }
}

/// Profiles live in the shared Keychain, not in a plaintext App Group file.
final class ProfileVault {
    static let shared = ProfileVault()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    func load() throws -> ProfilesStoreFile {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return ProfilesStoreFile()
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw ProfileVaultError.keychain(status)
        }
        return try decoder.decode(ProfilesStoreFile.self, from: data)
    }

    func save(_ store: ProfilesStoreFile) throws {
        let data = try encoder.encode(store)
        var query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess {
            return
        }
        if update != errSecItemNotFound {
            throw ProfileVaultError.keychain(update)
        }
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let add = SecItemAdd(query as CFDictionary, nil)
        guard add == errSecSuccess else {
            throw ProfileVaultError.keychain(add)
        }
    }

    func activeProfile() throws -> VlessProfile? {
        let store = try load()
        guard let id = store.activeId else { return store.profiles.first }
        return store.profiles.first { $0.id == id } ?? store.profiles.first
    }

    func upsert(_ profile: VlessProfile) throws {
        let structural = ProfileValidator.structuralIssues(profile)
        if let first = structural.first {
            throw ProfileVaultError.invalid(first.message)
        }
        var store = try load()
        if let index = store.profiles.firstIndex(where: { $0.id == profile.id }) {
            store.profiles[index] = profile
        } else if let index = store.profiles.firstIndex(where: {
            $0.address == profile.address && $0.port == profile.port && $0.uuid == profile.uuid
        }) {
            var merged = profile
            merged.id = store.profiles[index].id
            store.profiles[index] = merged
        } else {
            store.profiles.append(profile)
        }
        if store.activeId == nil {
            store.activeId = store.profiles.last?.id
        }
        try save(store)
    }

    func delete(id: String) throws {
        var store = try load()
        store.profiles.removeAll { $0.id == id }
        if store.activeId == id {
            store.activeId = store.profiles.first?.id
        }
        try save(store)
    }

    func setActive(id: String?) throws {
        var store = try load()
        store.activeId = id
        try save(store)
    }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount,
            kSecAttrSynchronizable as String: false,
        ]
        if let group = accessGroup() {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    /// Expanded at build time from Info.plist (`$(AppIdentifierPrefix)...`).
    private func accessGroup() -> String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: AppConstants.infoKeychainAccessGroup) as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, !trimmed.contains("$") else { return nil }
        return trimmed
    }
}
