import Foundation
import Testing
import AlarmCore
@testable import Persistence

/// Un fichero de almacen de usar y tirar.
///
/// Buena parte de lo que hay que probar aqui solo se ve con fichero de verdad:
/// "cerrar la app y reabrirla conserva la racha" no se puede comprobar en
/// memoria, porque en memoria no hay nada que reabrir.
final class AlmacenTemporal {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appending(path: "reprise-pruebas-\(UUID().uuidString).store")
    }

    /// Abre el almacen. Llamarlo dos veces sobre el mismo fichero es justo lo
    /// que hace la app al cerrarse y volver a abrirse.
    func abrir() throws -> AlmacenSwiftData {
        try Persistence.almacen(url: url)
    }

    deinit {
        let gestor = FileManager.default
        for sufijo in ["", "-shm", "-wal"] {
            try? gestor.removeItem(at: URL(fileURLWithPath: url.path + sufijo))
        }
    }
}

func dia(_ d: Int, mes: Int = 8, ano: Int = 2026) -> Day {
    Day(year: ano, month: mes, day: d)
}

func alarmaDePrueba(
    id: UUID = UUID(),
    hora: Int = 7,
    minuto: Int = 30,
    dias: Set<Weekday> = [.lunes, .miercoles],
    reto: ChallengeType = .pasos,
    activa: Bool = true,
    creadaEn: Date = Date()
) -> Alarm {
    Alarm(id: id, hour: hora, minute: minuto, weekdays: dias, challenge: reto,
          toneID: "sistema", label: "Trabajo", isEnabled: activa, creadaEn: creadaEn)
}
