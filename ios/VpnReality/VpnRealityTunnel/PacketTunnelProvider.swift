import NetworkExtension
import os.log
import VpnRealityCore

/// Packet tunnel for VLESS + Reality.
///
/// Traffic path, once libXray is linked and the device is signed for Network Extension:
/// NEPacketTunnelFlow utun fd → Xray `tun` inbound → VLESS + Reality outbound.
/// `startTunnel` calls the system completion with nil only after `runXray` reports success.
/// A missing core, profile, or utun fd fails the tunnel instead of leaving a black hole.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let log = Logger(subsystem: AppConstants.appBundleID, category: "tunnel")
    private let statusStore = TunnelStatusStore()
    private var coreRunning = false

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        log.info("startTunnel")
        let previousUtuns = UtunFileDescriptor.scan()

        do {
            guard LibXrayRuntime.isLinked else { throw TunnelFailure.coreNotLinked }
            guard let profile = try ProfileVault.shared.activeProfile() else {
                throw TunnelFailure.noProfile
            }
            let issues = ProfileValidator.connectIssues(profile)
            if let first = issues.first {
                throw TunnelFailure.invalidProfile(first.message)
            }
            let settings = TunnelNetworkSettings.make(for: profile)
            setTunnelNetworkSettings(settings) { [weak self] error in
                guard let self else {
                    completionHandler(error ?? TunnelFailure.coreRejected("Расширение освобождено до старта"))
                    return
                }
                if let error {
                    self.fail(error, profile: profile, completion: completionHandler)
                    return
                }
                do {
                    let fd = try UtunFileDescriptor.resolve(packetFlow: self.packetFlow, previous: previousUtuns)
                    let config = try XrayConfigBuilder.tunnelJSON(profile: profile, tunFD: fd)
                    let version = try LibXrayRuntime.run(xrayJSON: config)
                    self.coreRunning = true
                    self.statusStore.write(.running(coreVersion: version))
                    self.log.info("Xray tunnel is up")
                    completionHandler(nil)
                } catch {
                    self.fail(error, profile: profile, completion: completionHandler)
                }
            }
        } catch {
            fail(error, profile: nil, completion: completionHandler)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        log.info("stopTunnel reason=\(reason.rawValue, privacy: .public)")
        if coreRunning {
            LibXrayRuntime.stop()
            coreRunning = false
        }
        statusStore.write(.stopped())
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let report = statusStore.read()
        let payload: [String: Any] = [
            "ok": true,
            "linked": LibXrayRuntime.isLinked,
            "running": coreRunning,
            "state": report?.state ?? "unknown",
            "code": report?.code ?? "",
            "coreVersion": report?.coreVersion ?? "",
        ]
        let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        completionHandler?(data)
    }

    private func fail(_ error: Error, profile: VlessProfile?, completion: @escaping (Error?) -> Void) {
        if coreRunning {
            LibXrayRuntime.stop()
            coreRunning = false
        }
        let failure = TunnelFailure.wrap(error, profile: profile)
        statusStore.write(.failed(code: failure.code, message: failure.localizedDescription))
        log.error("tunnel failed code=\(failure.code, privacy: .public)")
        completion(failure)
    }
}

enum TunnelFailure: LocalizedError {
    case coreNotLinked
    case noProfile
    case invalidProfile(String)
    case tunFdUnavailable
    case coreRejected(String)
    case keychain(String)

    var code: String {
        switch self {
        case .coreNotLinked: return "coreNotLinked"
        case .noProfile: return "noProfile"
        case .invalidProfile: return "invalidProfile"
        case .tunFdUnavailable: return "tunFdUnavailable"
        case .coreRejected: return "coreRejected"
        case .keychain: return "keychain"
        }
    }

    var errorDescription: String? {
        switch self {
        case .coreNotLinked:
            return "В сборку не вшит libXray \(LibXrayInvoke.pinnedRelease). Туннель не включается. На Mac запустите ios/VpnReality/ThirdParty/fetch-libxray.sh и пересоберите расширение."
        case .noProfile:
            return "В Keychain нет активного профиля. Импортируйте свой VLESS + Reality и проверьте общий keychain-access-group."
        case .invalidProfile(let message):
            return message
        case .tunFdUnavailable:
            return "Network Extension не отдал файловый дескриптор utun. Туннель остановлен, трафик не перехватывался."
        case .coreRejected(let message):
            return "Xray не запустил туннель: \(message)"
        case .keychain(let message):
            return message
        }
    }

    static func wrap(_ error: Error, profile: VlessProfile?) -> TunnelFailure {
        if let failure = error as? TunnelFailure {
            if case .coreRejected(let message) = failure {
                return .coreRejected(redact(message, profile: profile))
            }
            return failure
        }
        if let vault = error as? ProfileVaultError {
            return .keychain(vault.localizedDescription)
        }
        return .coreRejected(redact(error.localizedDescription, profile: profile))
    }

    private static func redact(_ message: String, profile: VlessProfile?) -> String {
        guard let profile else { return SecretRedaction.redact(message, secrets: []) }
        return SecretRedaction.redact(message, secrets: SecretRedaction.secrets(in: profile))
    }
}
