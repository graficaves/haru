import Foundation

/// Un proyecto abierto desde Haru: se apaga solo cuando se cierra su ventana.
struct Vigilado: Codable, Equatable {
    /// Ruta del proyecto; es también su id.
    let ruta: String
    /// Nombre de la carpeta, tal como aparece en `code --status`.
    let carpeta: String
    /// Desde cuándo no tiene ventana de VS Code; nil mientras la tenga.
    var sinVentanaDesde: Date?
}

/// Decide cuándo apagar Docker de los proyectos abiertos desde Haru. No
/// ejecuta nada: dice qué apagar y quien lo llama lo hace. Ante la duda no
/// apaga: una lectura fallida de VS Code no empieza ni termina ninguna cuenta.
struct Vigilante: Codable, Equatable {
    static let gracia: TimeInterval = 120

    private(set) var vigilados: [Vigilado] = []

    var estaVacio: Bool { vigilados.isEmpty }

    mutating func vigilar(ruta: String, carpeta: String) {
        dejarDeVigilar(ruta)
        vigilados.append(Vigilado(ruta: ruta, carpeta: carpeta, sinVentanaDesde: nil))
    }

    mutating func dejarDeVigilar(_ ruta: String) {
        vigilados.removeAll { $0.ruta == ruta }
    }

    /// Segundos que faltan para apagar, o nil si no hay cuenta en curso.
    func segundosRestantes(_ ruta: String, ahora: Date) -> Int? {
        guard let v = vigilados.first(where: { $0.ruta == ruta }),
              let desde = v.sinVentanaDesde else { return nil }
        return max(0, Int((Vigilante.gracia - ahora.timeIntervalSince(desde)).rounded(.up)))
    }

    /// Un ciclo de vigilancia con las carpetas que hoy tienen ventana (nil si
    /// no se pudo leer VS Code). Devuelve los que hay que apagar y los saca.
    /// Los de `excluir` (rutas con una acción en curso) quedan vigilados tal cual.
    mutating func ciclo(carpetasAbiertas: Set<String>?, ahora: Date,
                        excluir: Set<String> = []) -> [Vigilado] {
        guard let abiertas = carpetasAbiertas else { return [] }
        var aApagar: [Vigilado] = []
        var quedan: [Vigilado] = []
        for var v in vigilados {
            if excluir.contains(v.ruta) {
                quedan.append(v)
            } else if abiertas.contains(v.carpeta) {
                v.sinVentanaDesde = nil
                quedan.append(v)
            } else if let desde = v.sinVentanaDesde {
                if ahora.timeIntervalSince(desde) >= Vigilante.gracia { aApagar.append(v) }
                else { quedan.append(v) }
            } else {
                v.sinVentanaDesde = ahora
                quedan.append(v)
            }
        }
        vigilados = quedan
        return aApagar
    }
}
