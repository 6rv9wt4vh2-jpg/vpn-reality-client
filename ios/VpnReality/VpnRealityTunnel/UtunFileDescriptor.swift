import Darwin
import Foundation
import NetworkExtension

/// Finds the utun descriptor Network Extension created for this provider.
///
/// Xray-core's iOS TUN inbound reads `env["xray.tun.fd"]` (see Xray `proxy/tun` iOS support).
/// The descriptor owned by `packetFlow` is preferred. The getsockopt scan from the Xray
/// documentation is the fallback, and only when it finds exactly one new `utun`.
enum UtunFileDescriptor {
    /// Darwin `SYSPROTO_CONTROL` / `UTUN_OPT_IFNAME`.
    private static let sysprotoControl: Int32 = 2
    private static let utunOptIfname: Int32 = 2

    static func resolve(packetFlow: NEPacketTunnelFlow, previous: Set<Int32>) throws -> Int32 {
        let packetFlowFD = fileDescriptor(of: packetFlow)
        let current = scan()
        guard let chosen = TunDescriptorChoice.choose(
            previous: previous,
            current: current,
            packetFlowFD: packetFlowFD
        ) else {
            throw TunnelFailure.tunFdUnavailable
        }
        return chosen
    }

    static func scan() -> Set<Int32> {
        var found: Set<Int32> = []
        for fd: Int32 in 0 ... 1024 {
            if let name = interfaceName(fd: fd), UtunInterfaceName.isUtun(name) {
                found.insert(fd)
            }
        }
        return found
    }

    private static func fileDescriptor(of packetFlow: NEPacketTunnelFlow) -> Int32? {
        let value = packetFlow.value(forKeyPath: "socket.fileDescriptor")
        if let number = value as? Int32 {
            return number
        }
        if let number = value as? NSNumber {
            return number.int32Value
        }
        return nil
    }

    private static func interfaceName(fd: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 32)
        var length = socklen_t(buffer.count)
        let result = buffer.withUnsafeMutableBytes { raw -> Int32 in
            guard let base = raw.baseAddress else { return -1 }
            return getsockopt(fd, sysprotoControl, utunOptIfname, base, &length)
        }
        guard result == 0 else { return nil }
        return String(cString: buffer)
    }
}
