import Foundation

/// Fallos al programar o sostener una alarma.
///
/// Todos llevan `mensaje` en espanol porque acaban en pantalla: una alarma que
/// no se programa y no lo dice es peor que una alarma que no existe.
///
/// AlarmKit reparte sus fallos en tres sitios —pedir el permiso, consultar lo
/// que hay puesto y programar— y solo tiene **un** error propio con nombre
/// (`maximumLimitReached`). Todo lo demas llega como un `NSError` opaco del
/// estilo `Error Domain=com.apple.AlarmKit code=0 "(null)"`. Por eso hay un
/// caso por operacion en vez de uno solo: con uno solo, tropezar al *consultar*
/// se le contaba al usuario como "no se ha podido programar la alarma", que es
/// mentira y ademas la peor mentira posible —le dice que no va a sonar algo que
/// si esta puesto.
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
    /// Fallo al programar. Este si deja al usuario sin despertador.
    case fallaDeAlarmKit(descripcion: String)
    /// Fallo al preguntarle al sistema que alarmas tiene puestas. No impide
    /// programar: solo impide saber que hay que limpiar.
    case noSePudoConsultarElSistema(descripcion: String)
    /// Fallo al pedir el permiso, que no es lo mismo que denegarlo.
    case falloAlPedirPermiso(descripcion: String)

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
        case let .noSePudoConsultarElSistema(descripcion):
            "El sistema no ha dicho qué alarmas tiene puestas: \(descripcion)"
        case let .falloAlPedirPermiso(descripcion):
            "No se ha podido pedir el permiso de alarmas: \(descripcion)"
        }
    }
}
