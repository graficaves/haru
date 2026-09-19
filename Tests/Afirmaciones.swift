import Foundation

// Banco de pruebas mínimo: las Command Line Tools no traen XCTest usable
// sin Xcode, así que las pruebas son un ejecutable que cuenta fallas.
var fallas = 0
var chequeos = 0

func chequear(_ condicion: @autoclosure () -> Bool, _ mensaje: String,
              file: StaticString = #file, line: UInt = #line) {
    chequeos += 1
    if !condicion() {
        fallas += 1
        print("✗ \(mensaje) (\(file):\(line))")
    }
}

func igual<T: Equatable>(_ obtenido: T, _ esperado: T, _ mensaje: String,
                         file: StaticString = #file, line: UInt = #line) {
    chequear(obtenido == esperado, "\(mensaje): se obtuvo \(obtenido), se esperaba \(esperado)",
             file: file, line: line)
}
