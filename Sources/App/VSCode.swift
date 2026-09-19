import AppKit
import ApplicationServices

enum VSCode {
    static let bundleId = "com.microsoft.VSCode"

    static var estaCorriendo: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    /// Abre la carpeta; si ya tiene ventana, VS Code la trae al frente.
    static func abrir(ruta: String) async throws {
        let r = await Ejecutor.correr(["open", "-a", "Visual Studio Code", ruta])
        guard r.ok else { throw ErrorHaru(mensaje: "No pude abrir VS Code: \(r.error)") }
    }

    /// Carpetas con ventana abierta. Vacío si VS Code no está corriendo; nil
    /// si está corriendo pero no se pudo leer (quien llama no debe apagar nada).
    static func carpetasAbiertas() async -> Set<String>? {
        guard estaCorriendo else { return [] }
        let r = await Ejecutor.correr(["code", "--status"], limite: 20)
        guard r.ok else { return nil }
        return ParserCodeStatus.carpetasAbiertas(r.stdout + "\n" + r.stderr)
    }

    /// Haru tiene el permiso de Accesibilidad (necesario para cerrar ventanas).
    static var tienePermiso: Bool { AXIsProcessTrusted() }

    /// Cierra la ventana de la carpeta. System Events solo ve las ventanas del
    /// escritorio (Space) actual, así que primero se abre la carpeta: VS Code
    /// trae su ventana al frente y macOS cambia de escritorio. Después se
    /// cierra la ventana del frente solo si su título es la carpeta o termina
    /// en "— carpeta". Sin permiso de Accesibilidad devuelve false sin intentar.
    static func cerrarVentana(ruta: String, carpeta: String) async -> Bool {
        guard tienePermiso, estaCorriendo else { return false }
        guard await Ejecutor.correr(["open", "-a", "Visual Studio Code", ruta], limite: 20).ok else {
            return false
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        let guion = """
        on run argv
          set carpeta to item 1 of argv
          tell application "System Events" to tell process "Code"
            if (count of windows) is 0 then return 0
            set w to window 1
            set t to name of w
            if t is carpeta or t ends with ("— " & carpeta) then
              click (first button of w whose subrole is "AXCloseButton")
              return 1
            end if
          end tell
          return 0
        end run
        """
        let r = await Ejecutor.correr(["osascript", "-e", guion, carpeta], limite: 20)
        return r.ok && (Int(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) > 0
    }

    /// Abre el diálogo del sistema para dar el permiso de Accesibilidad.
    static func pedirPermiso() {
        let clave = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([clave: true] as CFDictionary)
    }
}
