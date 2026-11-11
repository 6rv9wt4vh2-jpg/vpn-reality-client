import Foundation

public enum EndpointAddressKind: Equatable, Sendable {
    case ipv4
    case ipv6
    case hostname
}

public enum EndpointAddress {
    public static func kind(_ host: String) -> EndpointAddressKind {
        if isIPv4(host) { return .ipv4 }
        if isIPv6(host) { return .ipv6 }
        return .hostname
    }

    public static func isIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part), (0 ... 255).contains(value) else { return false }
            if part.count > 1, part.first == "0" { return false }
            return part.allSatisfy(\.isNumber)
        }
    }

    public static func isIPv6(_ host: String) -> Bool {
        let value = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard value.contains(":"), !value.contains(".") else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        let groups = value.split(separator: ":", omittingEmptySubsequences: false)
        guard groups.count >= 3, groups.count <= 8 else { return false }
        let empty = groups.filter(\.isEmpty).count
        if value.contains(":::") { return false }
        if !value.contains("::"), empty != 0 { return false }
        if value.contains("::"), empty > 2 { return false }
        return groups.allSatisfy { $0.isEmpty || ($0.count <= 4 && $0.allSatisfy(\.isHexDigit)) }
    }
}
