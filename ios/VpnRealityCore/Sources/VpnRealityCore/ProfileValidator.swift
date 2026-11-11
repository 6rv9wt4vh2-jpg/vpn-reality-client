import Foundation

public struct ProfileIssue: Equatable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public enum ProfileValidator {
    /// Public key shipped in `examples/client-reality.json`. It is a placeholder, not a server.
    public static let samplePublicKey = "sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA"
    public static let sampleUUID = "00000000-0000-4000-8000-000000000000"

    public static func structuralIssues(_ profile: VlessProfile) -> [ProfileIssue] {
        var issues: [ProfileIssue] = []
        if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ProfileIssue(code: "name", message: "У профиля нет имени"))
        }
        if profile.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ProfileIssue(code: "address", message: "Не указан адрес сервера"))
        }
        if !(1 ... 65535).contains(profile.port) {
            issues.append(ProfileIssue(code: "port", message: "Порт должен быть от 1 до 65535"))
        }
        if !isUUID(profile.uuid) {
            issues.append(ProfileIssue(code: "uuid", message: "UUID пользователя VLESS записан неверно"))
        }
        if profile.encryption != "none" {
            issues.append(ProfileIssue(code: "encryption", message: "VLESS Reality использует encryption=none"))
        }
        if profile.network.lowercased() != "tcp" {
            issues.append(ProfileIssue(code: "network", message: "Туннель поддерживает только TCP"))
        }
        if profile.security.lowercased() != "reality" {
            issues.append(ProfileIssue(code: "security", message: "Нужен security=reality"))
        }
        if !isRealityPublicKey(profile.reality.publicKey) {
            issues.append(ProfileIssue(code: "public_key", message: "Reality public key должен быть ключом X25519 (base64)"))
        }
        if !isShortID(profile.reality.shortId) {
            issues.append(ProfileIssue(code: "short_id", message: "shortId — пустая строка или чётное число hex-символов (до 16 байт)"))
        }
        if profile.reality.serverNames.isEmpty || profile.reality.serverNames.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty || $0.contains(" ") }) {
            issues.append(ProfileIssue(code: "sni", message: "Нужен хотя бы один SNI без пробелов"))
        }
        if profile.reality.fingerprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ProfileIssue(code: "fingerprint", message: "Не задан uTLS fingerprint"))
        }
        if profile.reality.spiderX.isEmpty {
            issues.append(ProfileIssue(code: "spider_x", message: "spiderX не может быть пустым (обычно /)"))
        }
        if !(1 ... 65535).contains(profile.socksPort) {
            issues.append(ProfileIssue(code: "socks_port", message: "Некорректный SOCKS-порт"))
        }
        if let httpPort = profile.httpPort, !(1 ... 65535).contains(httpPort) {
            issues.append(ProfileIssue(code: "http_port", message: "Некорректный HTTP-порт"))
        }
        return issues
    }

    /// Placeholder fields from the repository examples. Import is allowed; connect is not.
    public static func placeholderIssues(_ profile: VlessProfile) -> [ProfileIssue] {
        var issues: [ProfileIssue] = []
        let address = profile.address.uppercased()
        if address.contains("YOUR_SERVER") || address.contains("EXAMPLE") {
            issues.append(ProfileIssue(code: "placeholder_address", message: "Адрес всё ещё плейсхолдер. Вставьте данные своего сервера."))
        }
        if profile.uuid.lowercased() == sampleUUID {
            issues.append(ProfileIssue(code: "placeholder_uuid", message: "UUID из примера. Подключение с ним не запускается."))
        }
        if profile.reality.publicKey == samplePublicKey {
            issues.append(ProfileIssue(code: "placeholder_key", message: "Public key из примера в репозитории. Нужен ключ вашего сервера."))
        }
        return issues
    }

    public static func connectIssues(_ profile: VlessProfile) -> [ProfileIssue] {
        structuralIssues(profile) + placeholderIssues(profile)
    }

    public static func isUUID(_ value: String) -> Bool {
        let pattern = #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    public static func isRealityPublicKey(_ value: String) -> Bool {
        let stripped = value.trimmingCharacters(in: CharacterSet(charactersIn: "="))
        guard stripped.count == 43 else { return false }
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_+/"
        let allowed = CharacterSet(charactersIn: alphabet)
        return stripped.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    public static func isShortID(_ value: String) -> Bool {
        if value.isEmpty { return true }
        guard value.count <= 32, value.count.isMultiple(of: 2) else { return false }
        return value.allSatisfy(\.isHexDigit)
    }
}
