import Foundation

/// Builds Xray JSON.
///
/// `proxyConfig` matches the desktop client (`vpn_client/xray_config.py`): SOCKS and optional HTTP
/// on localhost, VLESS + Reality, private networks via `geoip:private`.
/// `tunnelConfig` is the iOS packet-tunnel document: official Xray `tun` inbound, the utun fd in
/// `env["xray.tun.fd"]`, and literal private ranges so the extension does not need `geoip.dat`.
public enum XrayConfigBuilder {
    public static let tunnelMTU = 1280
    public static let directCIDRs = [
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "127.0.0.0/8",
        "169.254.0.0/16",
        "224.0.0.0/4",
        "255.255.255.255/32",
        "fc00::/7",
        "fe80::/10",
    ]

    public static func proxyConfig(_ profile: VlessProfile) -> [String: Any] {
        var inbounds: [[String: Any]] = [
            [
                "tag": "socks-in",
                "port": profile.socksPort,
                "listen": "127.0.0.1",
                "protocol": "socks",
                "settings": ["udp": true, "auth": "noauth"] as [String: Any],
                "sniffing": [
                    "enabled": true,
                    "destOverride": ["http", "tls", "quic"],
                ] as [String: Any],
            ],
        ]
        if let httpPort = profile.httpPort {
            inbounds.append([
                "tag": "http-in",
                "port": httpPort,
                "listen": "127.0.0.1",
                "protocol": "http",
                "settings": ["allowTransparent": false],
            ])
        }
        return wrap(profile: profile, inbounds: inbounds, environment: nil, directIPs: ["geoip:private"])
    }

    public static func tunnelConfig(profile: VlessProfile, tunFD: Int32) -> [String: Any] {
        let inbound: [String: Any] = [
            "tag": "tun-in",
            "port": 0,
            "protocol": "tun",
            "settings": ["mtu": tunnelMTU],
            "sniffing": [
                "enabled": true,
                "destOverride": ["http", "tls", "quic"],
            ] as [String: Any],
        ]
        return wrap(
            profile: profile,
            inbounds: [inbound],
            environment: ["xray.tun.fd": String(tunFD)],
            directIPs: directCIDRs
        )
    }

    public static func proxyJSON(_ profile: VlessProfile) throws -> String {
        try jsonString(proxyConfig(profile))
    }

    public static func tunnelJSON(profile: VlessProfile, tunFD: Int32) throws -> String {
        try jsonString(tunnelConfig(profile: profile, tunFD: tunFD))
    }

    private static func wrap(
        profile: VlessProfile,
        inbounds: [[String: Any]],
        environment: [String: String]?,
        directIPs: [String]
    ) -> [String: Any] {
        let reality = profile.reality
        let stream: [String: Any] = [
            "network": profile.network,
            "security": "reality",
            "realitySettings": [
                "show": false,
                "fingerprint": reality.fingerprint,
                "serverName": profile.primarySNI(),
                "publicKey": reality.publicKey,
                "shortId": reality.shortId,
                "spiderX": reality.spiderX,
            ] as [String: Any],
        ]
        let outbound: [String: Any] = [
            "tag": "proxy",
            "protocol": "vless",
            "settings": [
                "vnext": [[
                    "address": profile.address,
                    "port": profile.port,
                    "users": [[
                        "id": profile.uuid,
                        "encryption": profile.encryption,
                        "flow": profile.flow,
                    ] as [String: Any]],
                ] as [String: Any]],
            ] as [String: Any],
            "streamSettings": stream,
        ]
        var document: [String: Any] = [
            "log": ["loglevel": "warning"],
            "inbounds": inbounds,
            "outbounds": [
                outbound,
                ["tag": "direct", "protocol": "freedom", "settings": [:] as [String: Any]],
                ["tag": "block", "protocol": "blackhole", "settings": [:] as [String: Any]],
            ],
            "routing": [
                "domainStrategy": "AsIs",
                "rules": [[
                    "type": "field",
                    "outboundTag": "direct",
                    "ip": directIPs,
                ] as [String: Any]],
            ] as [String: Any],
        ]
        if let environment {
            document["env"] = environment
        }
        return document
    }

    public static func jsonString(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let text = String(data: data, encoding: .utf8) else {
            throw XrayConfigError.encoding
        }
        return text + "\n"
    }
}

public enum XrayConfigError: Error {
    case encoding
}
