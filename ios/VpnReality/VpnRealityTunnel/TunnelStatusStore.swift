import Foundation
import VpnRealityCore

/// App Group file for non-secret tunnel state. Credentials stay in the Keychain.
struct TunnelStatusStore {
    func write(_ report: TunnelStatusReport) {
        guard let url = fileURL() else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(report) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func read() -> TunnelStatusReport? {
        guard let url = fileURL(), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TunnelStatusReport.self, from: data)
    }

    private func fileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)?
            .appendingPathComponent(AppConstants.statusFileName)
    }
}
