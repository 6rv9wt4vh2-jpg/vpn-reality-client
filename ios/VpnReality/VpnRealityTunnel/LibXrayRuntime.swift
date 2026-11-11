import Foundation
import VpnRealityCore

/// Calls the pinned XTLS/libXray C API (`CGoInvoke` / `CGoFree`) when the
/// official xcframework is linked. Without it, start fails closed.
enum LibXrayRuntime {
    private static let lock = NSLock()

    static var isLinked: Bool {
        #if LIBXRAY_ENABLED
        return true
        #else
        return false
        #endif
    }

    static func run(xrayJSON: String) throws -> String? {
        let response = try invoke(try LibXrayInvoke.runRequest(xrayJSON: xrayJSON))
        guard response.success else {
            throw TunnelFailure.coreRejected(response.error.isEmpty ? "runXray вернул ошибку" : response.error)
        }
        let state = try invoke(try LibXrayInvoke.stateRequest())
        guard state.success, state.running == true else {
            let detail = state.error.isEmpty ? "Xray не перешёл в состояние running" : state.error
            throw TunnelFailure.coreRejected(detail)
        }
        let version = try invoke(try LibXrayInvoke.versionRequest())
        return version.version
    }

    static func stop() {
        guard isLinked else { return }
        lock.lock()
        defer { lock.unlock() }
        guard let request = try? LibXrayInvoke.stopRequest() else { return }
        _ = try? invokeUnlocked(request)
    }

    private static func invoke(_ request: String) throws -> LibXrayInvoke.CallResult {
        lock.lock()
        defer { lock.unlock() }
        return try invokeUnlocked(request)
    }

    private static func invokeUnlocked(_ request: String) throws -> LibXrayInvoke.CallResult {
        #if LIBXRAY_ENABLED
        let bytes = Array(request.utf8CString)
        let response: String? = bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return nil }
            let pointer = UnsafeMutablePointer(mutating: base)
            guard let raw = CGoInvoke(pointer) else { return nil }
            defer { CGoFree(raw) }
            return String(cString: raw)
        }
        guard let response else {
            throw TunnelFailure.coreRejected("CGoInvoke не вернул ответ")
        }
        return try LibXrayInvoke.parse(response)
        #else
        _ = request
        throw TunnelFailure.coreNotLinked
        #endif
    }
}
