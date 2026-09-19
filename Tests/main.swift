import Foundation

probarModelos()
probarParser()
probarOrden()
probarVigilante()
probarEscaner()

if fallas > 0 {
    print("✗ \(fallas) de \(chequeos) chequeos fallaron")
    exit(1)
}
print("✓ \(chequeos) chequeos pasaron")
