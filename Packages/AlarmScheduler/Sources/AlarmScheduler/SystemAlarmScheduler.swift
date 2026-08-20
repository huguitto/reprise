import Foundation
import os
import AlarmCore

#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import ActivityKit
import SwiftUI
#endif

/// Implementacion real de `AlarmScheduling` sobre AlarmKit.
///
/// Contexto que hace falta para leer esto:
///
/// - AlarmKit es la UNICA forma en iOS de que la alarma suene con la app cerrada
///   rompiendo el silencio y los modos de concentracion. Requiere iOS 26 y un
///   entitlement que Apple aprueba caso por caso. **Todavia no lo tenemos**, asi
///   que nada de este fichero se ha visto funcionar: la app usa
///   `PreviewAlarmScheduler` hasta que llegue.
/// - La interfaz de sistema de AlarmKit SIEMPRE muestra un boton "Stop" que no
///   podemos ocultar. El diseno de producto ya lo asume: el boton secundario
///   abre la app para hacer el reto, y quien pulse "Stop" sin completarlo pierde
///   la racha.
/// - Los tonos solo pueden ser el sonido por defecto del sistema o ficheros del
///   bundle de maximo 30 segundos. No hay acceso a los tonos del usuario.
/// - Una vez la app esta en primer plano haciendo el reto, el sonido lo sostiene
///   la app con su propia sesion de audio: la alarma no se calla hasta que el
///   reto se completa entero, y vuelve a sonar si se abandona a mitad.
///
/// Fuera de iOS (el host donde corren `swift build` y `swift test`) no existe
/// AlarmKit y todo lo que programa alarmas lanza `.alarmKitNoDisponible`.
public actor SystemAlarmScheduler: AlarmScheduling {
    private let bundle: Bundle
    private let tones: ToneRegistry
    private let log = Logger(subsystem: "com.hrocha.reprise", category: "alarma")

    #if os(iOS)
    private let sonido = ChallengeSound()
    #endif

    public init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.bundle = bundle
        self.tones = ToneRegistry(defaults: defaults)
    }

    // MARK: - Autorizacion

    public func authorizationState() async -> AlarmAuthorizationState {
        #if canImport(AlarmKit)
        AlarmManager.shared.authorizationState.dominio
        #else
        .noDeterminado
        #endif
    }

    /// Pide el permiso. Si ya esta denegado no vuelve a preguntar —iOS solo
    /// deja preguntar una vez— y devuelve `.denegado` para que la pantalla
    /// mande a Ajustes con `AlarmAuthorizationCopy`.
    @discardableResult
    public func requestAuthorization() async throws -> AlarmAuthorizationState {
        #if canImport(AlarmKit)
        let actual = AlarmManager.shared.authorizationState.dominio
        guard actual == .noDeterminado else { return actual }
        do {
            return try await AlarmManager.shared.requestAuthorization().dominio
        } catch {
            throw AlarmSchedulerError.fallaDeAlarmKit(descripcion: "\(error)")
        }
        #else
        throw AlarmSchedulerError.alarmKitNoDisponible
        #endif
    }

    // MARK: - Programar y cancelar

    public func schedule(_ alarm: DomainAlarm) async throws {
        #if canImport(AlarmKit)
        // Una alarma apagada no se programa: se quita si estaba puesta.
        guard alarm.isEnabled else {
            try await cancel(alarmID: alarm.id)
            return
        }

        switch await authorizationState() {
        case .autorizado: break
        case .denegado: throw AlarmSchedulerError.sinAutorizacion
        case .noDeterminado: throw AlarmSchedulerError.autorizacionPendiente
        }

        let plan = try AlarmFirePlan(alarm: alarm)
        let configuracion = AlarmManager.AlarmConfiguration.alarm(
            schedule: plan.alarmKitSchedule,
            attributes: atributos(de: alarm),
            secondaryIntent: OpenChallengeIntent(alarm: alarm),
            sound: sonidoDeAlerta(de: alarm)
        )

        do {
            _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: configuracion)
        } catch AlarmManager.AlarmError.maximumLimitReached {
            throw AlarmSchedulerError.limiteDeAlarmasAlcanzado
        } catch {
            throw AlarmSchedulerError.fallaDeAlarmKit(descripcion: "\(error)")
        }

        tones.record(toneID: alarm.toneID, for: alarm.id)
        log.info("Alarma \(alarm.id, privacy: .public) programada a las \(plan.hour):\(plan.minute), repite: \(plan.repeats)")
        #else
        _ = alarm
        throw AlarmSchedulerError.alarmKitNoDisponible
        #endif
    }

    public func cancel(alarmID: DomainAlarm.ID) async throws {
        #if canImport(AlarmKit)
        do {
            try AlarmManager.shared.cancel(id: alarmID)
        } catch {
            // Cancelar algo que ya no existe no es un fallo que deba subir a la
            // pantalla: el estado final es el que se pedia.
            log.notice("Cancelar la alarma \(alarmID, privacy: .public) fallo: \(String(describing: error))")
        }
        tones.forget(alarmID: alarmID)
        #else
        _ = alarmID
        throw AlarmSchedulerError.alarmKitNoDisponible
        #endif
    }

    public func scheduledAlarmIDs() async throws -> Set<DomainAlarm.ID> {
        #if canImport(AlarmKit)
        do {
            let ids = Set(try AlarmManager.shared.alarms.map(\.id))
            tones.prune(keeping: ids)
            return ids
        } catch {
            throw AlarmSchedulerError.fallaDeAlarmKit(descripcion: "\(error)")
        }
        #else
        throw AlarmSchedulerError.alarmKitNoDisponible
        #endif
    }

    // MARK: - El sonido durante el reto

    /// Silencia. Solo debe llamarse con el reto completo: por decision de
    /// producto la alarma no se calla antes.
    public func silenceCurrentAlarm() async {
        #if canImport(AlarmKit)
        pararAlertaDelSistema()
        ChallengeInbox.clear()
        #endif
        #if os(iOS)
        await sonido.stop()
        #endif
    }

    /// Vuelve a sonar. Se llama dos veces en la vida de un reto: al abrirse la
    /// pantalla —la app toma el relevo de la alerta del sistema— y cada vez que
    /// el reto se abandona a mitad.
    public func resumeCurrentAlarm() async {
        #if canImport(AlarmKit)
        // Si la alerta del sistema sigue viva, se apaga: a partir de aqui el
        // ruido lo lleva la app, y dos alarmas sonando a la vez es peor que
        // ninguna. En una alarma con repeticion esto termina el aviso de hoy,
        // no la programacion de los demas dias.
        let idQueSuena = pararAlertaDelSistema()

        #if os(iOS)
        let alarmID = idQueSuena ?? ChallengeInbox.peek()?.alarmID
        let toneID = alarmID.flatMap { tones.toneID(for: $0) } ?? Tone.defaultID
        await sonido.start(tone: ToneCatalog.tonoEfectivo(id: toneID, en: bundle), bundle: bundle)
        #endif
        #endif
    }

    public var isSounding: Bool {
        get async {
            #if os(iOS)
            await sonido.isPlaying
            #else
            false
            #endif
        }
    }
}

