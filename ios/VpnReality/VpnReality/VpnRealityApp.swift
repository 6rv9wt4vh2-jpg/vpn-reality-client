import SwiftUI

@main
struct VpnRealityApp: App {
    @StateObject private var profileStore = ProfileStoreViewModel()
    @StateObject private var vpn = VPNManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileStore)
                .environmentObject(vpn)
                .onAppear {
                    profileStore.reload()
                    vpn.refreshStatus()
                }
        }
    }
}
