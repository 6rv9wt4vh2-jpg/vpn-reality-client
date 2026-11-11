import SwiftUI
import VpnRealityCore

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
                requirementsSection
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
                    Button("Обновить") {
                        profiles.reload()
                        Task { await vpn.reload() }
                    }
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
            .refreshable {
                profiles.reload()
                await vpn.reload()
            }
        }
    }

    private var statusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(vpn.statusColor)
                        .frame(width: 12, height: 12)
                    Text(vpn.statusText)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    if vpn.isBusy {
                        ProgressView()
                    }
                }
                if let profile = profiles.activeProfile {
                    Text(profile.name)
                        .font(.headline)
                    Text("\(profile.endpointSummary) · SNI \(profile.primarySNI())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Нет активного профиля. Импортируйте свою ссылку vless:// или JSON.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let error = vpn.lastError ?? profiles.lastError, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                Button {
                    Task { await toggle() }
                } label: {
                    Text(vpn.status == .connected || vpn.status == .connecting ? "Отключить" : "Подключить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(profiles.activeProfile == nil && vpn.status != .connected && vpn.status != .connecting)
            }
            .padding(.vertical, 4)
        }
    }

    private var profilesSection: some View {
        Section("Профили") {
            if profiles.items.isEmpty {
                Text("Список пуст. Пример в репозитории — только образец полей, им подключаться нельзя.")
                    .foregroundStyle(.secondary)
            }
            ForEach(profiles.items) { profile in
                NavigationLink {
                    ProfileDetailView(profile: profile) {
                        do {
                            try profiles.setActive(id: profile.id)
                        } catch {
                            alertMessage = error.localizedDescription
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name).font(.headline)
                            Text(profile.endpointSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let issue = ProfileValidator.connectIssues(profile).first {
                                Text(issue.message)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .lineLimit(2)
                            }
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
                        do {
                            try profiles.delete(id: profile.id)
                        } catch {
                            alertMessage = error.localizedDescription
                        }
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                    Button {
                        do {
                            try profiles.setActive(id: profile.id)
                        } catch {
                            alertMessage = error.localizedDescription
                        }
                    } label: {
                        Label("Выбрать", systemImage: "checkmark")
                    }
                    .tint(.blue)
                }
            }
        }
    }

    private var requirementsSection: some View {
        Section("Как это устроено") {
            Text("Подключение поднимает системный Packet Tunnel и передаёт его utun в Xray-core (XTLS/libXray) с исходящим VLESS + Reality.")
                .font(.footnote)
            Text("Если ядро не вшито в сборку, профиль пустой или система не выдала VPN, туннель завершается ошибкой и не остаётся «подключённым».")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Нужны Mac, Xcode, платная программа Apple Developer, подпись Network Extension и libXray \(LibXrayInvoke.pinnedRelease). Этот экран сам по себе трафик не проксирует.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func toggle() async {
        if vpn.status == .connected || vpn.status == .connecting || vpn.status == .reasserting {
            await vpn.disconnect()
            return
        }
        guard let profile = profiles.activeProfile else {
            alertMessage = "Сначала выберите профиль"
            return
        }
        do {
            try profiles.setActive(id: profile.id)
            try await vpn.connect(profile: profile)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
