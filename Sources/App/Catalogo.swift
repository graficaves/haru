import Foundation

/// La lista de proyectos: lo que encuentra el escáner en las carpetas raíz,
/// combinado con las preferencias guardadas en
/// ~/Library/Application Support/Haru/preferencias.json.
@MainActor
final class Catalogo {
    private let archivo = Persistencia.carpeta.appendingPathComponent("preferencias.json")
    private let home = NSHomeDirectory()

    private(set) var preferencias: Preferencias
    /// Resultado del último escaneo, antes de aplicar las preferencias.
    private(set) var encontrados: [Encontrado] = []
    private(set) var escaneando = false
    /// Pedidos de escaneo que llegaron durante uno en curso: se hace una vuelta más.
    private var otraVuelta = false

    init() {
        if let datos = try? Data(contentsOf: archivo),
           let guardadas = try? Preferencias.decodificar(datos) {
            preferencias = guardadas
        } else {
            let home = self.home
            preferencias = Preferencias.porDefecto(home: home, existe: { ruta in
                var esCarpeta: ObjCBool = false
                return FileManager.default.fileExists(atPath: ruta, isDirectory: &esCarpeta)
                    && esCarpeta.boolValue
            })
            guardar()
        }
    }

    var proyectos: [Proyecto] { preferencias.proyectos(de: encontrados) }
    var cantidadOcultos: Int { preferencias.cantidadOcultos(en: encontrados) }
    var raicesExpandidas: [String] { preferencias.raicesExpandidas(home: home) }

    /// Escanea las raíces fuera del hilo principal. Si ya hay un escaneo en
    /// curso, este pedido se junta en una vuelta más al terminar.
    func escanear() async {
        guard !escaneando else { otraVuelta = true; return }
        escaneando = true
        repeat {
            otraVuelta = false
            let raices = raicesExpandidas
            encontrados = await Task.detached(priority: .utility) {
                Escaner.escanear(raices: raices)
            }.value
        } while otraVuelta
        escaneando = false
    }

    // MARK: Cambios (se guardan enseguida)

    func alternarFavorito(_ ruta: String) { preferencias.alternarFavorito(ruta); guardar() }
    func registrarUso(_ ruta: String) { preferencias.registrarUso(ruta, fecha: Date()); guardar() }
    func ocultar(_ ruta: String) { preferencias.ocultar(ruta); guardar() }
    func mostrarOcultos() { preferencias.mostrarOcultos(); guardar() }

    /// Reemplaza las carpetas raíz. Las que están dentro del home se guardan
    /// con `~` para que el archivo sea fácil de leer.
    func cambiarRaices(_ rutas: [String]) {
        let base = normalizarRuta(home)
        preferencias.raices = rutas.map { ruta in
            let r = normalizarRuta(ruta)
            if r == base { return "~" }
            if r.hasPrefix(base + "/") { return "~" + r.dropFirst(base.count) }
            return r
        }
        guardar()
    }

    private func guardar() {
        guard let datos = try? preferencias.codificar() else { return }
        do { try datos.write(to: archivo, options: .atomic) } catch {
            NSLog("[Haru] no pude guardar las preferencias: %@", error.localizedDescription)
        }
    }
}
