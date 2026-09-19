import Foundation

func probarModelos() {
    let p = Proyecto(ruta: "/Users/ana/Projects/tienda/", tieneDocker: true)
    igual(p.ruta, "/Users/ana/Projects/tienda", "la ruta queda sin barra final")
    igual(p.id, "/Users/ana/Projects/tienda", "el id es la ruta")
    igual(p.nombre, "tienda", "el nombre es el de la carpeta")
    igual(p.usos, 0, "sin usos por defecto")
    igual(p.ultimoUso, nil, "sin último uso por defecto")
    chequear(!p.favorito, "no es favorito por defecto")

    igual(normalizarRuta("/Users/ana/tienda/"), "/Users/ana/tienda", "saca la barra final")
    igual(normalizarRuta("/Users/ana/tienda"), "/Users/ana/tienda", "deja igual una ruta limpia")
    igual(normalizarRuta("/"), "/", "la raíz queda igual")
    igual(normalizarRuta(""), "", "vacía queda vacía")
}
