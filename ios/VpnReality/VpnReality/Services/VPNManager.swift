import Combine
import Foundation
import NetworkExtension
import SwiftUI
import VpnRealityCore

@MainActor
final class VPNManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var isBusy = false
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?
    private let statusStore = TunnelStatusStore()

    var statusText: String {
        switch status {
        case .invalid: return "Не настроено"
        case .disconnected: return "Отключено"
        case .connecting: return "Подключение…"
        case .connected: return "Подключено"
        case .reasserting: return "Переподключение…"
        case .disconnecting: return "Отключение…"
        @unknown default: return "Неизвестное состояние"
        }
    }

    var statusColor: Color {
        switch status {
        case .connected: return .green
        case .connecting, .reasserting, .disconnecting: return .orange
        default: return .secondary
        }
    }

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                if let connection = note.object as? NEVPNConnection {
                    self.status = connection.status
                }
                self.absorbProviderStatus()
            }
        }
        Task { await reload() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reload() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = managers.first { manager in
                let proto = manager.protocolConfiguration as? NETunnelProviderProtocol
                return proto?.providerBundleIdentifier == AppConstants.tunnelProviderBundleID
            } ?? managers.first
            status = manager?.connection.status ?? .disconnected
            absorbProviderStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func connect(profile: VlessProfile) async throws {
        let issues = ProfileValidator.connectIssues(profile)
        if let first = issues.first {
            lastError = first.message
            throw TunnelClientError.message(first.message)
        }
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        let manager = try await ensureManager(profile: profile)
        do {
            try manager.connection.startVPNTunnel(options: [
                "profileId": profile.id as NSString,
            ])
        } catch {
            absorbProviderStatus()
            let message = lastError ?? error.localizedDescription
            lastError = message
            throw TunnelClientError.message(message)
        }
        status = manager.connection.status
    }

    func disconnect() async {
        isBusy = true
        defer { isBusy = false }
        manager?.connection.stopVPNTunnel()
        status = manager?.connection.status ?? .disconnected
    }

    private func absorbProviderStatus() {
        guard let report = statusStore.read() else { return }
        guard report.state == "failed" else {
            if status == .connected {
                lastError = nil
            }
            return
        }
        if status == .connected || status == .connecting { return }
        lastError = report.message
    }

    private func ensureManager(profile: VlessProfile) async throws -> NETunnelProviderManager {
        let manager = self.manager ?? NETunnelProviderManager()
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppConstants.tunnelProviderBundleID
        proto.serverAddress = profile.address
        proto.excludeLocalNetworks = true
        proto.providerConfiguration = ["profileId": profile.id]
        proto.disconnectOnSleep = false

        manager.protocolConfiguration = proto
        manager.localizedDescription = "VPN Reality"
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        self.manager = manager
        return manager
    }
}

enum TunnelClientError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
