import Foundation

func probarVigilante() {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func en(_ segundos: TimeInterval) -> Date { t0.addingTimeInterval(segundos) }

    // Con ventana abierta no pasa nada.
    var v = Vigilante()
    v.vigilar(ruta: "/x/tienda", carpeta: "tienda")
    igual(v.ciclo(carpetasAbiertas: ["tienda"], ahora: en(0)).count, 0, "con ventana no apaga")
    igual(v.segundosRestantes("/x/tienda", ahora: en(0)), nil, "con ventana no hay cuenta")

    // Se cierra la ventana: empieza la cuenta, y a los 2 min se apaga.
    igual(v.ciclo(carpetasAbiertas: [], ahora: en(10)).count, 0, "al cerrar empieza la cuenta, no apaga")
    igual(v.segundosRestantes("/x/tienda", ahora: en(40)), 90, "quedan 90 s a los 30 s de cerrada")
    igual(v.ciclo(carpetasAbiertas: [], ahora: en(100)).count, 0, "a los 90 s todavía no apaga")
    let apagados = v.ciclo(carpetasAbiertas: [], ahora: en(130))
    igual(apagados.map(\.ruta), ["/x/tienda"], "a los 120 s apaga")
    chequear(v.estaVacio, "el apagado sale de la lista")

    // Reabrir dentro de la gracia cancela la cuenta.
    var r = Vigilante()
    r.vigilar(ruta: "/x/blog", carpeta: "blog")
    _ = r.ciclo(carpetasAbiertas: [], ahora: en(0))
    _ = r.ciclo(carpetasAbiertas: ["blog"], ahora: en(60))
    igual(r.segundosRestantes("/x/blog", ahora: en(60)), nil, "reabrir cancela la cuenta")
    igual(r.ciclo(carpetasAbiertas: [], ahora: en(150)).count, 0, "la cuenta arranca de nuevo, no apaga")

    // Si no se pudo leer VS Code, no empieza ni termina ninguna cuenta.
    var f = Vigilante()
    f.vigilar(ruta: "/x/api-pagos", carpeta: "api-pagos")
    igual(f.ciclo(carpetasAbiertas: nil, ahora: en(0)).count, 0, "lectura fallida no apaga")
    igual(f.segundosRestantes("/x/api-pagos", ahora: en(0)), nil, "lectura fallida no empieza cuenta")
    _ = f.ciclo(carpetasAbiertas: [], ahora: en(10))
    igual(f.ciclo(carpetasAbiertas: nil, ahora: en(500)).count, 0, "lectura fallida no termina una cuenta")

    // Dos proyectos con el mismo nombre de carpeta: abiertos mientras haya ventana con ese nombre.
    var d = Vigilante()
    d.vigilar(ruta: "/x/a/site", carpeta: "site")
    d.vigilar(ruta: "/x/b/site", carpeta: "site")
    _ = d.ciclo(carpetasAbiertas: ["site"], ahora: en(0))
    igual(d.ciclo(carpetasAbiertas: ["site"], ahora: en(500)).count, 0, "nombre repetido con ventana: no apaga ninguno")

    // Volver a vigilar el mismo proyecto no lo duplica y reinicia su estado.
    var g = Vigilante()
    g.vigilar(ruta: "/x/k", carpeta: "k")
    _ = g.ciclo(carpetasAbiertas: [], ahora: en(0))
    g.vigilar(ruta: "/x/k", carpeta: "k")
    igual(g.vigilados.count, 1, "vigilar dos veces no duplica")
    igual(g.segundosRestantes("/x/k", ahora: en(0)), nil, "vigilar de nuevo reinicia la cuenta")
    g.dejarDeVigilar("/x/k")
    chequear(g.estaVacio, "dejar de vigilar lo saca")

    // Un proyecto con una acción en curso (p. ej. abriéndose) no se apaga ni se toca.
    var x = Vigilante()
    x.vigilar(ruta: "/x/tienda", carpeta: "tienda")
    x.vigilar(ruta: "/x/blog", carpeta: "blog")
    _ = x.ciclo(carpetasAbiertas: [], ahora: en(0))
    let fuera = x.ciclo(carpetasAbiertas: [], ahora: en(200), excluir: ["/x/tienda"])
    igual(fuera.map(\.ruta), ["/x/blog"], "el excluido no se apaga; el otro sí")
    igual(x.vigilados.map(\.ruta), ["/x/tienda"], "el excluido sigue vigilado")
    igual(x.segundosRestantes("/x/tienda", ahora: en(200)), 0, "el excluido conserva su cuenta")
    var y = Vigilante()
    y.vigilar(ruta: "/x/k", carpeta: "k")
    _ = y.ciclo(carpetasAbiertas: [], ahora: en(0), excluir: ["/x/k"])
    igual(y.segundosRestantes("/x/k", ahora: en(0)), nil, "un excluido recién abierto no empieza cuenta")
    igual(y.ciclo(carpetasAbiertas: [], ahora: en(500), excluir: ["/x/k"]).count, 0,
          "mientras esté excluido no se apaga nunca")

    // Se guarda y se recupera igual, con la cuenta en curso.
    var p = Vigilante()
    p.vigilar(ruta: "/x/tienda", carpeta: "tienda")
    _ = p.ciclo(carpetasAbiertas: [], ahora: en(0))
    let datos = try? JSONEncoder().encode(p)
    let recuperado = datos.flatMap { try? JSONDecoder().decode(Vigilante.self, from: $0) }
    igual(recuperado, p, "se recupera desde disco con la cuenta en curso")
}
