import Foundation

/// JSON envelope for XTLS/libXray `Invoke` (API version 3).
/// The same shape is used by `CGoInvoke` on the Apple xcframework and the Linux `.so`.
public enum LibXrayInvoke {
    public static let apiVersion = 3
    public static let pinnedRelease = "v26.11.9"

    public enum Method {
        public static let runXray = "runXray"
        public static let stopXray = "stopXray"
        public static let testXray = "testXray"
        public static let xrayVersion = "xrayVersion"
        public static let getXrayState = "getXrayState"
    }

    public struct CallResult: Equatable, Sendable {
        public var success: Bool
        public var error: String
        public var version: String?
        public var running: Bool?

        public init(success: Bool, error: String, version: String? = nil, running: Bool? = nil) {
            self.success = success
            self.error = error
            self.version = version
            self.running = running
        }
    }

    public static func request(method: String, payload: [String: Any] = [:]) throws -> String {
        let object: [String: Any] = [
            "apiVersion": apiVersion,
            "method": method,
            "payload": payload,
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw LibXrayInvokeError.encoding
        }
        return text
    }

    public static func runRequest(xrayJSON: String) throws -> String {
        try request(method: Method.runXray, payload: ["xrayJson": xrayJSON])
    }

    public static func stopRequest() throws -> String {
        try request(method: Method.stopXray, payload: [:])
    }

    public static func versionRequest() throws -> String {
        try request(method: Method.xrayVersion, payload: [:])
    }

    public static func stateRequest() throws -> String {
        try request(method: Method.getXrayState, payload: [:])
    }

    public static func testRequest(xrayJSON: String) throws -> String {
        try request(method: Method.testXray, payload: ["xrayJson": xrayJSON])
    }

    public static func parse(_ text: String) throws -> CallResult {
        guard let data = text.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw LibXrayInvokeError.malformedResponse
        }
        let success = object["success"] as? Bool ?? false
        let error = object["error"] as? String ?? ""
        var version: String?
        var running: Bool?
        if let payload = object["data"] as? [String: Any] {
            version = payload["version"] as? String
            running = payload["running"] as? Bool
        }
        return CallResult(success: success, error: error, version: version, running: running)
    }
}

public enum LibXrayInvokeError: Error, Equatable {
    case encoding
    case malformedResponse
}
