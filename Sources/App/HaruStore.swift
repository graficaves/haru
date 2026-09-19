import Foundation

/// Estado de Haru y sus acciones. Todo corre en el hilo principal; los
/// comandos externos esperan fuera de él dentro de `Ejecutor`, y el escaneo
/// de carpetas dentro de `Catalogo`.
@MainActor
final class HaruStore: ObservableObject {
    @Published private(set) var proyectos: [Proyecto] = []
    @Published private(set) var cantidadOcultos = 0
    /// Hay un escaneo en curso (para el mensaje de lista vacía).
    @Published private(set) var buscandoProyectos = false
    /// Ya terminó al menos un escaneo desde que arrancó la app.
    @Published private(set) var escaneoInicialListo = false
    @Published var busqueda = ""
    /// Nombres de carpeta con ventana de VS Code, según la última lectura.
    @Published private(set) var ventanas: Set<String> = []
    /// Carpetas (normalizadas) con contenedores corriendo.
    @Published private(set) var rutasConDocker: Set<String> = []
    /// Proyectos (por id) con una acción en curso.
    @Published private(set) var ocupados: Set<String> = []
    @Published private(set) var errores: [String: String] = [:]
    @Published private(set) var vigilante = Persistencia.leerVigilante()
    @Published private(set) var ahora = Date()

    /// Muestra un aviso breve; lo conecta el delegado de la app.
    var avisar: (String) -> Void = { NSLog("[Haru] %@", $0) }

    /// Con el panel a la vista vale la pena leer ventanas aunque no haya
    /// vigilados, y volver a buscar proyectos por si hay alguno nuevo. Las dos
    /// cosas corren por separado para que ninguna demore a la otra.
    var panelVisible = false {
        didSet {
            guard panelVisible && !oldValue else { return }
            Task { await vigilar() }
            Task { await reescanear() }
        }
    }

    private let catalogo = Catalogo()
    private var relojes: [Timer] = []
    private var avisoPermisoDado = false
    /// Hay un `vigilar()` en curso; los pedidos que llegan mientras tanto se
    /// juntan en una vuelta más al terminar, en vez de correr en paralelo.
    private var vigilando = false
    private var otraVuelta = false

    // MARK: Lo que muestra la interfaz

    func tieneVentana(_ p: Proyecto) -> Bool { ventanas.contains(p.nombre) }
    func tieneDockerCorriendo(_ p: Proyecto) -> Bool { rutasConDocker.contains(p.ruta) }
    func estaAbierto(_ p: Proyecto) -> Bool { tieneVentana(p) || tieneDockerCorriendo(p) }
    func segundosRestantes(_ p: Proyecto) -> Int? { vigilante.segundosRestantes(p.id, ahora: ahora) }

    /// Otro proyecto de la lista tiene el mismo nombre de carpeta: la fila
    /// muestra también la carpeta que lo contiene para distinguirlos.
    func nombreRepetido(_ p: Proyecto) -> Bool {
        proyectos.contains { $0.nombre == p.nombre && $0.id != p.id }
    }

    var secciones: Secciones {
        let abiertos = Set(proyectos.filter { estaAbierto($0) }.map(\.id))
        return Orden.secciones(proyectos, abiertos: abiertos, busqueda: busqueda)
    }

    var cantidadConDocker: Int { proyectos.filter { tieneDockerCorriendo($0) }.count }

    var raices: [String] { catalogo.raicesExpandidas }

    // MARK: Ciclo

