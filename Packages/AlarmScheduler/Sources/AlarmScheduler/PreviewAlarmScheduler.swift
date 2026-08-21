import Foundation
import AlarmCore

/// Programador en memoria para simulador, previews y tests.
///
/// No es un sustituto a la espera de nada —la app monta `SystemAlarmScheduler`
/// y suena—: es la otra mitad del protocolo, para donde AlarmKit no tiene con
/// que sonar. En el simulador no hay alarma que dar.
public actor PreviewAlarmScheduler: AlarmScheduling {
    private var scheduled: Set<DomainAlarm.ID> = []
    private var state: AlarmAuthorizationState
    public private(set) var isSounding = false

    public init(authorization: AlarmAuthorizationState = .autorizado) {
        self.state = authorization
    }

    public func authorizationState() async -> AlarmAuthorizationState { state }

    public func requestAuthorization() async throws -> AlarmAuthorizationState {
        if state == .noDeterminado { state = .autorizado }
        return state
    }

    public func schedule(_ alarm: DomainAlarm) async throws { scheduled.insert(alarm.id) }
    public func cancel(alarmID: DomainAlarm.ID) async throws { scheduled.remove(alarmID) }
    public func scheduledAlarmIDs() async throws -> Set<DomainAlarm.ID> { scheduled }
    public func silenceCurrentAlarm() async { isSounding = false }
    public func resumeCurrentAlarm() async { isSounding = true }
}
