import SwiftUI
import AppKit
import EDModele

@main
struct EngineeringDesignApp: App {
    @StateObject private var etat = EtatApp()

    init() {
        // lancé hors d'un .app (swift run) : se comporter quand même comme une vraie app du Dock
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Engineering Design") {
            ContentView()
                .environmentObject(etat)
                .frame(minWidth: 1100, minHeight: 680)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Écrire la macro SolidWorks") { etat.genererMacroSelection() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("Exporter en STL") { etat.exporterSTLSelection() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Recharger le projet") { etat.recharger() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
