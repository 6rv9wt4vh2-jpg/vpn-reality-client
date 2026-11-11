import Foundation

public enum SecretRedaction {
    /// Short display form. Does not reveal the middle of a credential.
    public static func preview(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        guard trimmed.count > 12 else { return String(repeating: "•", count: min(trimmed.count, 8)) }
        let start = trimmed.prefix(4)
        let end = trimmed.suffix(4)
        return "\(start)…\(end)"
    }

    /// Replace known secrets, then cap length so a core error cannot echo a config.
    public static func redact(_ text: String, secrets: [String], limit: Int = 280) -> String {
        var result = text
        for secret in secrets {
            let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 4 else { continue }
            result = result.replacingOccurrences(of: trimmed, with: "•••")
        }
        if result.count > limit {
            let end = result.index(result.startIndex, offsetBy: limit)
            result = String(result[..<end]) + "…"
        }
        return result
    }

    public static func secrets(in profile: VlessProfile) -> [String] {
        [
            profile.uuid,
            profile.reality.publicKey,
            profile.reality.shortId,
            profile.address,
        ]
    }
}
