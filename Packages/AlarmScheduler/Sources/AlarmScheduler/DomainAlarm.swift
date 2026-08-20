import Foundation
import AlarmCore

/// AlarmKit tambien exporta un tipo llamado `Alarm`, asi que dentro de este
/// paquete `Alarm` a secas es ambiguo y no compila. Usa siempre este alias para
/// referirte al nuestro. Descubierto en la fase 0 para que no lo descubras tu.
public typealias DomainAlarm = AlarmCore.Alarm

extension Weekday {
    /// AlarmKit pide los dias como `Locale.Weekday`. La conversion se escribe
    /// una sola vez y aqui: es el sitio clasico donde se cuela un dia de
    /// desfase y la alarma suena el dia equivocado.
    var localeWeekday: Locale.Weekday {
        switch self {
        case .lunes: .monday
        case .martes: .tuesday
        case .miercoles: .wednesday
        case .jueves: .thursday
        case .viernes: .friday
        case .sabado: .saturday
        case .domingo: .sunday
        }
    }
}
