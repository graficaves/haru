import Foundation

private func proyecto(_ nombre: String, usos: Int = 0, favorito: Bool = false,
                      ultimoUso: Date? = nil) -> Proyecto {
    Proyecto(ruta: "/x/\(nombre)", tieneDocker: true, favorito: favorito,
             usos: usos, ultimoUso: ultimoUso)
}

func probarOrden() {
    let lista = [
        proyecto("tienda", usos: 2),
        proyecto("blog", usos: 9),
        proyecto("gestión-precios", usos: 1, favorito: true),
        proyecto("api-pagos", usos: 2, ultimoUso: Date(timeIntervalSince1970: 1_000)),
        proyecto("landing"),
    ]

    let s = Orden.secciones(lista, abiertos: ["/x/tienda"], busqueda: "")
    igual(s.abiertos.map(\.nombre), ["tienda"], "los abiertos van aparte")
    igual(s.favoritos.map(\.nombre), ["gestión-precios"], "los favoritos no abiertos van aparte")
    igual(s.resto.map(\.nombre), ["blog", "api-pagos", "landing"],
          "el resto por usos; a igualdad, el usado más recientemente")
    igual(s.todos.map(\.nombre), ["tienda", "gestión-precios", "blog", "api-pagos", "landing"],
          "todos respeta el orden de pantalla")

    let b = Orden.secciones(lista, abiertos: [], busqueda: "gestion")
    igual(b.todos.map(\.nombre), ["gestión-precios"], "busca sin tildes")

    let c = Orden.secciones(lista, abiertos: [], busqueda: "PRECIOS")
    igual(c.todos.map(\.nombre), ["gestión-precios"], "busca sin mayúsculas")

    let d = Orden.secciones(lista, abiertos: [], busqueda: "  ")
    igual(d.todos.count, 5, "una búsqueda en blanco no filtra")

    // Mismo nombre en dos carpetas distintas: desempata la ruta.
    let dobles = [Proyecto(ruta: "/b/site", tieneDocker: false),
                  Proyecto(ruta: "/a/site", tieneDocker: false)]
    igual(Orden.secciones(dobles, abiertos: [], busqueda: "").todos.map(\.ruta),
          ["/a/site", "/b/site"], "a igual nombre, ordena por ruta")
}
