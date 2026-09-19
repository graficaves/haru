import AppKit
import SwiftUI

/// Aviso breve arriba a la derecha que se va solo a los 6 s. Haru dibuja el
/// suyo en lugar de usar las notificaciones del sistema: no pide permiso de
/// notificaciones y se ve aunque esté activado un modo de concentración.
@MainActor
enum Aviso {
    private static var ventana: NSPanel?
    private static var cierre: DispatchWorkItem?

    static func mostrar(_ texto: String) {
        NSLog("[Haru] %@", texto)
        cierre?.cancel()
        ventana?.orderOut(nil)

        let vista = NSHostingView(rootView:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "leaf.fill").foregroundStyle(.green)
                Text(texto).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 340, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        )
        let tamano = vista.fittingSize
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: tamano),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = vista
        if let pantalla = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: pantalla.maxX - tamano.width - 16,
                                         y: pantalla.maxY - tamano.height - 16))
        }
        panel.orderFrontRegardless()
        ventana = panel

        let trabajo = DispatchWorkItem { panel.orderOut(nil) }
        cierre = trabajo
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: trabajo)
    }
}
