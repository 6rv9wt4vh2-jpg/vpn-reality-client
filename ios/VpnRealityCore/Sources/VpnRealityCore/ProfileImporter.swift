import Foundation

public enum ProfileImportError: LocalizedError, Equatable {
    case empty
    case invalidURI
    case missingPublicKey
    case unrecognizedJSON
    case unsupportedSecurity(String)
    case unsupportedTransport(String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "Пустой ввод"
        case .invalidURI:
            return "Некорректный vless:// URI: нужны UUID, адрес и порт"
        case .missingPublicKey:
            return "В ссылке нет Reality public key (pbk)"
        case .unrecognizedJSON:
            return "Это не профиль VPN Reality и не VLESS outbound"
        case .unsupportedSecurity(let value):
            return "Это приложение поднимает только VLESS + Reality (security=\(value))"
        case .unsupportedTransport(let value):
            return "Туннель поддерживает только TCP (type=\(value))"
        case .decoding(let message):
            return message
        }
    }
}

public enum ProfileImporter {
    /// Import a `vless://` URI or profile JSON. Desktop `import_any` accepts the same shapes.
    /// iOS additionally refuses an explicit non-Reality security or non-TCP transport,
    /// because the packet tunnel cannot carry those profiles.
    public static func importAny(_ text: String) throws -> VlessProfile {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ProfileImportError.empty }

