import Foundation
import NetworkExtension
import VpnRealityCore

enum TunnelNetworkSettings {
    static func make(for profile: VlessProfile) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: profile.address)
        settings.mtu = NSNumber(value: XrayConfigBuilder.tunnelMTU)

        // 198.18.0.0/15 is the benchmarking range, outside the RFC1918 routes excluded below.
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        var excluded4 = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "169.254.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "224.0.0.0", subnetMask: "240.0.0.0"),
        ]
        if EndpointAddress.kind(profile.address) == .ipv4 {
            excluded4.append(NEIPv4Route(destinationAddress: profile.address, subnetMask: "255.255.255.255"))
        }
        ipv4.excludedRoutes = excluded4
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(addresses: ["fd66:1::2"], networkPrefixLengths: [NSNumber(value: 64)])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        var excluded6 = [
            NEIPv6Route(destinationAddress: "fe80::", networkPrefixLength: 10),
            NEIPv6Route(destinationAddress: "fc00::", networkPrefixLength: 7),
            NEIPv6Route(destinationAddress: "ff00::", networkPrefixLength: 8),
        ]
        if EndpointAddress.kind(profile.address) == .ipv6 {
            excluded6.append(NEIPv6Route(destinationAddress: profile.address, networkPrefixLength: 128))
        }
        ipv6.excludedRoutes = excluded6
        settings.ipv6Settings = ipv6

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns
        return settings
    }
}
