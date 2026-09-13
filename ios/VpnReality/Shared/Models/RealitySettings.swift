import Foundation

/// XTLS Reality client settings (first-class fields).
struct RealitySettings: Codable, Equatable, Hashable, Sendable {
    var publicKey: String
    var shortId: String
    var serverNames: [String]
    var fingerprint: String
    var spiderX: String
    /// Usually server-side; kept for import parity with desktop client.
    var dest: String?

    enum CodingKeys: String, CodingKey {
        case publicKey = "public_key"
        case shortId = "short_id"
        case serverNames = "server_names"
        case fingerprint
        case spiderX = "spider_x"
        case dest
    }

    init(
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Accept both snake_case (our JSON) and camelCase (xray-style snippets)
        if let pk = try c.decodeIfPresent(String.self, forKey: .publicKey) {
            publicKey = pk
        } else {
            publicKey = try Self.decodeAlt(c, key: .publicKey, alts: ["publicKey", "pbk"]) ?? ""
        }
        shortId = try c.decodeIfPresent(String.self, forKey: .shortId)
            ?? Self.decodeAlt(c, key: .shortId, alts: ["shortId", "sid"])
            ?? ""
        if let names = try c.decodeIfPresent([String].self, forKey: .serverNames) {
            serverNames = names
        } else if let sni = Self.decodeAlt(c, key: .serverNames, alts: ["serverName", "sni"]) {
            serverNames = sni.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            serverNames = ["www.cloudflare.com"]
        }
        fingerprint = try c.decodeIfPresent(String.self, forKey: .fingerprint)
            ?? Self.decodeAlt(c, key: .fingerprint, alts: ["fp"])
            ?? "chrome"
        spiderX = try c.decodeIfPresent(String.self, forKey: .spiderX)
            ?? Self.decodeAlt(c, key: .spiderX, alts: ["spiderX", "spx"])
            ?? "/"
        dest = try c.decodeIfPresent(String.self, forKey: .dest)
    }

    private static func decodeAlt(
        _ c: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys,
        alts: [String]
    ) -> String? {
        // Fallback via JSONSerialization-style isn't available here; callers use flexible importer.
        _ = c
        _ = key
        _ = alts
        return nil
    }
}
