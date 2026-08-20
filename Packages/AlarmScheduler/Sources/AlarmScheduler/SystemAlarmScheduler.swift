import Foundation
import AlarmCore

#if canImport(AlarmKit)
import AlarmKit
#endif

/// AlarmKit tambien exporta un tipo llamado `Alarm`, asi que dentro de este
/// paquete `Alarm` a secas es ambiguo y no compila. Usa siempre este alias para
/// referirte al nuestro. Descubierto en la fase 0 para que no lo descubras tu.
public typealias DomainAlarm = AlarmCore.Alarm

/// Implementacion real de `AlarmScheduling` sobre AlarmKit.
///
/// TAREA DEL AGENTE B. Contexto que necesitas antes de escribir nada:
///
/// - AlarmKit es la UNICA forma en iOS de que la alarma suene con la app cerrada
///   rompiendo el silencio y los modos de concentracion. Requiere iOS 26 y un
///   entitlement que Apple aprueba caso por caso. Hasta que llegue, esta clase
///   no se puede probar de verdad: trabaja contra el protocolo y usa
///   `PreviewAlarmScheduler` para el resto de la app.
/// - La interfaz de sistema de AlarmKit SIEMPRE muestra un boton "Stop" que no
///   podemos ocultar. No intentes bloquearlo. El diseno de producto ya lo asume:
///   el boton secundario abre la app para hacer el reto, y quien pulse "Stop"
///   sin completarlo pierde la racha.
/// - Los tonos solo pueden ser el sonido por defecto del sistema o ficheros del
///   bundle de maximo 30 segundos. No hay acceso a los tonos del usuario.
/// - Una vez la app esta en primer plano haciendo el reto, el sonido lo sostiene
///   la app con su propia sesion de audio: la alarma no se calla hasta que el
///   reto se completa entero, y vuelve a sonar si se abandona a mitad.
public actor SystemAlarmScheduler: AlarmScheduling {
    public init() {}

    public func authorizationState() async -> AlarmAuthorizationState { .noDeterminado }
    public func requestAuthorization() async throws -> AlarmAuthorizationState { .noDeterminado }
    public func schedule(_ alarm: DomainAlarm) async throws {}
    public func cancel(alarmID: DomainAlarm.ID) async throws {}
    public func scheduledAlarmIDs() async throws -> Set<DomainAlarm.ID> { [] }
    public func silenceCurrentAlarm() async {}
    public func resumeCurrentAlarm() async {}
}
