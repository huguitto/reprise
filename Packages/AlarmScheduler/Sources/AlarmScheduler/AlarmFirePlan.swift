import Foundation
import AlarmCore

/// Cuando tiene que sonar una alarma, ya validado y sin tipos de AlarmKit.
///
/// Existe para poder probar en el host la parte que se rompe en silencio (el
/// desfase de dias de la semana, una hora imposible) sin necesitar iPhone,
/// entitlement ni simulador. La traduccion a `AlarmKit.Alarm.Schedule` es la
/// linea de al lado, en `SystemAlarmScheduler`.
public struct AlarmFirePlan: Sendable, Hashable {
    public let hour: Int
    public let minute: Int
    /// Ordenados de lunes a domingo. Vacio = alarma de un solo uso: suena la
    /// proxima vez que el reloj pase por esa hora.
    public let weekdays: [Weekday]

    public init(alarm: DomainAlarm) throws {
        guard (0...23).contains(alarm.hour), (0...59).contains(alarm.minute) else {
            throw AlarmSchedulerError.horaInvalida(hour: alarm.hour, minute: alarm.minute)
        }
        self.hour = alarm.hour
        self.minute = alarm.minute
        self.weekdays = alarm.weekdays.sorted()
    }

    public var repeats: Bool { !weekdays.isEmpty }

    /// Los mismos dias en el tipo que pide AlarmKit.
    public var localeWeekdays: [Locale.Weekday] { weekdays.map(\.localeWeekday) }
}
