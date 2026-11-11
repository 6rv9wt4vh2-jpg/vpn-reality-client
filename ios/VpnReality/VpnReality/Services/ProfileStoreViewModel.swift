import Combine
import Foundation
import VpnRealityCore

@MainActor
final class ProfileStoreViewModel: ObservableObject {
    @Published private(set) var items: [VlessProfile] = []
    @Published private(set) var activeId: String?
    @Published var lastError: String?

    var activeProfile: VlessProfile? {
        guard let activeId else { return items.first }
        return items.first { $0.id == activeId } ?? items.first
    }

    func reload() {
        do {
            let store = try ProfileVault.shared.load()
            items = store.profiles
            activeId = store.activeId
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func upsert(_ profile: VlessProfile) throws {
        try ProfileVault.shared.upsert(profile)
        reload()
    }

    func delete(id: String) throws {
        try ProfileVault.shared.delete(id: id)
        reload()
    }

    func setActive(id: String?) throws {
        try ProfileVault.shared.setActive(id: id)
        reload()
    }
}
