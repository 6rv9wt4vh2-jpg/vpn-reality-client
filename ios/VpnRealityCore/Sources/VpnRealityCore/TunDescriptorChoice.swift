import Foundation

/// Picks the utun descriptor for this tunnel.
///
/// The packet-flow descriptor is specific to the current provider. A scan of
/// process file descriptors is only used when that descriptor is missing, and
/// only when exactly one new utun appeared after the tunnel settings were applied.
public enum TunDescriptorChoice {
    public static func choose(
        previous: Set<Int32>,
        current: Set<Int32>,
        packetFlowFD: Int32?
    ) -> Int32? {
        if let packetFlowFD, packetFlowFD > 2 {
            return packetFlowFD
        }
        let added = current.subtracting(previous).filter { $0 > 2 }
        guard added.count == 1 else { return nil }
        return added.first
    }
}

public enum UtunInterfaceName {
    public static func isUtun(_ name: String) -> Bool {
        guard name.hasPrefix("utun") else { return false }
        let suffix = name.dropFirst(4)
        return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
    }
}
