import Foundation
import AlarmCore

/// La peticion que deja el boton secundario de la alerta al abrir la app.
public struct ChallengeRequest: Codable, Sendable, Hashable {
    public let alarmID: DomainAlarm.ID
    public let challenge: ChallengeType
    public let requestedAt: Date

    public init(alarmID: DomainAlarm.ID, challenge: ChallengeType, requestedAt: Date) {
        self.alarmID = alarmID
        self.challenge = challenge
        self.requestedAt = requestedAt
    }
}

/// Buzon entre el boton de la alerta del sistema y la app.
///
/// El `AppIntent` del boton secundario corre en el proceso de la app, pero
/// antes de que exista pantalla ninguna. Deja aqui que alarma ha sonado y con
/// que reto; la app lo lee al arrancar y abre el reto que toca.
///
/// No sustituye a `PendingChallenge`: aquel es el rastro en disco que sirve para
/// penalizar a quien mata la app a mitad, y lo escribe la app. Este es solo un
/// recado, y se consume nada mas leerlo.
public enum ChallengeInbox {
    private static let clave = "reprise.reto-solicitado"

    public static func post(_ request: ChallengeRequest, to defaults: UserDefaults = .standard) {
        guard let datos = try? JSONEncoder().encode(request) else { return }
        defaults.set(datos, forKey: clave)
    }

    /// Lee sin consumir.
    public static func peek(in defaults: UserDefaults = .standard) -> ChallengeRequest? {
        guard let datos = defaults.data(forKey: clave) else { return nil }
        return try? JSONDecoder().decode(ChallengeRequest.self, from: datos)
    }

    /// Lee y borra. Un recado se atiende una vez.
    public static func consume(from defaults: UserDefaults = .standard) -> ChallengeRequest? {
        let peticion = peek(in: defaults)
        clear(in: defaults)
        return peticion
    }

    public static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: clave)
    }
}
