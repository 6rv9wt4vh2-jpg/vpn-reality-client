import Foundation

/// Shared constants for App + Packet Tunnel Provider.
enum AppConstants {
    /// Replace TEAM_ID after creating an App Group in Apple Developer / Xcode.
    /// Format: group.<TEAM_ID>.vpnreality or a custom reverse-DNS you register.
    static let appGroupID = "group.com.example.vpnreality"

    static let profilesFileName = "profiles.json"
    static let activeProfileIDKey = "activeProfileID"
    static let tunnelProviderBundleID = "com.example.vpnreality.tunnel"

    /// Placeholder bundle IDs — change in Xcode Signing & Capabilities to match your Team.
    static let appBundleID = "com.example.vpnreality"
}
