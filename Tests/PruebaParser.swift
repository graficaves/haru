import Foundation

private let salidaReal = """
Version:          Code 1.137.0 (645f29cc3176500b4b5762ba887cf2a7f0ffdf2c, 2026-09-08T13:43:59-07:00)
OS Version:       Darwin arm64 25.5.0

CPU %\tMem MB\t   PID\tProcess
    0\t11258999068\t 87650\twindow [37] (Gran problema — blog)

Workspace Stats:
|  Window (Panel principal — tienda)
|  Window (carrito vacío — api-pagos)
|  Window (Gran problema — blog)
|  Window (Usuario nuevo, error… — Comercio-Web)
|  Window (inventario)
|    Folder (tienda): 34 files
|      File types: js(19) md(3) json(2) env(1) gitignore(1) db(1) db-shm(1)
|                  db-wal(1) log(1) css(1) other(3)
|      Conf files: package.json(1)
|    Folder (Comercio-Web): 354 files
|    Folder (reportes-docker): 13582 files
|    Folder (api-pagos): more than 20000 files

"""

func probarParser() {
    let carpetas = ParserCodeStatus.carpetasAbiertas(salidaReal)
    igual(carpetas, [
        "tienda", "api-pagos", "blog", "Comercio-Web", "inventario", "reportes-docker",
        "Panel principal", "carrito vacío", "Gran problema", "Usuario nuevo, error…",
    ], "junta todas las partes de títulos de ventana y las líneas Folder")

    igual(ParserCodeStatus.carpetasAbiertas("Warning: algo raro\n"), nil,
          "sin Workspace Stats no se sabe nada: nil, no vacío")

    igual(ParserCodeStatus.carpetasAbiertas("Workspace Stats: \n"), Set<String>(),
          "Workspace Stats sin ventanas es el conjunto vacío")

    igual(ParserCodeStatus.carpetasAbiertas("Workspace Stats:\n|  Window (a — b — mi-carpeta)\n"),
          ["a", "b", "mi-carpeta"], "se guardan todas las partes del título")

    igual(ParserCodeStatus.carpetasAbiertas("Workspace Stats:\n|  Window (app.js — mi-carpeta — Perfil Trabajo)\n"),
          ["app.js", "mi-carpeta", "Perfil Trabajo"],
          "con un sufijo de perfil la carpeta igual queda retenida")
}
