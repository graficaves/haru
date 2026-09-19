import Foundation

/// Lee la salida de `code --status` y devuelve los nombres de las carpetas que
/// tienen una ventana de VS Code abierta. `code --status` no pide permisos (a
/// diferencia de leer ventanas con Accesibilidad), pero solo da nombres, no rutas.
enum ParserCodeStatus {
    /// Separador que VS Code pone entre el editor activo y la carpeta en el título.
    private static let separador = " — "

    /// nil si la salida no trae la sección `Workspace Stats`: no se pudo leer,
    /// y quien llama no debe tomarlo como "no hay ventanas".
    static func carpetasAbiertas(_ salida: String) -> Set<String>? {
        let lineas = salida.components(separatedBy: .newlines)
        guard let inicio = lineas.firstIndex(where: { $0.hasPrefix("Workspace Stats:") }) else {
            return nil
        }
        var carpetas = Set<String>()
        for linea in lineas[(inicio + 1)...] where linea.hasPrefix("|") {
            let texto = linea.dropFirst().trimmingCharacters(in: .whitespaces)
            if let titulo = entre(texto, prefijo: "Window (", fin: ")") {
                // `Window (editor — carpeta)` o `Window (carpeta)` sin editor abierto.
                // Se guardan todas las partes: si el título trae perfil u otro
                // sufijo, la carpeta igual queda (sobra algún nombre, del lado seguro).
                for parte in titulo.components(separatedBy: separador) {
                    let nombre = parte.trimmingCharacters(in: .whitespaces)
                    if !nombre.isEmpty { carpetas.insert(nombre) }
                }
            } else if let carpeta = entre(texto, prefijo: "Folder (", fin: "):") {
                carpetas.insert(carpeta)
            }
        }
        return carpetas
    }

    /// Texto entre `prefijo` y la última aparición de `fin`.
    private static func entre(_ texto: String, prefijo: String, fin: String) -> String? {
        guard texto.hasPrefix(prefijo) else { return nil }
        let resto = texto.dropFirst(prefijo.count)
        guard let cierre = resto.range(of: fin, options: .backwards) else { return nil }
        return String(resto[..<cierre.lowerBound])
    }
}
