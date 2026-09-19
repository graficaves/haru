import AppKit

/// Diálogo para elegir las carpetas donde Haru busca proyectos.
@MainActor
enum SelectorCarpetas {
    static func elegir(store: HaruStore) {
        let dialogo = NSOpenPanel()
        dialogo.title = "Carpetas de proyectos"
        dialogo.message = "Elegí una o más carpetas donde tenés tus proyectos. Haru mira sus subcarpetas (y un nivel más adentro). Reemplaza las actuales."
        dialogo.prompt = "Usar estas carpetas"
        dialogo.canChooseDirectories = true
        dialogo.canChooseFiles = false
        dialogo.canCreateDirectories = false
        dialogo.allowsMultipleSelection = true
        dialogo.directoryURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        // Una app de barra de menú tiene que activarse para que el diálogo quede al frente.
        NSApp.activate(ignoringOtherApps: true)
        guard dialogo.runModal() == .OK, !dialogo.urls.isEmpty else { return }
        store.cambiarRaices(dialogo.urls.map(\.path))
    }
}
