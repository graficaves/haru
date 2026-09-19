import Foundation

/// Archivos de Haru en ~/Library/Application Support/Haru.
enum Persistencia {
    static let carpeta: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Haru", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let archivoVigilante = carpeta.appendingPathComponent("estado.json")

    /// El Vigilante guardado; si no hay o está roto, uno vacío.
    static func leerVigilante() -> Vigilante {
        guard let datos = try? Data(contentsOf: archivoVigilante),
              let v = try? JSONDecoder().decode(Vigilante.self, from: datos) else { return Vigilante() }
        return v
    }

    static func guardar(_ vigilante: Vigilante) {
        guard let datos = try? JSONEncoder().encode(vigilante) else { return }
        try? datos.write(to: archivoVigilante, options: .atomic)
    }
}