#if canImport(AlarmKit)

// MARK: - Traduccion a AlarmKit

extension SystemAlarmScheduler {
    /// Apaga la alerta que este sonando ahora mismo y devuelve de que alarma
    /// era. `nil` si no habia ninguna.
    @discardableResult
    private func pararAlertaDelSistema() -> DomainAlarm.ID? {
        guard let sonando = try? AlarmManager.shared.alarms.first(where: { $0.state == .alerting })
        else { return nil }
        try? AlarmManager.shared.stop(id: sonando.id)
        return sonando.id
    }

    private func atributos(de alarm: DomainAlarm) -> AlarmAttributes<ChallengeMetadata> {
        let secundario = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Hacer el reto"),
            textColor: .white,
            systemImageName: alarm.challenge.simbolo
        )
        return AlarmAttributes(
            presentation: AlarmPresentation(alert: alerta(de: alarm, secundario: secundario)),
            metadata: ChallengeMetadata(alarmID: alarm.id, challenge: alarm.challenge),
            tintColor: .accentColor
        )
    }

    private func alerta(
        de alarm: DomainAlarm,
        secundario: AlarmButton
    ) -> AlarmPresentation.Alert {
        let titulo = LocalizedStringResource(stringLiteral: alarm.tituloDeAlerta)
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(
                title: titulo,
                secondaryButton: secundario,
                secondaryButtonBehavior: .custom
            )
        } else {
            // En iOS 26.0 el init sin `stopButton` no existe. El boton de parar
            // lo pinta el sistema igual, se lo demos o no.
            return AlarmPresentation.Alert(
                title: titulo,
                stopButton: AlarmButton(
                    text: LocalizedStringResource(stringLiteral: "Parar"),
                    textColor: .white,
                    systemImageName: "stop.fill"
                ),
                secondaryButton: secundario,
                secondaryButtonBehavior: .custom
            )
        }
    }

    private func sonidoDeAlerta(de alarm: DomainAlarm) -> AlertConfiguration.AlertSound {
        let tono = ToneCatalog.tonoEfectivo(id: alarm.toneID, en: bundle)
        guard let fileName = tono.fileName else { return .default }
        return .named(fileName)
    }
}

/// Lo que la alerta del sistema lleva encima sobre nuestro reto.
@available(iOS 26.0, *)
public struct ChallengeMetadata: AlarmMetadata {
    public let alarmID: DomainAlarm.ID
    public let challenge: ChallengeType

    public init(alarmID: DomainAlarm.ID, challenge: ChallengeType) {
        self.alarmID = alarmID
        self.challenge = challenge
    }
}

extension AlarmFirePlan {
    /// La programacion en el tipo de AlarmKit.
    ///
    /// `.relative` con `.never` es la alarma de un solo uso: suena la proxima
    /// vez que el reloj pase por esa hora y no vuelve.
    var alarmKitSchedule: AlarmKit.Alarm.Schedule {
        .relative(
            .init(
                time: .init(hour: hour, minute: minute),
                repeats: repeats ? .weekly(localeWeekdays) : .never
            )
        )
    }
}

extension AlarmManager.AuthorizationState {
    var dominio: AlarmAuthorizationState {
        switch self {
        case .notDetermined: .noDeterminado
        case .authorized: .autorizado
        case .denied: .denegado
        @unknown default: .noDeterminado
        }
    }
}
#endif

extension ChallengeType {
    /// El icono del boton secundario de la alerta.
    var simbolo: String {
        switch self {
        case .pasos: "figure.walk"
        case .sentadillas: "figure.strengthtraining.functional"
        }
    }
}

extension DomainAlarm {
    /// Lo que se lee en la alerta del sistema. La etiqueta manda si la hay,
    /// porque la puso el usuario; si no, el reto que le espera.
    var tituloDeAlerta: String {
        label.isEmpty ? "Arriba: \(challenge.nombre)" : label
    }
}
