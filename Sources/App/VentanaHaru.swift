import AppKit
import SwiftUI

/// Un NSPanel sin barra de título no toma el foco por defecto; el buscador lo necesita.
final class PanelFlotante: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Panel tipo Spotlight: aparece centrado arriba, toma el foco y se esconde
/// cuando se hace clic en otra app.
@MainActor
final class VentanaHaru: NSObject, NSWindowDelegate {
    private let store: HaruStore
    private var panel: PanelFlotante?

    init(store: HaruStore) {
        self.store = store
    }

    func alternar() {
        if panel?.isVisible == true { esconder() } else { mostrar() }
    }

    func mostrar() {
        let p = panel ?? armar()
        panel = p
        store.busqueda = ""
        store.panelVisible = true
        if let pantalla = NSScreen.main?.visibleFrame {
            p.setFrameOrigin(NSPoint(x: pantalla.midX - p.frame.width / 2,
                                     y: pantalla.maxY - p.frame.height - pantalla.height * 0.12))
        }
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func esconder() {
        panel?.orderOut(nil)
        store.panelVisible = false
    }

    func windowDidResignKey(_ notification: Notification) {
        esconder()
    }

    private func armar() -> PanelFlotante {
        let p = PanelFlotante(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                              styleMask: [.titled, .fullSizeContentView],
                              backing: .buffered, defer: false)
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.delegate = self
        p.contentView = NSHostingView(rootView:
            PanelHaru(cerrarPanel: { [weak self] in self?.esconder() })
                .environmentObject(store)
        )
        return p
    }
}
