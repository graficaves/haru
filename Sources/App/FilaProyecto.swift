import AppKit
import SwiftUI

struct FilaProyecto: View {
    @EnvironmentObject var store: HaruStore
    let proyecto: Proyecto
    let seleccionada: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.alternarFavorito(proyecto)
            } label: {
                Image(systemName: proyecto.favorito ? "star.fill" : "star")
                    .foregroundStyle(proyecto.favorito ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(proyecto.favorito ? "Quitar de favoritos" : "Marcar como favorito")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(proyecto.nombre).font(.body.weight(.medium))
                    // Distingue proyectos con el mismo nombre de carpeta.
                    if store.nombreRepetido(proyecto) {
                        Text("en \(carpetaContenedora)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if proyecto.tieneDocker { Text("🐳").font(.caption) }
                }
                Text(detalle).font(.caption).foregroundStyle(colorDetalle).lineLimit(1)
            }

            Spacer()

            if store.ocupados.contains(proyecto.id) {
                ProgressView().controlSize(.small)
            } else if store.estaAbierto(proyecto) {
                Button("Cerrar") { Task { await store.cerrar(proyecto) } }
            } else {
                Button("Abrir") { Task { await store.abrir(proyecto) } }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(seleccionada ? Color.accentColor.opacity(0.18) : Color.clear))
        .contentShape(Rectangle())
        .contextMenu {
            Button("Ocultar de la lista") { store.ocultar(proyecto) }
            Button("Mostrar en Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: proyecto.ruta)])
            }
        }
    }

    private var carpetaContenedora: String {
        ((proyecto.ruta as NSString).deletingLastPathComponent as NSString).lastPathComponent
    }

    private var detalle: String {
        if let error = store.errores[proyecto.id] { return error }
        if let resto = cuentaVisible {
            return "Se apaga en \(resto / 60):\(String(format: "%02d", resto % 60))"
        }
        switch (store.tieneVentana(proyecto), store.tieneDockerCorriendo(proyecto)) {
        case (true, true): return "VS Code + Docker"
        case (true, false): return "VS Code"
        case (false, true): return "Docker sin ventana"
        case (false, false): return proyecto.ruta.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        }
    }

    private var colorDetalle: Color {
        if store.errores[proyecto.id] != nil { return .red }
        if cuentaVisible != nil { return .orange }
        return .secondary
    }

    /// La cuenta regresiva se muestra solo con el proyecto quieto y después de
    /// los primeros 30 s: al abrir, VS Code tarda en aparecer en `code --status`
    /// y no tiene sentido anunciar un apagado que no va a pasar. Es solo lo que se ve.
    private var cuentaVisible: Int? {
        guard !store.ocupados.contains(proyecto.id),
              let resto = store.segundosRestantes(proyecto), resto <= 90 else { return nil }
        return resto
    }
}
