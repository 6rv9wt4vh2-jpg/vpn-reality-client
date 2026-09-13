import Foundation

/// Stored client profile: VLESS + Reality outbound.
struct VlessProfile: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: String
    var name: String
    var address: String
    var port: Int
    var uuid: String
    var flow: String
    var encryption: String
    var network: String
    var security: String
    var reality: RealitySettings
    var socksPort: Int
    var httpPort: Int?
    var notes: String

    enum CodingKeys: String, CodingKey {
        case id, name, address, port, uuid, flow, encryption, network, security, reality, notes
        case socksPort = "socks_port"
        case httpPort = "http_port"
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        port: Int,
        uuid: String,
        flow: String = "xtls-rprx-vision",
        encryption: String = "none",
        network: String = "tcp",
        security: String = "reality",
        reality: RealitySettings,
        socksPort: Int = 10808,
        httpPort: Int? = 10809,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.uuid = uuid
        self.flow = flow
        self.encryption = encryption
        self.network = network
        self.security = security
        self.reality = reality
        self.socksPort = socksPort
        self.httpPort = httpPort
        self.notes = notes
    }

    func primarySNI() -> String {
        reality.serverNames.first ?? "www.example.com"
    }

    /// Human-readable subtitle for lists.
    var endpointSummary: String {
        "\(address):\(port)"
    }
}

struct ProfilesStoreFile: Codable, Equatable, Sendable {
    var profiles: [VlessProfile]
    var activeId: String?

    enum CodingKeys: String, CodingKey {
        case profiles
        case activeId = "active_id"
    }

    init(profiles: [VlessProfile] = [], activeId: String? = nil) {
        self.profiles = profiles
        self.activeId = activeId
    }
}
