import Foundation

/// Non-secret status the packet tunnel writes for the app. Never store credentials here.
public struct TunnelStatusReport: Codable, Equatable, Sendable {
    public var state: String
    public var code: String
    public var message: String
    public var coreVersion: String?
    public var updatedAt: TimeInterval

    public init(
        state: String,
        code: String,
        message: String,
        coreVersion: String? = nil,
        updatedAt: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.state = state
        self.code = code
        self.message = message
        self.coreVersion = coreVersion
        self.updatedAt = updatedAt
    }

    public static func failed(code: String, message: String) -> TunnelStatusReport {
        TunnelStatusReport(state: "failed", code: code, message: message)
    }

    public static func running(coreVersion: String?) -> TunnelStatusReport {
        TunnelStatusReport(state: "running", code: "running", message: "Xray запущен", coreVersion: coreVersion)
    }

    public static func stopped() -> TunnelStatusReport {
        TunnelStatusReport(state: "stopped", code: "stopped", message: "Туннель остановлен")
    }
}
