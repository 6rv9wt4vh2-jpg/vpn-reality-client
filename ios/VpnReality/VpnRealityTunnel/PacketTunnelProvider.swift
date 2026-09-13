import NetworkExtension
import os.log

/// Packet Tunnel Provider — App ↔ Shared models ↔ this extension.
///
/// Integration status:
/// - ✅ Reads active profile / runtime xray JSON from App Group
/// - ✅ Applies basic NEPacketTunnelNetworkSettings (utun)
/// - ⚠️ Does NOT yet run a real Xray/sing-box core (stub)
///
/// To make VPN actually proxy traffic on a device:
/// 1. Link LibXray.xcframework or SwiftyXrayKit / Libbox (see ../ThirdParty/README.md)
/// 2. Paid Apple Developer + Network Extension entitlement + provisioning
/// 3. Replace `startCoreIfAvailable` stub with real start/stop
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let log = Logger(subsystem: AppConstants.appBundleID, category: "tunnel")
    private var coreHandle: TunnelCoreHandle?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        log.info("startTunnel options=\(String(describing: options), privacy: .public)")

        guard let profile = AppGroupStore.shared.activeProfile() else {
            completionHandler(TunnelError.noProfile)
            return
        }

        do {
            let json = try AppGroupStore.shared.readRuntimeConfigJSON()
                ?? XrayConfigBuilder.jsonString(profile: profile, forTunnel: true)
            try AppGroupStore.shared.writeRuntimeConfigJSON(json)
        } catch {
            completionHandler(error)
            return
        }

        let settings = makeNetworkSettings(for: profile)
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else {
                completionHandler(error)
                return
            }
            if let error {
                completionHandler(error)
                return
            }
            do {
                try self.startCoreIfAvailable(profile: profile)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        log.info("stopTunnel reason=\(String(describing: reason), privacy: .public)")
        coreHandle?.stop()
        coreHandle = nil
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Optional control channel App → Extension
        let reply = #"{"ok":true,"core":"\#(coreHandle == nil ? "stub" : "linked")"}"#
        completionHandler?(reply.data(using: .utf8))
    }

    // MARK: - Network settings

    private func makeNetworkSettings(for profile: VlessProfile) -> NEPacketTunnelNetworkSettings {
        // Full-tunnel style defaults; refine after core is linked (split tunnel / DNS).
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: profile.address)
        settings.mtu = 1500

        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        // Keep LAN reachable when excludeLocalNetworks is set on the protocol.
        ipv4.excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
        ]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns.matchDomains = [""] // capture all DNS when core is live
        settings.dnsSettings = dns

        return settings
    }

    // MARK: - Core bridge (stub → LibXray / sing-box)

    private func startCoreIfAvailable(profile: VlessProfile) throws {
        #if canImport(LibXray)
        // Example when LibXray.xcframework is linked (API names vary by build):
        // let dir = FileManager.default.containerURL(...)!
        // let conf = dir.appendingPathComponent("runtime-config.json").path
        // LibXrayRunXray(dir.path, conf, /* memory limit */)
        // coreHandle = LibXrayHandle()
        // return
        #endif

        #if canImport(SwiftyXrayKit)
        // Preferred path on Apple platforms — see ThirdParty/README.md
        // let bridge = XrayBridge(packetFlow: packetFlow)
        // try bridge.start(config: .json(json), dataDir: geoDir, finalConfigPath: finalURL)
        // coreHandle = SwiftyBridgeHandle(bridge)
        // return
        #endif

        #if canImport(Libbox)
        // Alternative: sing-box Libbox + PlatformInterface OpenTun
        #endif

        // Honest stub: tunnel interface comes up, but packets are not proxied
        // until a real core is linked. Documented in ios/README.md.
        log.warning("No Xray/sing-box core linked — tunnel stub only. Profile=\(profile.name, privacy: .public)")
        coreHandle = StubCoreHandle()
        // Do not throw: allows UI/status plumbing & provisioning tests without core.
    }
}

// MARK: - Core handle abstraction

protocol TunnelCoreHandle: AnyObject {
    func stop()
}

final class StubCoreHandle: TunnelCoreHandle {
    func stop() {}
}

enum TunnelError: LocalizedError {
    case noProfile
    case coreNotLinked

    var errorDescription: String? {
        switch self {
        case .noProfile:
            return "Нет активного профиля в App Group"
        case .coreNotLinked:
            return "LibXray/sing-box не подключён — см. ios/VpnReality/ThirdParty/README.md"
        }
    }
}
