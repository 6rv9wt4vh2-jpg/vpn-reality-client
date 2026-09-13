import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var profiles: ProfileStoreViewModel
    @EnvironmentObject private var vpn: VPNManager
    @State private var showImport = false
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            List {
                statusSection
                profilesSection
                aboutSection
            }
            .navigationTitle("VPN Reality")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showImport = true
                    } label: {
                        Label("Импорт", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await toggleVPN() }
                    } label: {
                        Label(
                            vpn.isConnected ? "Отключить" : "Подключить",
                            systemImage: vpn.isConnected ? "network.slash" : "network"
                        )
                    }
                    .disabled(profiles.activeProfile == nil && !vpn.isConnected)
                }
            }
            .sheet(isPresented: $showImport) {
                ImportProfileView { profile in
                    do {
                        try profiles.upsert(profile)
                        showImport = false
                    } catch {
                        alertMessage = error.localizedDescription
                    }
                }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var statusSection: some View {
        Section("Статус") {
            HStack {
                Circle()
                    .fill(vpn.statusColor)
                    .frame(width: 10, height: 10)
                Text(vpn.statusTextRU)
                Spacer()
                if vpn.isBusy {
                    ProgressView()
                }
            }
            if let name = profiles.activeProfile?.name {
                Text("Профиль: \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Нет активного профиля — импортируйте JSON или vless://")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let note = vpn.lastError, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var profilesSection: some View {
        Section("Профили") {
            if profiles.items.isEmpty {
                Text("Список пуст. Добавьте `examples/client-reality.json` или URI.")
                    .foregroundStyle(.secondary)
            }
            ForEach(profiles.items) { profile in
                Button {
                    try? profiles.setActive(id: profile.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name).font(.headline)
                            Text(profile.endpointSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("SNI: \(profile.primarySNI()) · fp: \(profile.reality.fingerprint)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if profiles.activeId == profile.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        try? profiles.delete(id: profile.id)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("О приложении") {
            Text("VLESS + Reality · каркас iOS Network Extension")
                .font(.footnote)
            Text("Без связанного LibXray/sing-box и оплаченного Apple Developer VPN на устройстве не заработает.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleVPN() async {
        do {
            if vpn.isConnected {
                await vpn.disconnect()
            } else {
                guard let profile = profiles.activeProfile else {
                    alertMessage = "Сначала выберите профиль"
                    return
                }
                let json = try XrayConfigBuilder.jsonString(profile: profile, forTunnel: true)
                try AppGroupStore.shared.writeRuntimeConfigJSON(json)
                try profiles.setActive(id: profile.id)
                try await vpn.connect(profileName: profile.name)
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
