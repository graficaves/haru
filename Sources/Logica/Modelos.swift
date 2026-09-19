import Foundation

/// Una carpeta de proyecto encontrada en el disco. Su identidad es la ruta
/// absoluta; favorito y usos vienen de las preferencias guardadas.
struct Proyecto: Identifiable, Equatable, Hashable {
    /// Ruta absoluta, sin barra final.
    let ruta: String
    /// Nombre de la carpeta. Es también lo único que VS Code muestra de ella
    /// en `code --status`, así que sirve para saber si tiene ventana abierta.
    let nombre: String
    let tieneDocker: Bool
    var favorito: Bool
    var usos: Int
    var ultimoUso: Date?

    var id: String { ruta }

    init(ruta: String, tieneDocker: Bool, favorito: Bool = false,
         usos: Int = 0, ultimoUso: Date? = nil) {
        let limpia = normalizarRuta(ruta)
        self.ruta = limpia
        self.nombre = (limpia as NSString).lastPathComponent
        self.tieneDocker = tieneDocker
        self.favorito = favorito
        self.usos = usos
        self.ultimoUso = ultimoUso
    }
}

/// Ruta sin barra final, para comparar la del escaneo con la que informa Docker.
func normalizarRuta(_ ruta: String) -> String {
    var r = ruta
    while r.count > 1 && r.hasSuffix("/") { r.removeLast() }
    return r
}
