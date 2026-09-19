import Foundation

/// Arma un árbol de carpetas en un directorio temporal. Cada entrada es una
/// ruta relativa: termina en "/" si es carpeta, si no es un archivo vacío.
private func armarArbol(_ entradas: [String]) -> String {
    let fm = FileManager.default
    let base = fm.temporaryDirectory
        .appendingPathComponent("haru-prueba-\(UUID().uuidString)", isDirectory: true)
        .resolvingSymlinksInPath().path
    for e in entradas {
        let ruta = base + "/" + e
        if e.hasSuffix("/") {
            try? fm.createDirectory(atPath: ruta, withIntermediateDirectories: true)
        } else {
            try? fm.createDirectory(atPath: (ruta as NSString).deletingLastPathComponent,
                                    withIntermediateDirectories: true)
            fm.createFile(atPath: ruta, contents: Data())
        }
    }
    return base
}

func probarEscaner() {
    let fm = FileManager.default
    let raiz = armarArbol([
        // Proyectos directos.
        "tienda/package.json",
        "tienda/src/package.json",            // subcarpeta de un proyecto: no se lista
        "tienda/docs/sitio/index.html",       // tampoco más adentro
        "blog/.git/",                         // .git como carpeta
        "api-pagos/go.mod",
        "api-pagos/docker-compose.yml",
        "landing/index.html",
        "landing/compose.yaml",
        // Contenedora: no es proyecto, pero tiene proyectos adentro.
        "clientes/notas.txt",
        "clientes/inventario/composer.json",
        "clientes/reportes/pyproject.toml",
        "clientes/reportes/compose.yml",
        "clientes/vacia/",
        "clientes/profunda/nivel/package.json", // dos niveles dentro de una contenedora: no
        // Ignorados.
        ".oculto/package.json",
        "node_modules/paquete/package.json",
        "vendor/package.json",
        "build/package.json",
        "dist/package.json",
        "backup/package.json",
        "backups/package.json",
        "tienda-worktree/package.json",
        "clientes/.escondido/package.json",
        "clientes/node_modules/package.json",
        // Un archivo suelto en la raíz no es proyecto.
        "leeme.txt",
        // Cada marcador cuenta.
        "m1/composer.json", "m2/Package.swift", "m3/requirements.txt",
        "m4/Cargo.toml", "m5/Gemfile", "m6/docker-compose.yaml",
    ])

    let encontrados = Escaner.escanear(raices: [raiz])
    let relativas = encontrados.map { String($0.ruta.dropFirst(raiz.count + 1)) }
    igual(relativas, [
        "api-pagos", "blog", "clientes/inventario", "clientes/reportes", "landing",
        "m1", "m2", "m3", "m4", "m5", "m6", "tienda",
    ], "encuentra proyectos directos y dentro de contenedoras, sin ignorados ni subcarpetas")

    func docker(_ rel: String) -> Bool? {
        encontrados.first { $0.ruta == raiz + "/" + rel }?.tieneDocker
    }
    igual(docker("api-pagos"), true, "docker-compose.yml da Docker")
    igual(docker("landing"), true, "compose.yaml da Docker")
    igual(docker("clientes/reportes"), true, "compose.yml da Docker")
    igual(docker("m6"), true, "docker-compose.yaml da Docker")
    igual(docker("tienda"), false, "sin compose no hay Docker")
    igual(docker("clientes/inventario"), false, "sin compose no hay Docker (contenedora)")

    // Raíz inexistente: no corta, las demás se escanean igual.
    let conInexistente = Escaner.escanear(raices: [raiz + "/no-existe", raiz])
    igual(conInexistente.count, encontrados.count, "una raíz inexistente se saltea")
    igual(Escaner.escanear(raices: ["/no/existe/haru"]), [], "solo raíces inexistentes: nada")

    // La misma carpeta alcanzable desde dos raíces aparece una sola vez.
    let dobles = Escaner.escanear(raices: [raiz, raiz + "/"])
    igual(dobles.count, encontrados.count, "sin duplicados entre raíces")
    // Con clientes también como raíz, sus proyectos no se repiten; aparece
    // además clientes/profunda/nivel, que desde ahí está a un nivel de contenedora.
    let anidadas = Escaner.escanear(raices: [raiz, raiz + "/clientes"])
    igual(anidadas.count, encontrados.count + 1, "raíces anidadas sin duplicados")
    chequear(anidadas.contains { $0.ruta == raiz + "/clientes/profunda/nivel" },
             "desde la raíz clientes, profunda es contenedora")

    // Una carpeta ilegible no corta el escaneo.
    let cerrada = raiz + "/clientes/cerrada"
    try? fm.createDirectory(atPath: cerrada, withIntermediateDirectories: true)
    fm.createFile(atPath: cerrada + "/package.json", contents: Data())
    try? fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: cerrada)
    let conCerrada = Escaner.escanear(raices: [raiz])
    chequear(conCerrada.contains { $0.ruta == raiz + "/tienda" }, "sigue escaneando con una carpeta ilegible")
    chequear(!conCerrada.contains { $0.ruta == cerrada }, "la carpeta ilegible no se lista")
    try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cerrada)

    // Reglas de nombres ignorados.
    chequear(Escaner.ignorar(".git"), "ignora lo que empieza con punto")
    chequear(Escaner.ignorar("api-worktree"), "ignora los -worktree")
    chequear(!Escaner.ignorar("worktree-api"), "no ignora worktree al principio")
    chequear(!Escaner.ignorar("builder"), "no ignora nombres que solo empiezan como uno ignorado")

    try? fm.removeItem(atPath: raiz)
}
