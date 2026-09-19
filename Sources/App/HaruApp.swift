import SwiftUI
import AppKit
import ServiceManagement
import ApplicationServices

@main
struct HaruApp: App {
    // El store vive en el delegado: la vigilancia tiene que latir aunque el
    // menú nunca se abra (MenuBarExtra arma su contenido recién al abrirse).
    @NSApplicationDelegateAdaptor(Delegado.self) private var delegado

    var body: some Scene {
        MenuBarExtra {
            MenuHaru(store: delegado.store, abrirPanel: { delegado.ventana?.mostrar() })
        } label: {
            EtiquetaBarra(store: delegado.store)
        }
    }

    final class Delegado: NSObject, NSApplicationDelegate, ObservableObject {
        @MainActor let store = HaruStore()
        @MainActor var ventana: VentanaHaru?

        @MainActor
        func applicationDidFinishLaunching(_ notification: Notification) {
            store.avisar = { Aviso.mostrar($0) }
            let v = VentanaHaru(store: store)
            ventana = v
            store.iniciar()
            AtajoGlobal.registrar { Task { @MainActor in v.alternar() } }
            registrarInicioDeSesion()
            NSLog("[Haru] arrancó")
        }

        /// Abrir Haru desde Spotlight o Finder con la app ya corriendo muestra el panel.
        func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
            Task { @MainActor in ventana?.mostrar() }
            return true
        }

        /// Arranque al iniciar sesión. Si macOS lo rechaza queda en el log y se
        /// puede agregar a mano en Ajustes → General → Ítems de inicio.
        @MainActor
        private func registrarInicioDeSesion() {
            guard SMAppService.mainApp.status != .enabled else { return }
            do { try SMAppService.mainApp.register() } catch {
                NSLog("[Haru] no pude registrar el inicio de sesión: %@", error.localizedDescription)
            }
        }
    }
}

private struct MenuHaru: View {
    @ObservedObject var store: HaruStore
    let abrirPanel: () -> Void

    var body: some View {
        Button("Abrir Haru (⌥⌘P)", action: abrirPanel)
        Divider()
        Text("\(store.cantidadConDocker) proyectos con Docker prendido")
        Divider()
        Button("Carpetas de proyectos…") { SelectorCarpetas.elegir(store: store) }
        Button("Volver a buscar proyectos") { Task { await store.reescanear() } }
        if store.cantidadOcultos > 0 {
            Button("Mostrar proyectos ocultos (\(store.cantidadOcultos))") { store.mostrarOcultos() }
        }
        if !AXIsProcessTrusted() {
            Divider()
            Button("Dar permiso para cerrar ventanas de VS Code…") { VSCode.pedirPermiso() }
        }
        Divider()
        Button("Salir") { NSApp.terminate(nil) }
    }
}

/// Ícono de la barra con la cantidad de proyectos que tienen Docker prendido.
private struct EtiquetaBarra: View {
    @ObservedObject var store: HaruStore

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "leaf.fill")
            if store.cantidadConDocker > 0 {
                Text("\(store.cantidadConDocker)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
        }
        .accessibilityLabel("Haru, \(store.cantidadConDocker) proyectos con Docker prendido")
    }
}
