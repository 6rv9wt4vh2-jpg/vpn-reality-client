import SwiftUI
import VpnRealityCore

struct ProfileDetailView: View {
    let profile: VlessProfile
    var onUse: () -> Void

    @State private var revealSecrets = false

    var body: some View {
        List {
            Section("Сервер") {
                LabeledContent("Имя", value: profile.name)
                LabeledContent("Адрес", value: profile.endpointSummary)
                LabeledContent("SNI", value: profile.reality.serverNames.joined(separator: ", "))
                LabeledContent("Fingerprint", value: profile.reality.fingerprint)
                LabeledContent("Flow", value: profile.flow)
                LabeledContent("SpiderX", value: profile.reality.spiderX)
            }
            Section("Секретные поля") {
                Toggle("Показать полностью", isOn: $revealSecrets)
                secretRow("UUID", profile.uuid)
                secretRow("Public key", profile.reality.publicKey)
                secretRow("Short ID", profile.reality.shortId)
            }
            let issues = ProfileValidator.connectIssues(profile)
            if !issues.isEmpty {
                Section("Перед подключением") {
                    ForEach(issues, id: \.code) { issue in
                        Text(issue.message)
                            .foregroundStyle(.orange)
                    }
                }
            }
            Section {
                Button("Сделать активным", action: onUse)
            }
        }
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func secretRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: revealSecrets ? value : SecretRedaction.preview(value))
            .font(.body.monospaced())
    }
}
