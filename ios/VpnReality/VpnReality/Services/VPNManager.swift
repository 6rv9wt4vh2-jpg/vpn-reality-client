import Foundation
import NetworkExtension
import Combine
import SwiftUI

@MainActor
final class VPNManager: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var isBusy = false
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    var isConnected: Bool {
        status == .connected || status == .connecting || status == .reasserting
    }

    var statusTextRU: String {
        switch status {
        case .invalid: return "Не настроено"
        case .disconnected: return "Отключено"
        case .connecting: return "Подключение…"
        case .connected: return "Подключено"
        case .reasserting: return "Переподключение…"
        case .disconnecting: return "Отключение…"
        @unknown default: return "Неизвестно"
        }
    }

    var statusColor: Color {
        switch status {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        case .disconnecting: return .orange
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
                if let session = note.object as? NEVPNConnection {
                    self?.status = session.status
                }
            }
        }
        Task { await loadManager() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func refreshStatus() {
        status = manager?.connection.status ?? .invalid
    }

    func connect(profileName: String) async throws {
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        let mgr = try await ensureManager(displayName: profileName)
        // iOS will show the system VPN permission sheet on first start.
        try mgr.connection.startVPNTunnel(options: [
            "profileName": profileName as NSString
        ])
        status = mgr.connection.status
    }

    func disconnect() async {
        isBusy = true
        defer { isBusy = false }
        manager?.connection.stopVPNTunnel()
        status = manager?.connection.status ?? .disconnected
    }

    private func loadManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = managers.first
            status = manager?.connection.status ?? .invalid
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func ensureManager(displayName: String) async throws -> NETunnelProviderManager {
        if let manager { return manager }

        let mgr = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppConstants.tunnelProviderBundleID
        proto.serverAddress = displayName
        // Credentials / config live in App Group; protocol only needs provider id.
        proto.excludeLocalNetworks = true

        mgr.protocolConfiguration = proto
        mgr.localizedDescription = "VPN Reality (\(displayName))"
        mgr.isEnabled = true

        try await mgr.saveToPreferences()
        try await mgr.loadFromPreferences()
        self.manager = mgr
        return mgr
    }
}
