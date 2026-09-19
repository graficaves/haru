import Foundation

/// La lista de Haru tal como se muestra: abiertos, favoritos y el resto.
struct Secciones: Equatable {
    var abiertos: [Proyecto] = []
    var favoritos: [Proyecto] = []
    var resto: [Proyecto] = []

    /// En el orden de pantalla, para moverse con ↑↓.
    var todos: [Proyecto] { abiertos + favoritos + resto }
}

enum Orden {
    /// Minúsculas y sin tildes, para que "gestion" encuentre "gestión".
    static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.caseInsensitive, .diacriticInsensitive],
                      locale: Locale(identifier: "es"))
    }

    static func secciones(_ proyectos: [Proyecto], abiertos: Set<String>, busqueda: String) -> Secciones {
        let consulta = normalizar(busqueda.trimmingCharacters(in: .whitespaces))
        let visibles = consulta.isEmpty ? proyectos : proyectos.filter {
            normalizar($0.nombre).contains(consulta)
        }
        var s = Secciones()
        for p in visibles.sorted(by: vaAntes) {
            if abiertos.contains(p.id) { s.abiertos.append(p) }
            else if p.favorito { s.favoritos.append(p) }
            else { s.resto.append(p) }
        }
        return s
    }

    /// Más usado primero; a igualdad, el usado más recientemente; después
    /// por nombre y por ruta.
    static func vaAntes(_ a: Proyecto, _ b: Proyecto) -> Bool {
        if a.usos != b.usos { return a.usos > b.usos }
        let ua = a.ultimoUso ?? .distantPast, ub = b.ultimoUso ?? .distantPast
        if ua != ub { return ua > ub }
        let porNombre = a.nombre.localizedCaseInsensitiveCompare(b.nombre)
        if porNombre != .orderedSame { return porNombre == .orderedAscending }
        return a.ruta < b.ruta
    }
}
