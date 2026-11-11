import Foundation

/// Identifiers shared by the app and the packet tunnel.
/// Replace the placeholder team values in Xcode before installing on a device.
enum AppConstants {
    static let appGroupID = "group.com.example.vpnreality"
    static let tunnelProviderBundleID = "com.example.vpnreality.tunnel"
    static let appBundleID = "com.example.vpnreality"
    static let keychainService = "vpnreality.profiles"
    static let keychainAccount = "profiles-store"
    static let statusFileName = "tunnel-status.json"
    static let infoKeychainAccessGroup = "VPNKeychainAccessGroup"
}
