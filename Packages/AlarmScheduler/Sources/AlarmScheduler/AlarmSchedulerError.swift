import Foundation

/// Fallos al programar o sostener una alarma.
///
/// Todos llevan `mensaje` en espanol porque acaban en pantalla: una alarma que
/// no se programa y no lo dice es peor que una alarma que no existe.
public enum AlarmSchedulerError: Error, Sendable, Hashable {
    /// El usuario dijo que no. Desde iOS no se puede volver a preguntar: solo
    /// queda mandarle a Ajustes.
    case sinAutorizacion
    /// Todavia no se ha pedido permiso. Pide antes de programar.
    case autorizacionPendiente
    /// Compilado sin AlarmKit (host de desarrollo, macOS). Usa
    /// `PreviewAlarmScheduler`.
    case alarmKitNoDisponible
    /// AlarmKit no admite mas alarmas simultaneas.
    case limiteDeAlarmasAlcanzado
    case horaInvalida(hour: Int, minute: Int)
    case fallaDeAlarmKit(descripcion: String)

    public var mensaje: String {
        switch self {
        case .sinAutorizacion:
            "RepRise no tiene permiso para poner alarmas. Sin ese permiso no puede despertarte."
        case .autorizacionPendiente:
            "Falta conceder el permiso de alarmas."
        case .alarmKitNoDisponible:
            "Las alarmas del sistema no están disponibles en este entorno."
        case .limiteDeAlarmasAlcanzado:
            "Has llegado al máximo de alarmas que iOS permite tener programadas a la vez."
        case let .horaInvalida(hour, minute):
            "La hora \(hour):\(minute) no existe."
        case let .fallaDeAlarmKit(descripcion):
            "El sistema no ha podido programar la alarma: \(descripcion)"
        }
    }
}
