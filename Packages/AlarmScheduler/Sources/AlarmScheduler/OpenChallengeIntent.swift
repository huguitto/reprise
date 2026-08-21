import Foundation
import AlarmCore

#if canImport(AlarmKit)
import AppIntents

/// Lo que hace el boton secundario de la alerta del sistema: abrir la app con
/// el reto de esa alarma.
///
/// Es el paso 2 del flujo, el inevitable: con la app cerrada no corre nuestro
/// codigo y no hay sensores, asi que alguien tiene que traer la app al frente.
/// El intent no arranca el reto ni toca la racha; solo deja el recado en
/// `ChallengeInbox` y abre la app, que es la que decide.
@available(iOS 26.0, *)
public struct OpenChallengeIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Hacer el reto"
    public static let description = IntentDescription(
        "Abre RepRise para completar el reto y apagar la alarma."
    )
    /// El recado tiene que existir **antes** de que la app termine de volver al
    /// frente. Con `.immediate`, iOS abre la app antes de llamar a `perform()`:
    /// en un arranque en frio la raiz puede mirar el buzon aun vacio y quedarse
    /// en la lista de alarmas hasta el siguiente toque. `.deferred` ejecuta la
    /// escritura primero y lleva la app al frente antes de que termine el
    /// intent, cerrando esa carrera sin retrasar trabajo real.
    public static var supportedModes: IntentModes { .foreground(.deferred) }
    /// Que no aparezca en Atajos ni en Spotlight: no tiene sentido fuera de la
    /// alerta de una alarma.
    public static var isDiscoverable: Bool { false }

    @Parameter(title: "Alarma")
    public var alarmID: String

    @Parameter(title: "Reto")
    public var challengeID: String

    public init() {}

    public init(alarm: DomainAlarm) {
        self.alarmID = alarm.id.uuidString
        self.challengeID = alarm.challenge.rawValue
    }

    public func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID), let reto = ChallengeType(rawValue: challengeID) {
            ChallengeInbox.post(
                ChallengeRequest(alarmID: id, challenge: reto, requestedAt: Date())
            )
        }
        return .result()
    }
}

/// AppIntents no descubre por su cuenta los intents que viven en un paquete: el
/// target de la app tiene que declararlos suyos. Ver el README del paquete.
@available(iOS 26.0, *)
public struct AlarmSchedulerAppIntents: AppIntentsPackage {}
#endif
