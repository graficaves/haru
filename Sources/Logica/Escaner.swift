import Foundation

/// Una carpeta de proyecto encontrada por el escáner.
struct Encontrado: Equatable, Hashable {
    let ruta: String
    let tieneDocker: Bool
}

/// Busca proyectos en las carpetas raíz. En cada raíz mira sus subcarpetas:
/// una subcarpeta es proyecto si tiene alguno de los `marcadores`. Si no lo
/// es, se la trata como contenedora y se mira un nivel más adentro (p. ej.
/// `~/Projects/clientes/tienda`). Dentro de un proyecto no se baja nunca.
enum Escaner {
    /// Archivos o carpetas que delatan un proyecto.
    static let marcadores = [
        ".git", "package.json", "composer.json", "Package.swift", "pyproject.toml",
        "requirements.txt", "go.mod", "Cargo.toml", "Gemfile", "index.html",
    ] + archivosCompose

    /// Con alguno de estos, Haru levanta y apaga Docker del proyecto.
    static let archivosCompose = [
        "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml",
    ]

    /// Carpetas que nunca son proyectos ni contienen proyectos propios.
    /// `Library` evita recorrer ~/Library cuando el home es una raíz.
    static let ignorados: Set<String> = [
        "node_modules", "vendor", "build", "dist", "backup", "backups", "Library",
    ]

    static func ignorar(_ nombre: String) -> Bool {
        nombre.hasPrefix(".") || ignorados.contains(nombre) || nombre.hasSuffix("-worktree")
    }

    /// Proyectos de todas las raíces, sin duplicados (una misma carpeta
    /// alcanzable desde dos raíces aparece una sola vez), ordenados por ruta.
    /// Una raíz inexistente o una carpeta ilegible se saltean sin cortar nada.
    static func escanear(raices: [String], fm: FileManager = .default) -> [Encontrado] {
        var vistos = Set<String>()
        var resultado: [Encontrado] = []

        func agregar(_ ruta: String, docker: Bool) {
            let real = URL(fileURLWithPath: ruta).resolvingSymlinksInPath().path
            guard vistos.insert(real).inserted else { return }
            resultado.append(Encontrado(ruta: ruta, tieneDocker: docker))
        }

        for raiz in raices {
            let base = normalizarRuta(URL(fileURLWithPath: raiz).standardizedFileURL.path)
            for hija in subcarpetas(de: base, fm: fm) {
                if let docker = esProyecto(hija, fm: fm) {
                    agregar(hija, docker: docker)
                    continue
                }
                // Contenedora: un nivel más, sin seguir bajando.
                for nieta in subcarpetas(de: hija, fm: fm) {
                    if let docker = esProyecto(nieta, fm: fm) { agregar(nieta, docker: docker) }
                }
            }
        }
        return resultado.sorted { $0.ruta < $1.ruta }
    }

    /// nil si la carpeta no es proyecto; si lo es, si tiene archivo compose.
    static func esProyecto(_ ruta: String, fm: FileManager = .default) -> Bool? {
        guard let contenido = try? fm.contentsOfDirectory(atPath: ruta) else { return nil }
        let nombres = Set(contenido)
        guard marcadores.contains(where: nombres.contains) else { return nil }
        return archivosCompose.contains(where: nombres.contains)
    }

    /// Subcarpetas no ignoradas, en orden alfabético. Vacío si no se puede leer.
    private static func subcarpetas(de ruta: String, fm: FileManager) -> [String] {
        guard let nombres = try? fm.contentsOfDirectory(atPath: ruta) else { return [] }
        return nombres.sorted().compactMap { nombre in
            guard !ignorar(nombre) else { return nil }
            let completa = ruta == "/" ? "/" + nombre : ruta + "/" + nombre
            var esCarpeta: ObjCBool = false
            guard fm.fileExists(atPath: completa, isDirectory: &esCarpeta), esCarpeta.boolValue else {
                return nil
            }
            return completa
        }
    }
}
