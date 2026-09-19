import Foundation

func probarPreferencias() {
    let home = "/Users/ana"

    // Por defecto: las raíces habituales que existan, y siempre el home.
    let existentes: Set<String> = ["/Users/ana/Projects", "/Users/ana/code"]
    let def = Preferencias.porDefecto(home: home, existe: { existentes.contains($0) })
    igual(def.raices, ["~/Projects", "~/code", "~"], "raíces por defecto: las que existen más el home")
    igual(def.raicesExpandidas(home: home), ["/Users/ana/Projects", "/Users/ana/code", "/Users/ana"],
          "expande ~")
    chequear(def.favoritos.isEmpty && def.usos.isEmpty && def.ocultos.isEmpty && def.ultimoUso.isEmpty,
             "arranca sin favoritos, usos ni ocultos")
    igual(Preferencias.porDefecto(home: home, existe: { _ in false }).raices, ["~"],
          "sin carpetas habituales queda solo el home")

    igual(Preferencias.expandir("~", home: home), "/Users/ana", "~ solo es el home")
    igual(Preferencias.expandir("~/dev", home: home), "/Users/ana/dev", "~/ se expande")
    igual(Preferencias.expandir("/opt/src", home: home), "/opt/src", "una ruta absoluta queda igual")
    igual(Preferencias.expandir("~otro/x", home: home), "~otro/x", "~usuario no se toca")

    // Combinación con el escaneo.
    let fecha = Date(timeIntervalSince1970: 1_800_000_000)
    var p = Preferencias(raices: ["~"])
    p.alternarFavorito("/Users/ana/blog")
    p.registrarUso("/Users/ana/tienda", fecha: fecha)
    p.registrarUso("/Users/ana/tienda/", fecha: fecha)
    p.ocultar("/Users/ana/viejo")
    let encontrados = [
        Encontrado(ruta: "/Users/ana/blog", tieneDocker: false),
        Encontrado(ruta: "/Users/ana/tienda", tieneDocker: true),
        Encontrado(ruta: "/Users/ana/viejo", tieneDocker: true),
    ]
    let lista = p.proyectos(de: encontrados)
    igual(lista.map(\.nombre), ["blog", "tienda"], "los ocultos no aparecen")
    igual(lista.first { $0.nombre == "blog" }?.favorito, true, "aplica favoritos")
    igual(lista.first { $0.nombre == "tienda" }?.usos, 2, "aplica usos (la barra final no importa)")
    igual(lista.first { $0.nombre == "tienda" }?.ultimoUso, fecha, "aplica último uso")
    igual(lista.first { $0.nombre == "tienda" }?.tieneDocker, true, "conserva tieneDocker del escaneo")
    igual(p.cantidadOcultos(en: encontrados), 1, "cuenta los ocultos encontrados")

    p.alternarFavorito("/Users/ana/blog")
    chequear(p.favoritos.isEmpty, "alternar dos veces saca el favorito")
    p.mostrarOcultos()
    igual(p.proyectos(de: encontrados).count, 3, "mostrar ocultos los devuelve a la lista")

    // Ida y vuelta por JSON.
    var q = Preferencias(raices: ["~/Projects", "/opt/src"])
    q.alternarFavorito("/opt/src/api-pagos")
    q.registrarUso("/opt/src/api-pagos", fecha: fecha)
    q.ocultar("/opt/src/viejo")
    let recuperada = (try? q.codificar()).flatMap { try? Preferencias.decodificar($0) }
    igual(recuperada, q, "ida y vuelta por JSON")

    // Un JSON con campos faltantes no se pierde entero.
    let parcial = try? Preferencias.decodificar(Data(#"{"raices":["~/dev"]}"#.utf8))
    igual(parcial?.raices, ["~/dev"], "lee las raíces de un JSON parcial")
    igual(parcial?.usos, [:], "lo que falta toma el valor por defecto")
    igual(try? Preferencias.decodificar(Data("no es json".utf8)), nil, "un JSON roto no se decodifica")
}
