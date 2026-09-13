import SwiftUI

struct ImportProfileView: View {
    var onImport: (VlessProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var errorText: String?
    @State private var preview: VlessProfile?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("JSON или vless://")
                } footer: {
                    Text("Поддерживается формат examples/client-reality.json и стандартные Reality share-ссылки.")
                }

                if let preview {
                    Section("Превью") {
                        LabeledContent("Имя", value: preview.name)
                        LabeledContent("Адрес", value: preview.endpointSummary)
                        LabeledContent("UUID", value: preview.uuid)
                        LabeledContent("pbk", value: preview.reality.publicKey)
                        LabeledContent("sid", value: preview.reality.shortId)
                        LabeledContent("SNI", value: preview.reality.serverNames.joined(separator: ", "))
                        LabeledContent("fp", value: preview.reality.fingerprint)
                        LabeledContent("spx", value: preview.reality.spiderX)
                        LabeledContent("flow", value: preview.flow)
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Разобрать") { parse() }
                    Button("Импортировать") {
                        parse()
                        if let preview { onImport(preview) }
                    }
                    .disabled(preview == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            preview = try ProfileImporter.importAny(text)
            errorText = nil
        } catch {
            preview = nil
            errorText = error.localizedDescription
        }
    }
}

enum SampleData {
    /// Matches repo `examples/client-reality.json` (placeholders only).
    static let clientRealityJSON = #"""
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
    """#
}