    func iniciar() {
        actualizarLista()
        Task { await reescanear() }
        Task { await vigilar() }
        // En modo .common siguen corriendo con el menú de la barra abierto.
        relojes = [
            Timer(timeInterval: 30, repeats: true) { [weak self] _ in
                Task { @MainActor in await self?.vigilar() }
            },
            // Solo mueve la cuenta regresiva que se ve; con el panel oculto no hace nada.
            Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.panelVisible else { return }
                    self.ahora = Date()
                }
            },
        ]
        for reloj in relojes { RunLoop.main.add(reloj, forMode: .common) }
    }

    /// Vuelve a buscar proyectos en las carpetas raíz, sin bloquear la interfaz.
    func reescanear() async {
        buscandoProyectos = true
        await catalogo.escanear()
        // Si este pedido se juntó con un escaneo en curso, vuelve enseguida:
        // el que termina de verdad es el que actualiza la lista.
        guard !catalogo.escaneando else { return }
        buscandoProyectos = false
        escaneoInicialListo = true
        actualizarLista()
    }

    /// Lee Docker y VS Code y apaga lo que el Vigilante diga. Nunca corren dos
    /// a la vez: si ya hay uno en curso, se pide otra vuelta al terminar.
    func vigilar() async {
        guard !vigilando else { otraVuelta = true; return }
        vigilando = true
        repeat {
            otraVuelta = false
            await vueltaDeVigilancia()
        } while otraVuelta
        vigilando = false
    }

    /// VS Code solo se consulta si hay algo que vigilar o el panel está a la vista.
    private func vueltaDeVigilancia() async {
        // Si `docker ps` falla no se sabe qué corre: no se pisa lo último
        // conocido y en esta vuelta no se apaga nada.
        let rutas = await Docker.rutasCorriendo()
        if let rutas { rutasConDocker = rutas }
        guard panelVisible || !vigilante.estaVacio else { return }
        let ahora = Date()
        let leidas = await VSCode.carpetasAbiertas()
        if let leidas { ventanas = leidas }
        guard let rutas, !vigilante.estaVacio else { return }
        // Los que tienen una acción en curso (abrirse, cerrarse) no se tocan.
        let aApagar = vigilante.ciclo(carpetasAbiertas: leidas, ahora: ahora, excluir: ocupados)
        Persistencia.guardar(vigilante)
        guard !aApagar.isEmpty else { return }
        var huboDown = false
        for v in aApagar {
            // Sin contenedores propios corriendo no hay nada que bajar, y así
            // no se baja otro proyecto compose con el mismo nombre de carpeta.
            guard rutas.contains(v.ruta) else { continue }
            // Si mientras tanto el usuario empezó a abrirlo o cerrarlo, se deja.
            guard empezar(v.ruta) else { continue }
            let nombre = v.carpeta
            do {
                try await Docker.bajar(ruta: v.ruta)
                huboDown = true
                avisar("Haru apagó Docker de \(nombre): se cerró su ventana")
            } catch {
                anotarError(v.ruta, error.localizedDescription)
                avisar("No pude apagar Docker de \(nombre): \(error.localizedDescription)")
            }
            ocupados.remove(v.ruta)
        }
        if huboDown { await cerrarDesktopSiVacio() }
        if let nuevas = await Docker.rutasCorriendo() { rutasConDocker = nuevas }
    }

    // MARK: Acciones

    func abrir(_ p: Proyecto) async {
        guard empezar(p.id) else { return }
        // Se vigila antes de cualquier espera: así una vuelta del vigilante
        // en medio del arranque ya lo ve (y lo saltea por estar ocupado).
        if p.tieneDocker {
            vigilante.vigilar(ruta: p.ruta, carpeta: p.nombre)
            Persistencia.guardar(vigilante)
        }
        // VS Code se abre en paralelo: se puede empezar a trabajar mientras Docker levanta.
        let vscode = Task { try await VSCode.abrir(ruta: p.ruta) }
        if p.tieneDocker {
            do {
                try await Docker.asegurarDesktop()
                try await Docker.levantar(ruta: p.ruta)
            } catch {
                vigilante.dejarDeVigilar(p.id)
                Persistencia.guardar(vigilante)
                anotarError(p.id, error.localizedDescription)
                avisar("No pude levantar Docker de \(p.nombre): \(error.localizedDescription)")
            }
        }
        do { try await vscode.value } catch { anotarError(p.id, error.localizedDescription) }
        catalogo.registrarUso(p.id)
        actualizarLista()
        ocupados.remove(p.id)
        await vigilar()
    }

    func cerrar(_ p: Proyecto) async {
        guard empezar(p.id) else { return }
        vigilante.dejarDeVigilar(p.id)
        Persistencia.guardar(vigilante)
        // `compose down` es idempotente: se corre siempre que haya Docker, sin
        // depender de la última lectura. Con Docker Desktop apagado no hay nada
        // corriendo, y no se intenta ni se marca error.
        var huboDown = false
        if p.tieneDocker, await Docker.responde() {
            do {
                try await Docker.bajar(ruta: p.ruta)
                huboDown = true
            } catch {
                anotarError(p.id, error.localizedDescription)
            }
        }
        if tieneVentana(p) {
            let cerro = await VSCode.cerrarVentana(ruta: p.ruta, carpeta: p.nombre)
            if !cerro && !VSCode.tienePermiso && !avisoPermisoDado {
                avisoPermisoDado = true
                avisar("Docker apagado. La ventana de VS Code quedó abierta: para cerrarla, Haru necesita permiso de Accesibilidad (menú de Haru → Dar permiso).")
            }
        }
        ocupados.remove(p.id)
        if huboDown { await cerrarDesktopSiVacio() }
        await vigilar()
    }

    /// Proyectos con Docker prendido y sin ventana de VS Code. nil si no se
    /// pudo leer Docker o VS Code: en ese caso no se propone apagar nada.
    func sinUso() async -> [Proyecto]? {
        guard let rutas = await Docker.rutasCorriendo() else { return nil }
        rutasConDocker = rutas
        guard let leidas = await VSCode.carpetasAbiertas() else { return nil }
        ventanas = leidas
        return proyectos.filter { tieneDockerCorriendo($0) && !leidas.contains($0.nombre) }
    }

    /// Apaga los confirmados, salvo los que desde la confirmación volvieron a
    /// tener ventana. Si no se puede leer VS Code, no apaga nada.
    func apagar(_ lista: [Proyecto]) async {
        guard let leidas = await VSCode.carpetasAbiertas() else {
            avisar("No pude leer las ventanas de VS Code: no apago nada")
            return
        }
        ventanas = leidas
        var huboDown = false
        for p in lista where !leidas.contains(p.nombre) {
            guard empezar(p.id) else { continue }
            vigilante.dejarDeVigilar(p.id)
            Persistencia.guardar(vigilante)
            do {
                try await Docker.bajar(ruta: p.ruta)
                huboDown = true
            } catch {
                anotarError(p.id, error.localizedDescription)
            }
            ocupados.remove(p.id)
        }
        if huboDown { await cerrarDesktopSiVacio() }
        await vigilar()
    }

    // MARK: Lista

    func alternarFavorito(_ p: Proyecto) {
        catalogo.alternarFavorito(p.id)
        actualizarLista()
    }

    /// Lo saca de la lista. Si estaba vigilado lo sigue estando: ocultar no
    /// cambia lo que pasa con su Docker.
    func ocultar(_ p: Proyecto) {
        catalogo.ocultar(p.id)
        actualizarLista()
    }

    func mostrarOcultos() {
        catalogo.mostrarOcultos()
        actualizarLista()
    }

    func cambiarRaices(_ rutas: [String]) {
        guard !rutas.isEmpty else { return }
        catalogo.cambiarRaices(rutas)
        Task { await reescanear() }
    }

    private func actualizarLista() {
        proyectos = catalogo.proyectos
        cantidadOcultos = catalogo.cantidadOcultos
    }

    // MARK: Ayudas

    /// Marca el proyecto como ocupado; false si ya había una acción en curso.
    private func empezar(_ id: String) -> Bool {
        guard !ocupados.contains(id) else { return false }
        ocupados.insert(id)
        errores[id] = nil
        return true
    }

    /// Cierra Docker Desktop si quedó vacío, pero nunca con otra acción en
    /// curso (p. ej. un abrir que está levantando Docker): quien llama ya sacó
    /// su propio proyecto de `ocupados`. Se vuelve a mirar justo antes de cerrar.
    private func cerrarDesktopSiVacio() async {
        guard ocupados.isEmpty else { return }
        await Docker.cerrarDesktopSiVacio(seguir: { [weak self] in self?.ocupados.isEmpty ?? false })
    }

    private func anotarError(_ id: String, _ mensaje: String) {
        errores[id] = [errores[id], mensaje].compactMap { $0 }.joined(separator: " · ")
    }
}
