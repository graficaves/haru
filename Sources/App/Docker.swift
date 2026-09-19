import Foundation

enum Docker {
    /// Docker Desktop está prendido y el motor contesta.
    static func responde() async -> Bool {
        await Ejecutor.correr(["docker", "info", "--format", "{{.ServerVersion}}"], limite: 15).ok
    }

    /// Arranca Docker Desktop si no responde. `docker desktop start` espera
    /// hasta que el motor esté listo (máximo 60 s).
    static func asegurarDesktop() async throws {
        if await responde() { return }
        let r = await Ejecutor.correr(["docker", "desktop", "start", "--timeout", "60"], limite: 90)
        guard r.ok, await responde() else {
            throw ErrorHaru(mensaje: "Docker Desktop no arrancó en 60 segundos. \(r.error)")
        }
    }

    static func levantar(ruta: String) async throws {
        let r = await Ejecutor.correr(["docker", "compose", "up", "-d"], en: ruta, limite: 600)
        guard r.ok else { throw ErrorHaru(mensaje: r.error) }
    }

    static func bajar(ruta: String) async throws {
        let r = await Ejecutor.correr(["docker", "compose", "down"], en: ruta)
        guard r.ok else { throw ErrorHaru(mensaje: r.error) }
    }

    /// Carpetas de compose con contenedores corriendo, según la etiqueta que
    /// pone compose. Con Docker Desktop apagado es el conjunto vacío; nil si
    /// `docker ps` falló con el motor prendido (no se sabe qué corre).
    static func rutasCorriendo() async -> Set<String>? {
        let formato = "{{.Label \"com.docker.compose.project.working_dir\"}}"
        let r = await Ejecutor.correr(["docker", "ps", "--format", formato], limite: 20)
        guard r.ok else { return await responde() ? nil : [] }
        return Set(r.stdout.split(separator: "\n")
            .map { normalizarRuta(String($0).trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty })
    }

    /// Cierra Docker Desktop solo si no queda ningún contenedor corriendo, de
    /// nadie. Si `docker ps` falla no se sabe, y entonces no se toca. `seguir`
    /// se consulta justo antes de cerrar, por si mientras tanto empezó algo.
    static func cerrarDesktopSiVacio(seguir: @MainActor () -> Bool) async {
        let r = await Ejecutor.correr(["docker", "ps", "-q"], limite: 20)
        guard r.ok, r.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard await seguir() else { return }
        _ = await Ejecutor.correr(["docker", "desktop", "stop", "--detach"], limite: 30)
    }
}
