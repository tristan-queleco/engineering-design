import SwiftUI
import AppKit

/// Comment brancher Claude sur l'app : serveur MCP local, aucune clé API.
struct VueConnexion: View {
    private var cheminMCP: String {
        let dansApp = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/engineering-design-mcp").path
        if FileManager.default.isExecutableFile(atPath: dansApp) { return dansApp }
        return URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
            .appendingPathComponent("engineering-design-mcp").path
    }

    private var commandeClaudeCode: String { "claude mcp add -s user engineering-design -- \"\(cheminMCP)\"" }

    private var configDesktop: String {
        """
        "engineering-design": {
          "command": "\(cheminMCP)"
        }
        """
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Brancher Claude").font(.title2.bold())
                Text("Le serveur MCP tourne sur ton Mac. Claude Desktop et Claude Code le lancent eux-mêmes et utilisent ton compte Claude : aucune clé API.")
                    .foregroundStyle(.secondary)
                bloc("Claude Code (Terminal)", commandeClaudeCode)
                bloc("Claude Desktop : Réglages > Développeur > Modifier la config, dans « mcpServers »", configDesktop)
                Text("Outils offerts : lister_pieces, changer_parametre, generer_macro, exporter_stl, essai_enroulement.")
                    .font(.callout)
                Text("À venir (jalon 3) : connexion par compte (OAuth) pour claude.ai et ChatGPT, sans rien installer.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private func bloc(_ titre: String, _ texte: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titre).font(.headline)
            HStack(alignment: .top) {
                Text(texte).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                Button("Copier") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(texte, forType: .string)
                }
            }
        }
    }
}
