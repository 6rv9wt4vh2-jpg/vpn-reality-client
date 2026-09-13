import Foundation
import Combine

@MainActor
final class ProfileStoreViewModel: ObservableObject {
    @Published private(set) var items: [VlessProfile] = []
    @Published private(set) var activeId: String?

    var activeProfile: VlessProfile? {
        guard let activeId else { return items.first }
        return items.first { $0.id == activeId } ?? items.first
    }

    func reload() {
        let store = AppGroupStore.shared.load()
        items = store.profiles
        activeId = store.activeId
    }

    func upsert(_ profile: VlessProfile) throws {
        try AppGroupStore.shared.upsert(profile)
        reload()
    }

    func delete(id: String) throws {
        try AppGroupStore.shared.delete(id: id)
        reload()
    }

    func setActive(id: String?) throws {
        try AppGroupStore.shared.setActive(id: id)
        reload()
    }
}
