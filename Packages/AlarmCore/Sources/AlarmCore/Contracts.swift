import Foundation

// Contratos compartidos entre modulos.
//
// REGLA DEL REPOSITORIO: si eres un agente y necesitas cambiar algo de este
// fichero, PARA y preguntalo. Todos los modulos compilan contra estos tipos;
// cambiarlos por tu cuenta rompe el trabajo de los otros tres agentes.

// MARK: - Programacion de alarmas (lo implementa AlarmScheduler)

public enum AlarmAuthorizationState: Sendable, Hashable {
    case noDeterminado
    case autorizado
    case denegado
}

public protocol AlarmScheduling: Sendable {
    func authorizationState() async -> AlarmAuthorizationState
    @discardableResult
    func requestAuthorization() async throws -> AlarmAuthorizationState

    func schedule(_ alarm: Alarm) async throws
    func cancel(alarmID: Alarm.ID) async throws
    func scheduledAlarmIDs() async throws -> Set<Alarm.ID>

    /// Silencia el sonido en curso. Solo debe llamarse cuando el reto se ha
    /// completado entero: por decision de producto la alarma no se calla antes.
    func silenceCurrentAlarm() async
    /// Vuelve a sonar tras un abandono a mitad de reto.
    func resumeCurrentAlarm() async
}

// MARK: - Persistencia (lo implementa Persistence)

public protocol AlarmRepository: Sendable {
    func all() async throws -> [Alarm]
    func save(_ alarm: Alarm) async throws
    func delete(id: Alarm.ID) async throws
}

public protocol StreakRepository: Sendable {
    func load() async throws -> StreakState
    func save(_ state: StreakState) async throws
}

public protocol DayRecordRepository: Sendable {
    func records(from: Day, to: Day) async throws -> [DayRecord]
    func save(_ record: DayRecord) async throws
}

// MARK: - Sesion de reto en curso (lo implementa la App, lo persiste Persistence)

/// Rastro en disco de un reto empezado.
///
/// Existe para un solo caso: si el usuario mata la app o reinicia el movil a
/// mitad del reto, al volver a abrir encontramos este rastro sin cerrar y
/// sabemos que hay que penalizar. Sin el, matar la app seria la forma trivial
/// de saltarse el despertador.
public struct PendingChallenge: Codable, Sendable, Hashable {
    public let alarmID: Alarm.ID
    public let challenge: ChallengeType
    public let day: Day
    public let startedAt: Date

    public init(alarmID: Alarm.ID, challenge: ChallengeType, day: Day, startedAt: Date) {
        self.alarmID = alarmID
        self.challenge = challenge
        self.day = day
        self.startedAt = startedAt
    }
}

public protocol PendingChallengeRepository: Sendable {
    func current() async throws -> PendingChallenge?
    func begin(_ pending: PendingChallenge) async throws
    func clear() async throws
}
