import Foundation

/// Lo que Haru recuerda entre sesiones. Todo se indexa por ruta absoluta del
/// proyecto. Se guarda como JSON; campos que falten toman su valor por defecto,
/// así un archivo viejo o editado a mano no se pierde entero.
struct Preferencias: Codable, Equatable {
    /// Carpetas donde buscar proyectos. Aceptan `~` al principio.
    var raices: [String]
    var favoritos: Set<String> = []
    var usos: [String: Int] = [:]
    var ultimoUso: [String: Date] = [:]
    var ocultos: Set<String> = []

    init(raices: [String], favoritos: Set<String> = [], usos: [String: Int] = [:],
         ultimoUso: [String: Date] = [:], ocultos: Set<String> = []) {
        self.raices = raices
        self.favoritos = favoritos
        self.usos = usos
        self.ultimoUso = ultimoUso
        self.ocultos = ocultos
    }

    // MARK: Raíces

    /// Lugares habituales donde se guardan proyectos. Se usan los que existan.
    static let raicesHabituales = [
        "~/Projects", "~/Developer", "~/Sites", "~/code", "~/dev", "~/Documents/GitHub",
    ]

    /// Preferencias de la primera vez: las raíces habituales que existan y,
    /// siempre, el home (su primer nivel, más las carpetas contenedoras).
    static func porDefecto(home: String, existe: (String) -> Bool) -> Preferencias {
        let encontradas = raicesHabituales.filter { existe(expandir($0, home: home)) }
        return Preferencias(raices: encontradas + ["~"])
    }

    /// Expande `~` y `~/…` al home dado. Otras rutas quedan igual.
    static func expandir(_ ruta: String, home: String) -> String {
        if ruta == "~" { return home }
        if ruta.hasPrefix("~/") { return normalizarRuta(home) + String(ruta.dropFirst(1)) }
        return ruta
    }

    func raicesExpandidas(home: String) -> [String] {
        raices.map { Preferencias.expandir($0, home: home) }
    }

    // MARK: Combinar con el escaneo

    /// Proyectos para mostrar: lo encontrado en disco con favorito y usos
    /// aplicados, sin los ocultos.
    func proyectos(de encontrados: [Encontrado]) -> [Proyecto] {
        encontrados.compactMap { e in
            let ruta = normalizarRuta(e.ruta)
            guard !ocultos.contains(ruta) else { return nil }
            return Proyecto(ruta: ruta, tieneDocker: e.tieneDocker,
                            favorito: favoritos.contains(ruta),
                            usos: usos[ruta] ?? 0, ultimoUso: ultimoUso[ruta])
        }
    }

    /// Cuántos de los encontrados están ocultos (para ofrecer mostrarlos).
    func cantidadOcultos(en encontrados: [Encontrado]) -> Int {
        encontrados.filter { ocultos.contains(normalizarRuta($0.ruta)) }.count
    }

    // MARK: Cambios

    mutating func alternarFavorito(_ ruta: String) {
        let r = normalizarRuta(ruta)
        if favoritos.contains(r) { favoritos.remove(r) } else { favoritos.insert(r) }
    }

    mutating func registrarUso(_ ruta: String, fecha: Date) {
        let r = normalizarRuta(ruta)
        usos[r, default: 0] += 1
        ultimoUso[r] = fecha
    }

    mutating func ocultar(_ ruta: String) {
        ocultos.insert(normalizarRuta(ruta))
    }

    mutating func mostrarOcultos() {
        ocultos.removeAll()
    }

    // MARK: JSON

    private enum Claves: String, CodingKey {
        case raices, favoritos, usos, ultimoUso, ocultos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Claves.self)
        raices = try c.decodeIfPresent([String].self, forKey: .raices) ?? ["~"]
        favoritos = try c.decodeIfPresent(Set<String>.self, forKey: .favoritos) ?? []
        usos = try c.decodeIfPresent([String: Int].self, forKey: .usos) ?? [:]
        ultimoUso = try c.decodeIfPresent([String: Date].self, forKey: .ultimoUso) ?? [:]
        ocultos = try c.decodeIfPresent(Set<String>.self, forKey: .ocultos) ?? []
    }

    /// JSON legible (fechas ISO 8601, claves ordenadas) para poder editarlo a mano.
    func codificar() throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    static func decodificar(_ datos: Data) throws -> Preferencias {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(Preferencias.self, from: datos)
    }
}
