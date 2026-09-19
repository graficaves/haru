import Foundation

struct Resultado {
    let codigo: Int32
    let stdout: String
    let stderr: String

    var ok: Bool { codigo == 0 }

    /// Texto para mostrar cuando falla: stderr si hay, si no stdout.
    var error: String {
        let e = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.isEmpty ? stdout.trimmingCharacters(in: .whitespacesAndNewlines) : e
    }
}

struct ErrorHaru: LocalizedError {
    let mensaje: String
    var errorDescription: String? { mensaje }
}

/// Corre comandos externos. Una app abierta desde Finder o al iniciar sesión
/// no hereda el PATH de la shell, así que se arma uno con los lugares donde
/// suelen instalarse docker (y sus plugins) y code.
enum Ejecutor {
    static let path = [
        "/usr/local/bin", "/opt/homebrew/bin",
        NSHomeDirectory() + "/bin",
        NSHomeDirectory() + "/.docker/bin",
        "/Applications/Docker.app/Contents/Resources/bin",
        "/Applications/Visual Studio Code.app/Contents/Resources/app/bin",
        NSHomeDirectory() + "/Applications/Visual Studio Code.app/Contents/Resources/app/bin",
        "/usr/bin", "/bin", "/usr/sbin", "/sbin",
    ].joined(separator: ":")

    static func correr(_ argumentos: [String], en carpeta: String? = nil,
                       limite: TimeInterval = 180) async -> Resultado {
        await withCheckedContinuation { continuacion in
            DispatchQueue.global().async {
                continuacion.resume(returning: correrBloqueando(argumentos, en: carpeta, limite: limite))
            }
        }
    }

    /// Corre el comando y espera a que termine, con un tope garantizado: al
    /// vencer `limite` mata el grupo de procesos y vuelve aunque algún nieto
    /// (p. ej. el Electron que lanza el script `code`) siga con los pipes abiertos.
    private static func correrBloqueando(_ argumentos: [String], en carpeta: String?,
                                         limite: TimeInterval) -> Resultado {
        let proceso = Process()
        proceso.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proceso.arguments = argumentos
        var entorno = ProcessInfo.processInfo.environment
        entorno["PATH"] = path
        proceso.environment = entorno
        if let carpeta { proceso.currentDirectoryURL = URL(fileURLWithPath: carpeta) }
        let salida = Pipe()
        let errores = Pipe()
        proceso.standardOutput = salida
        proceso.standardError = errores
        proceso.standardInput = FileHandle.nullDevice
        let termino = DispatchSemaphore(value: 0)
        proceso.terminationHandler = { _ in termino.signal() }
        do {
            try proceso.run()
        } catch {
            return Resultado(codigo: -1, stdout: "", stderr: error.localizedDescription)
        }
        // En macOS, Process lanza al hijo como líder de su propio grupo de
        // procesos (pgid == pid): matar el grupo alcanza también a los nietos,
        // aunque el hijo ya haya terminado.
        let pid = proceso.processIdentifier
        func matarGrupo(_ senal: Int32) {
            killpg(pid, senal)
            if proceso.isRunning { kill(pid, senal) }
        }

        // Los dos pipes se leen en paralelo: si el buffer de uno se llenara
        // mientras se espera el otro, el proceso quedaría trabado escribiendo.
        let lecturas = Lecturas()
        let grupo = DispatchGroup()
        for (pipe, esSalida) in [(salida, true), (errores, false)] {
            grupo.enter()
            DispatchQueue.global().async {
                let datos = pipe.fileHandleForReading.readDataToEndOfFile()
                lecturas.guardar(datos, esSalida: esSalida)
                grupo.leave()
            }
        }

        let agotado = grupo.wait(timeout: .now() + limite) == .timedOut
        if agotado {
            matarGrupo(SIGTERM)
            // Si en un par de segundos no terminó, a la fuerza.
            if termino.wait(timeout: .now() + 2) == .timedOut { matarGrupo(SIGKILL) }
            // Da un momento para que los lectores cierren; si algún proceso
            // fuera del grupo sigue con los pipes, se vuelve igual sin esperar.
            _ = grupo.wait(timeout: .now() + 2)
            let comando = argumentos.joined(separator: " ")
            return Resultado(codigo: -1, stdout: "",
                             stderr: "se agotó el tiempo (\(Int(limite)) s) esperando `\(comando)`")
        }
        // Los pipes cerraron; el proceso termina enseguida.
        if termino.wait(timeout: .now() + 5) == .timedOut {
            matarGrupo(SIGKILL)
            _ = termino.wait(timeout: .now() + 2)
        }
        let (datos, datosError) = lecturas.valores()
        return Resultado(codigo: proceso.isRunning ? -1 : proceso.terminationStatus,
                         stdout: String(decoding: datos, as: UTF8.self),
                         stderr: String(decoding: datosError, as: UTF8.self))
    }
}

/// Lo leído de stdout y stderr, compartido con los hilos lectores.
private final class Lecturas: @unchecked Sendable {
    private let cerrojo = NSLock()
    private var salida = Data()
    private var errores = Data()

    func guardar(_ datos: Data, esSalida: Bool) {
        cerrojo.lock(); defer { cerrojo.unlock() }
        if esSalida { salida = datos } else { errores = datos }
    }

    func valores() -> (Data, Data) {
        cerrojo.lock(); defer { cerrojo.unlock() }
        return (salida, errores)
    }
}
