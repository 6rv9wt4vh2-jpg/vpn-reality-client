import Foundation

enum ProfileImportError: LocalizedError {
    case empty
    case invalidURI
    case missingPublicKey
    case unrecognizedJSON
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .empty: return "Пустой ввод / Empty input"
        case .invalidURI: return "Некорректный vless:// URI"
        case .missingPublicKey: return "Нужен Reality public key (pbk)"
        case .unrecognizedJSON: return "Неизвестный JSON профиля"
        case .decoding(let e): return e.localizedDescription
        }
    }
}

enum ProfileImporter {
    /// Import vless:// URI or profile JSON (matches desktop `import_any`).
    static func importAny(_ text: String) throws -> VlessProfile {
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
            while uri.last.map({ "')\",\n".contains($0) }) == true {
                uri.removeLast()
            }
            return try parseVlessURI(uri)
        }
        throw ProfileImportError.unrecognizedJSON
    }

    static func parseVlessURI(_ uri: String) throws -> VlessProfile {
        guard let url = URL(string: uri), url.scheme?.lowercased() == "vless" else {
            throw ProfileImportError.invalidURI
        }

        let uuid = url.user ?? ""
        let host = url.host ?? ""
        let port = url.port ?? 443
        guard !uuid.isEmpty, !host.isEmpty else { throw ProfileImportError.invalidURI }

        let q = Self.queryItems(url)
        let name: String = {
            if let frag = url.fragment, !frag.isEmpty {
                return frag.removingPercentEncoding ?? frag
            }
            return "\(host):\(port)"
        }()

        let sni = q["sni"] ?? q["serverName"] ?? "www.cloudflare.com"
        let serverNames = sni.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let pbk = q["pbk"] ?? q["publicKey"], !pbk.isEmpty else {
            throw ProfileImportError.missingPublicKey
        }

        let spxRaw = q["spx"] ?? q["spiderX"] ?? "/"
        let spiderX = spxRaw.removingPercentEncoding ?? spxRaw

        let reality = RealitySettings(
            publicKey: pbk,
            shortId: q["sid"] ?? q["shortId"] ?? "",
            serverNames: serverNames,
            fingerprint: q["fp"] ?? q["fingerprint"] ?? "chrome",
            spiderX: spiderX,
            dest: q["dest"]
        )

        return VlessProfile(
            name: name,
            address: host,
            port: port,
            uuid: uuid,
            flow: q["flow"] ?? "xtls-rprx-vision",
            reality: reality
        )
    }

    static func parseProfileJSON(_ text: String) throws -> VlessProfile {
        guard let data = text.data(using: .utf8) else { throw ProfileImportError.unrecognizedJSON }

        // Our desktop profile shape
        if let profile = try? JSONDecoder().decode(VlessProfile.self, from: data) {
            return profile
        }

        // Flexible dictionary path (snake_case / nested reality / xray outbound)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProfileImportError.unrecognizedJSON
        }

        if obj["reality"] != nil || (obj["address"] != nil && obj["uuid"] != nil) {
            return try decodeFlexibleProfile(obj)
        }

        if (obj["protocol"] as? String) == "vless"
            || ((obj["settings"] as? [String: Any])?["vnext"] != nil) {
            return try decodeXrayOutbound(obj)
        }

        throw ProfileImportError.unrecognizedJSON
    }

    // MARK: - Helpers

    private static func queryItems(_ url: URL) -> [String: String] {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [:] }
        var out: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            if let v = item.value { out[item.name] = v }
        }
        return out
    }

    private static func decodeFlexibleProfile(_ obj: [String: Any]) throws -> VlessProfile {
        guard let address = obj["address"] as? String,
              let uuid = obj["uuid"] as? String else {
            throw ProfileImportError.unrecognizedJSON
        }
        let port = (obj["port"] as? Int) ?? Int("\(obj["port"] ?? 443)") ?? 443
        let name = (obj["name"] as? String) ?? "\(address):\(port)"
        let realityObj = obj["reality"] as? [String: Any] ?? [:]
        let publicKey = (realityObj["public_key"] as? String)
            ?? (realityObj["publicKey"] as? String)
            ?? ""
        guard !publicKey.isEmpty else { throw ProfileImportError.missingPublicKey }

        var serverNames: [String] = []
        if let arr = realityObj["server_names"] as? [String] {
            serverNames = arr
        } else if let s = realityObj["server_names"] as? String {
            serverNames = s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        let reality = RealitySettings(
            publicKey: publicKey,
            shortId: (realityObj["short_id"] as? String) ?? (realityObj["shortId"] as? String) ?? "",
            serverNames: serverNames.isEmpty ? ["www.cloudflare.com"] : serverNames,
            fingerprint: (realityObj["fingerprint"] as? String) ?? "chrome",
            spiderX: (realityObj["spider_x"] as? String) ?? (realityObj["spiderX"] as? String) ?? "/",
            dest: realityObj["dest"] as? String
        )

        return VlessProfile(
            id: (obj["id"] as? String) ?? UUID().uuidString,
            name: name,
            address: address,
            port: port,
            uuid: uuid,
            flow: (obj["flow"] as? String) ?? "xtls-rprx-vision",
            encryption: (obj["encryption"] as? String) ?? "none",
            network: (obj["network"] as? String) ?? "tcp",
            security: (obj["security"] as? String) ?? "reality",
            reality: reality,
            socksPort: (obj["socks_port"] as? Int) ?? 10808,
            httpPort: obj["http_port"] as? Int,
            notes: (obj["notes"] as? String) ?? ""
        )
    }

    private static func decodeXrayOutbound(_ data: [String: Any]) throws -> VlessProfile {
        guard let settings = data["settings"] as? [String: Any],
              let vnextArr = settings["vnext"] as? [[String: Any]],
              let vnext = vnextArr.first,
              let users = vnext["users"] as? [[String: Any]],
              let user = users.first,
              let address = vnext["address"] as? String,
              let uuid = user["id"] as? String else {
            throw ProfileImportError.unrecognizedJSON
        }
        let port = (vnext["port"] as? Int) ?? 443
        let stream = data["streamSettings"] as? [String: Any] ?? [:]
        let rs = stream["realitySettings"] as? [String: Any] ?? [:]
        let sni = (rs["serverName"] as? String) ?? "www.cloudflare.com"
        let publicKey = (rs["publicKey"] as? String) ?? ""
        guard !publicKey.isEmpty else { throw ProfileImportError.missingPublicKey }

        return VlessProfile(
            name: (data["tag"] as? String) ?? "\(address):\(port)",
            address: address,
            port: port,
            uuid: uuid,
            flow: (user["flow"] as? String) ?? "xtls-rprx-vision",
            reality: RealitySettings(
                publicKey: publicKey,
                shortId: (rs["shortId"] as? String) ?? "",
                serverNames: [sni],
                fingerprint: (rs["fingerprint"] as? String) ?? "chrome",
                spiderX: (rs["spiderX"] as? String) ?? "/"
            )
        )
    }
}