        if trimmed.lowercased().hasPrefix("vless://") {
            return try parseVlessURI(trimmed)
        }
        if trimmed.hasPrefix("{") {
            return try parseProfileJSON(trimmed)
        }
        if let range = trimmed.range(of: #"vless://\S+"#, options: .regularExpression) {
            var uri = String(trimmed[range])
            while let last = uri.last, "')\",".contains(last) || last.isNewline {
                uri.removeLast()
            }
            return try parseVlessURI(uri)
        }
        throw ProfileImportError.unrecognizedJSON
    }

    public static func parseVlessURI(_ uri: String) throws -> VlessProfile {
        guard let components = URLComponents(string: uri),
              components.scheme?.lowercased() == "vless"
        else {
            throw ProfileImportError.invalidURI
        }

        let uuid = components.user ?? ""
        var host = components.host ?? ""
        if host.hasPrefix("["), host.hasSuffix("]"), host.count > 2 {
            host = String(host.dropFirst().dropLast())
        }
        let port = components.port ?? 443
        guard !uuid.isEmpty, !host.isEmpty else { throw ProfileImportError.invalidURI }

        let query = queryItems(components)
        if let security = query["security"], !security.isEmpty, security.lowercased() != "reality" {
            throw ProfileImportError.unsupportedSecurity(security)
        }
        if let transport = query["type"] ?? query["network"],
           !transport.isEmpty,
           transport.lowercased() != "tcp" {
            throw ProfileImportError.unsupportedTransport(transport)
        }

        let name: String = {
            if let fragment = components.fragment, !fragment.isEmpty {
                return fragment.removingPercentEncoding ?? fragment
            }
            return "\(host):\(port)"
        }()

        let sni = query["sni"] ?? query["serverName"] ?? "www.cloudflare.com"
        let serverNames = sni
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let publicKey = query["pbk"] ?? query["publicKey"], !publicKey.isEmpty else {
            throw ProfileImportError.missingPublicKey
        }

        let spiderRaw = query["spx"] ?? query["spiderX"] ?? "/"
        let spiderX = spiderRaw.removingPercentEncoding ?? spiderRaw
        let reality = RealitySettings(
            publicKey: publicKey,
            shortId: query["sid"] ?? query["shortId"] ?? "",
            serverNames: serverNames.isEmpty ? ["www.cloudflare.com"] : serverNames,
            fingerprint: query["fp"] ?? query["fingerprint"] ?? "chrome",
            spiderX: spiderX,
            dest: query["dest"]
        )

        return VlessProfile(
            name: name,
            address: host,
            port: port,
            uuid: uuid,
            flow: query["flow"] ?? "xtls-rprx-vision",
            reality: reality
        )
    }

    public static func parseProfileJSON(_ text: String) throws -> VlessProfile {
        guard let data = text.data(using: .utf8) else { throw ProfileImportError.unrecognizedJSON }

        if let profile = try? JSONDecoder().decode(VlessProfile.self, from: data) {
            try rejectUnsupported(profile)
            return profile
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProfileImportError.unrecognizedJSON
        }

        if object["reality"] != nil || (object["address"] != nil && object["uuid"] != nil) {
            let profile = try decodeFlexibleProfile(object)
            try rejectUnsupported(profile)
            return profile
        }

        if (object["protocol"] as? String) == "vless"
            || ((object["settings"] as? [String: Any])?["vnext"] != nil) {
            let profile = try decodeXrayOutbound(object)
            try rejectUnsupported(profile)
            return profile
        }

        throw ProfileImportError.unrecognizedJSON
    }

    private static func rejectUnsupported(_ profile: VlessProfile) throws {
        if profile.security.lowercased() != "reality" {
            throw ProfileImportError.unsupportedSecurity(profile.security)
        }
        if profile.network.lowercased() != "tcp" {
            throw ProfileImportError.unsupportedTransport(profile.network)
        }
        if profile.reality.publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProfileImportError.missingPublicKey
        }
    }

    private static func queryItems(_ components: URLComponents) -> [String: String] {
        var out: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value {
                out[item.name] = value
            }
        }
        return out
    }

    private static func decodeFlexibleProfile(_ object: [String: Any]) throws -> VlessProfile {
        guard let address = object["address"] as? String,
              let uuid = object["uuid"] as? String
        else {
            throw ProfileImportError.unrecognizedJSON
        }
        let port = (object["port"] as? Int) ?? Int("\(object["port"] ?? 443)") ?? 443
        let name = (object["name"] as? String) ?? "\(address):\(port)"
        let realityObject = object["reality"] as? [String: Any] ?? [:]
        let publicKey = (realityObject["public_key"] as? String)
            ?? (realityObject["publicKey"] as? String)
            ?? ""
        guard !publicKey.isEmpty else { throw ProfileImportError.missingPublicKey }

        var serverNames: [String] = []
        if let names = realityObject["server_names"] as? [String] {
            serverNames = names
        } else if let sni = realityObject["server_names"] as? String {
            serverNames = sni.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else if let sni = realityObject["serverName"] as? String {
            serverNames = [sni]
        }

        let httpPort: Int?
        if object["http_port"] is NSNull {
            httpPort = nil
        } else if let value = object["http_port"] as? Int {
            httpPort = value
        } else {
            httpPort = 10809
        }

        return VlessProfile(
            id: (object["id"] as? String) ?? UUID().uuidString,
            name: name,
            address: address,
            port: port,
            uuid: uuid,
            flow: (object["flow"] as? String) ?? "xtls-rprx-vision",
            encryption: (object["encryption"] as? String) ?? "none",
            network: (object["network"] as? String) ?? "tcp",
            security: (object["security"] as? String) ?? "reality",
            reality: RealitySettings(
                publicKey: publicKey,
                shortId: (realityObject["short_id"] as? String) ?? (realityObject["shortId"] as? String) ?? "",
                serverNames: serverNames.isEmpty ? ["www.cloudflare.com"] : serverNames,
                fingerprint: (realityObject["fingerprint"] as? String) ?? "chrome",
                spiderX: (realityObject["spider_x"] as? String) ?? (realityObject["spiderX"] as? String) ?? "/",
                dest: realityObject["dest"] as? String
            ),
            socksPort: (object["socks_port"] as? Int) ?? 10808,
            httpPort: httpPort,
            notes: (object["notes"] as? String) ?? ""
        )
    }

    private static func decodeXrayOutbound(_ data: [String: Any]) throws -> VlessProfile {
        guard let settings = data["settings"] as? [String: Any],
              let vnextList = settings["vnext"] as? [[String: Any]],
              let vnext = vnextList.first,
              let users = vnext["users"] as? [[String: Any]],
              let user = users.first,
              let address = vnext["address"] as? String,
              let uuid = user["id"] as? String
        else {
            throw ProfileImportError.unrecognizedJSON
        }
        let port = (vnext["port"] as? Int) ?? 443
        let stream = data["streamSettings"] as? [String: Any] ?? [:]
        let security = (stream["security"] as? String) ?? "reality"
        let network = (stream["network"] as? String) ?? "tcp"
        let reality = stream["realitySettings"] as? [String: Any] ?? [:]
        let sni = (reality["serverName"] as? String) ?? "www.cloudflare.com"
        let publicKey = (reality["publicKey"] as? String) ?? ""
        guard !publicKey.isEmpty else { throw ProfileImportError.missingPublicKey }

        return VlessProfile(
            name: (data["tag"] as? String) ?? "\(address):\(port)",
            address: address,
            port: port,
            uuid: uuid,
            flow: (user["flow"] as? String) ?? "xtls-rprx-vision",
            encryption: (user["encryption"] as? String) ?? "none",
            network: network,
            security: security,
            reality: RealitySettings(
                publicKey: publicKey,
                shortId: (reality["shortId"] as? String) ?? "",
                serverNames: [sni],
                fingerprint: (reality["fingerprint"] as? String) ?? "chrome",
                spiderX: (reality["spiderX"] as? String) ?? "/"
            ),
            httpPort: nil
        )
    }
}
