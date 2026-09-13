import Foundation

/// Builds xray-core JSON from a VlessProfile (parity with desktop `xray_config.py`).
/// On iOS the Packet Tunnel typically uses a TUN inbound instead of SOCKS;
/// `buildTunnelXrayConfig` switches inbounds accordingly once a real core is linked.
enum XrayConfigBuilder {
    static func buildProxyConfig(profile: VlessProfile) -> [String: Any] {
        var inbounds: [[String: Any]] = [
            [
                "tag": "socks-in",
                "port": profile.socksPort,
                "listen": "127.0.0.1",
                "protocol": "socks",
                "settings": ["udp": true, "auth": "noauth"],
                "sniffing": [
                    "enabled": true,
                    "destOverride": ["http", "tls", "quic"],
                ],
            ]
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

        return wrap(profile: profile, inbounds: inbounds)
    }

    /// Config intended for Network Extension + LibXray / SwiftyXrayKit TUN bridge.
    /// Uses dokodemo-door / socks on localhost as a safe default until TUN inbound
    /// is wired by the linked core (see ThirdParty/README.md).
    static func buildTunnelXrayConfig(profile: VlessProfile) -> [String: Any] {
        // Many LibXray Apple bridges inject/replace the TUN inbound themselves.
        // We emit a VLESS+Reality outbound identical to desktop, with a minimal
        // socks inbound that the bridge may rewrite.
        return buildProxyConfig(profile: profile)
    }

    static func jsonString(profile: VlessProfile, forTunnel: Bool = true, pretty: Bool = true) throws -> String {
        let cfg = forTunnel ? buildTunnelXrayConfig(profile: profile) : buildProxyConfig(profile: profile)
        let data = try JSONSerialization.data(
            withJSONObject: cfg,
            options: pretty ? [.prettyPrinted, .sortedKeys] : []
        )
        guard let s = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "XrayConfigBuilder", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "UTF-8 encode failed",
            ])
        }
        return s
    }

    private static func wrap(profile: VlessProfile, inbounds: [[String: Any]]) -> [String: Any] {
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
            ],
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
                    ]],
                ]],
            ],
            "streamSettings": stream,
        ]

        return [
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
                    "ip": ["geoip:private"],
                ]],
            ],
        ]
    }
}
