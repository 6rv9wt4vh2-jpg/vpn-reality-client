import Foundation

/// Stored client profile: VLESS + Reality. Field names match `vpn_client.models.VlessProfile`.
public struct VlessProfile: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var address: String
    public var port: Int
    public var uuid: String
    public var flow: String
    public var encryption: String
    public var network: String
    public var security: String
    public var reality: RealitySettings
    public var socksPort: Int
    public var httpPort: Int?
    public var notes: String

    enum CodingKeys: String, CodingKey {
        case id, name, address, port, uuid, flow, encryption, network, security, reality, notes
        case socksPort = "socks_port"
        case httpPort = "http_port"
    }

    public init(
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

    public func primarySNI() -> String {
        reality.serverNames.first ?? "www.example.com"
    }

    public var endpointSummary: String {
        "\(address):\(port)"
    }
}

public struct ProfilesStoreFile: Codable, Equatable, Sendable {
    public var profiles: [VlessProfile]
    public var activeId: String?

    enum CodingKeys: String, CodingKey {
        case profiles
        case activeId = "active_id"
    }

    public init(profiles: [VlessProfile] = [], activeId: String? = nil) {
        self.profiles = profiles
        self.activeId = activeId
    }
}
