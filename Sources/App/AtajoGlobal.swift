import AppKit
import Carbon.HIToolbox

/// Identificador propio del atajo. Vive fuera del enum porque el handler de
/// Carbon es un puntero a función de C y no puede capturar contexto.
private let idAtajoHaru: UInt32 = 1
private let firmaHaru: OSType = 0x48415255 // 'HARU'
private var accionAtajoHaru: (() -> Void)?
private var referenciaAtajoHaru: EventHotKeyRef?

/// Atajo global ⌥⌘P. Usa Carbon en lugar de `NSEvent.addGlobalMonitor`
/// porque este no pide permiso de Accesibilidad: Carbon solo recibe esa
/// combinación, sin ver el resto del teclado.
enum AtajoGlobal {
    @discardableResult
    static func registrar(accion: @escaping () -> Void) -> Bool {
        accionAtajoHaru = accion

        var tipo = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), manejarAtajoHaru, 1, &tipo, nil, nil)

        let identificador = EventHotKeyID(signature: firmaHaru, id: idAtajoHaru)
        let estado = RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(optionKey | cmdKey),
                                         identificador, GetApplicationEventTarget(), 0,
                                         &referenciaAtajoHaru)
        if estado != noErr {
            NSLog("[Haru] no pude registrar ⌥⌘P (código %d): puede estar tomado por otra app", Int(estado))
            return false
        }
        NSLog("[Haru] atajo ⌥⌘P registrado")
        return true
    }
}

private func manejarAtajoHaru(_ llamador: EventHandlerCallRef?, _ evento: EventRef?,
                              _ datos: UnsafeMutableRawPointer?) -> OSStatus {
    var id = EventHotKeyID()
    GetEventParameter(evento, EventParamName(kEventParamDirectObject),
                      EventParamType(typeEventHotKeyID), nil,
                      MemoryLayout<EventHotKeyID>.size, nil, &id)
    if id.id == idAtajoHaru {
        DispatchQueue.main.async { accionAtajoHaru?() }
    }
    return noErr
}
