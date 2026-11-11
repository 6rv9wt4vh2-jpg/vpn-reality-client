import Foundation

/// XTLS Reality client settings. JSON keys match the desktop client.
public struct RealitySettings: Codable, Equatable, Hashable, Sendable {
    public var publicKey: String
    public var shortId: String
    public var serverNames: [String]
    public var fingerprint: String
    public var spiderX: String
    /// Usually server-side. Kept so desktop JSON imports round-trip.
    public var dest: String?

    enum CodingKeys: String, CodingKey {
        case publicKey = "public_key"
        case shortId = "short_id"
        case serverNames = "server_names"
        case fingerprint
        case spiderX = "spider_x"
        case dest
    }

    public init(
        publicKey: String,
        shortId: String = "",
        serverNames: [String] = ["www.cloudflare.com"],
        fingerprint: String = "chrome",
        spiderX: String = "/",
        dest: String? = nil
    ) {
        self.publicKey = publicKey
        self.shortId = shortId
        self.serverNames = serverNames.isEmpty ? ["www.cloudflare.com"] : serverNames
        self.fingerprint = fingerprint
        self.spiderX = spiderX
        self.dest = dest
    }
}
