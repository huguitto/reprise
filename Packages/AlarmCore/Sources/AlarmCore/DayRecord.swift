import Foundation

/// Por que se perdio un despertar. Los cuatro casos son decisiones de producto
/// tomadas explicitamente, no defensas genericas.
public enum FailureReason: String, Codable, Sendable {
    /// Pulso "Stop" en la interfaz del sistema y nunca abrio la app.
    /// AlarmKit siempre muestra ese boton y no podemos ocultarlo, asi que la
    /// unica respuesta posible es penalizar despues.
    case paroSinReto
    /// Empezo el reto y lo dejo a medias.
    case abandono
    /// Mato la app o reinicio el dispositivo con el reto en marcha.
    case appTerminada
    /// La alarma sono y no hubo ninguna interaccion.
    case ignorada
}

public enum DayOutcome: Codable, Sendable, Hashable {
    case completado
    case fallado(FailureReason)
    /// Fallo, pero una vida absorbio el golpe y la racha sobrevivio.
    case salvadoPorVida(FailureReason)
}

public struct DayRecord: Identifiable, Hashable, Codable, Sendable {
    public var id: Day { day }

    public let day: Day
    public let alarmID: Alarm.ID?
    public let challenge: ChallengeType?
    public let outcome: DayOutcome
    /// Cuanto tardo en completar el reto desde que sono la alarma.
    public let duration: TimeInterval?

    public init(
        day: Day,
        alarmID: Alarm.ID?,
        challenge: ChallengeType?,
        outcome: DayOutcome,
        duration: TimeInterval? = nil
    ) {
        self.day = day
        self.alarmID = alarmID
        self.challenge = challenge
        self.outcome = outcome
        self.duration = duration
    }
}
