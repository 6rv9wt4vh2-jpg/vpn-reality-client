import SwiftUI
import VpnRealityCore

struct ImportProfileView: View {
    var onImport: (VlessProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var errorText: String?
    @State private var preview: VlessProfile?
    @State private var issues: [ProfileIssue] = []
    @State private var revealSecrets = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("JSON или vless://")
                } footer: {
                    Text("Формат тот же, что у десктопного vpn-reality import: examples/client-reality.json и ссылка vless:// с pbk, sid, sni, fp, spx.")
                }

                if let preview {
                    Section("Разбор") {
                        LabeledContent("Имя", value: preview.name)
                        LabeledContent("Адрес", value: preview.endpointSummary)
                        LabeledContent("SNI", value: preview.reality.serverNames.joined(separator: ", "))
                        LabeledContent("UUID", value: revealSecrets ? preview.uuid : SecretRedaction.preview(preview.uuid))
                        LabeledContent("Public key", value: revealSecrets ? preview.reality.publicKey : SecretRedaction.preview(preview.reality.publicKey))
                        LabeledContent("Short ID", value: revealSecrets ? preview.reality.shortId : SecretRedaction.preview(preview.reality.shortId))
                        Toggle("Показать секреты", isOn: $revealSecrets)
                    }
                }

                if !issues.isEmpty {
                    Section("Замечания") {
                        ForEach(issues, id: \.code) { issue in
                            Text(issue.message).foregroundStyle(.orange)
                        }
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Разобрать", action: parse)
                    Button("Импортировать") {
                        parse()
                        if let preview, errorText == nil {
                            onImport(preview)
                        }
                    }
                    .disabled(preview == nil)
                    Button("Вставить пример JSON") {
                        text = SampleData.clientRealityJSON
                        parse()
                    }
                }
            }
            .navigationTitle("Импорт")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private func parse() {
        do {
            let profile = try ProfileImporter.importAny(text)
            preview = profile
            issues = ProfileValidator.connectIssues(profile)
            errorText = nil
        } catch {
            preview = nil
            issues = []
            errorText = error.localizedDescription
        }
    }
}

enum SampleData {
    static let clientRealityJSON = """
    {
      "name": "example-reality",
      "address": "YOUR_SERVER_IP_OR_DOMAIN",
      "port": 443,
      "uuid": "00000000-0000-4000-8000-000000000000",
      "flow": "xtls-rprx-vision",
      "encryption": "none",
      "network": "tcp",
      "security": "reality",
      "socks_port": 10808,
      "http_port": 10809,
      "notes": "Placeholder — replace with YOUR values.",
      "reality": {
        "public_key": "sCMyd0MxQEessoya6gphVLM9lOX9-5tuWBMRlskeuwA",
        "short_id": "abcd1234",
        "server_names": ["www.cloudflare.com", "www.microsoft.com"],
        "fingerprint": "chrome",
        "spider_x": "/",
        "dest": "www.cloudflare.com:443"
      }
    }
    """
}
