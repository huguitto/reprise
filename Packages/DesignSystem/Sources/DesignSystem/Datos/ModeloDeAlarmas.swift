import Foundation
import AlarmCore
import AlarmScheduler

/// Las alarmas del usuario: lo que hay guardado, lo que el plan deja que suene
/// y lo que esta puesto de verdad en el sistema.
///
/// Habla contra los protocolos de `AlarmCore` —`AlarmRepository` y
/// `AlarmScheduling`—, no contra `Persistence` ni contra AlarmKit. Asi la
/// pantalla se prueba entera en el host con dos dobles de juguete.
///
/// Las tres cosas que hace, y en este orden, que importa:
///
///   1. **Pregunta al plan.** `PoliticaDelPlan.alGuardar` corta antes de tocar
///      nada. Si dice que no, no se guarda: se ensena el muro de pago.
///   2. **Escribe en disco.** Y solo si el disco dice que si, cambia la lista.
///   3. **Sincroniza el sistema.** Programa lo que tiene que sonar y cancela lo
///      que no. Esto va al final a proposito: una alarma programada que no esta
///      en disco se pierde al reiniciar el movil y suena un dia sin que nadie
///      sepa por que.
@MainActor
@Observable
public final class ModeloDeAlarmas {

    /// Lo que hay guardado, tal cual. Es lo que se edita.
    public private(set) var alarmas: [Alarm]
    /// Mientras se lee el disco. Sirve para no ensenar "ninguna puesta" en la
    /// cabecera durante el parpadeo del arranque, que es mentira y asusta.
    public private(set) var cargando: Bool
    /// Lo ultimo que fallo, ya en castellano. `nil` = todo bien.
    ///
    /// Se ensena en la lista en vez de tragarselo: una alarma que el usuario
    /// cree guardada y no lo esta es justo el fallo que hace que no suene.
    public private(set) var fallo: String?
    /// Permiso de alarmas del sistema. Sin el, nada de esto suena.
    public private(set) var autorizacion: AlarmAuthorizationState = .noDeterminado

    private let repositorio: any AlarmRepository
    private let programador: any AlarmScheduling
    private let plan: ModeloDelPlan

    public init(
        repositorio: any AlarmRepository,
        programador: any AlarmScheduling,
        plan: ModeloDelPlan,
        alarmasIniciales: [Alarm] = []
    ) {
        self.repositorio = repositorio
        self.programador = programador
        self.plan = plan
        self.alarmas = Self.ordenadas(alarmasIniciales)
        // Con alarmas de partida no hay parpadeo que tapar: es el caso de los
        // `#Preview`, que no llegan a llamar a `cargar()`.
        self.cargando = alarmasIniciales.isEmpty
    }

    // MARK: - Lo que suena de verdad

    /// Las alarmas tal y como quedan con el plan contratado.
    ///
    /// Es lo que se **pinta** y lo que se **programa**, y puede no coincidir con
    /// lo guardado: quien tenia Pro y lo deja conserva sus cinco alarmas en
    /// disco, pero solo le suena una y sin dias de la semana. Lo guardado no se
    /// toca, para que volver a Pro lo devuelva todo sin reconfigurar nada.
    public var efectivas: [Alarm] {
        PoliticaDelPlan.alarmasEfectivas(alarmas, plan: plan.plan)
    }

    /// Si el plan esta recortando algo de lo guardado. La lista lo dice en vez
    /// de ensenar una alarma apagada sin explicacion.
    public var elPlanRecortaAlgo: Bool { efectivas != alarmas }

    /// Aviso mientras el permiso siga denegado, o `nil` si no hay nada que
    /// avisar. El texto es de `AlarmScheduler`, que es de quien es el permiso.
    public var avisoDePermiso: String? {
        autorizacion == .denegado ? AlarmAuthorizationCopy.avisoEnLista : nil
    }

    // MARK: - Arranque

    /// Relee el disco, pide el permiso si no se ha pedido nunca y deja el
    /// sistema en sintonia con lo guardado. Idempotente.
    public func cargar() async {
        do {
            alarmas = Self.ordenadas(try await repositorio.all())
            fallo = nil
        } catch {
            fallo = "No se han podido leer las alarmas guardadas."
        }
        cargando = false
        await refrescarAutorizacion()
        await sincronizarProgramador()
    }

    /// Pregunta el estado del permiso y lo pide si todavia no se ha preguntado.
    ///
    /// iOS solo deja preguntar una vez. Si ya esta denegado esto no vuelve a
    /// sacar el dialogo: se queda en `.denegado` y la pantalla manda a Ajustes.
    public func refrescarAutorizacion() async {
        autorizacion = await programador.authorizationState()
        guard autorizacion == .noDeterminado else { return }
        autorizacion = (try? await programador.requestAuthorization()) ?? .noDeterminado
    }

    // MARK: - Escrituras

    /// Como acabo un intento de guardar. La pantalla necesita distinguirlos:
    /// uno cierra la hoja, otro abre el muro de pago y otro se queda.
    public enum Resultado: Sendable, Hashable {
        case guardada
        /// El plan contratado no da para esto. Lleva el motivo para que la
        /// pantalla sepa **que** muro ensenar.
        case loImpideElPlan(RestriccionDelPlan)
        case noSeHaPodidoGuardar
    }

    /// Guarda una alarma nueva o los cambios de una que ya estaba. Distingue
    /// una de otra por el `id`, igual que hace el almacen.
    @discardableResult
    public func guardar(_ alarma: Alarm) async -> Resultado {
        if let restriccion = PoliticaDelPlan.alGuardar(alarma, entre: alarmas, plan: plan.plan) {
            return .loImpideElPlan(restriccion)
        }

        do {
            try await repositorio.save(alarma)
        } catch {
            fallo = "No se ha podido guardar la alarma."
            return .noSeHaPodidoGuardar
        }

        if let indice = alarmas.firstIndex(where: { $0.id == alarma.id }) {
            alarmas[indice] = alarma
        } else {
            alarmas.append(alarma)
        }
        alarmas = Self.ordenadas(alarmas)
        fallo = nil

        await sincronizarProgramador()
        return .guardada
    }

    public func eliminar(id: Alarm.ID) async {
        // Primero se quita del sistema. Al reves, si el borrado de disco va
        // bien y la cancelacion falla, queda una alarma programada que ya no
        // existe en ningun sitio y no hay forma de llegar a ella para pararla.
        do {
            try await programador.cancel(alarmID: id)
        } catch {
            fallo = mensaje(de: error, siNo: "No se ha podido quitar la alarma del sistema.")
            return
        }

        do {
            try await repositorio.delete(id: id)
            alarmas.removeAll { $0.id == id }
            fallo = nil
        } catch {
            fallo = "No se ha podido eliminar la alarma."
        }
    }

    /// Encender o apagar desde la lista, sin entrar a editarla.
    ///
    /// Apagar siempre se puede. Encender pasa por el plan igual que guardar,
    /// porque encender una segunda alarma es exactamente lo que el plan gratis
    /// no da.
    @discardableResult
    public func cambiarEncendido(id: Alarm.ID, a encendido: Bool) async -> Resultado {
        guard let indice = alarmas.firstIndex(where: { $0.id == id }) else { return .guardada }

        // Se compara contra lo **efectivo**, no contra lo guardado. Con el plan
        // gratis una alarma puede estar guardada encendida y salir apagada
        // porque el plan la esta tapando; comparando con lo guardado, ese
        // interruptor concreto no hacia nada al pulsarlo: ni encendia, ni
        // guardaba, ni explicaba por que. Volvia solo a su sitio.
        let comoSeVeAhora = efectivas.first { $0.id == id }?.isEnabled ?? alarmas[indice].isEnabled
        guard comoSeVeAhora != encendido else { return .guardada }

        var cambiada = alarmas[indice]
        cambiada.isEnabled = encendido
        return await guardar(cambiada)
    }

    // MARK: - El sistema

    /// Deja programado exactamente lo que tiene que sonar, ni mas ni menos.
    ///
    /// Reprograma todo lo encendido en vez de solo lo que ha cambiado: no hay
    /// forma de preguntarle al sistema **a que hora** tiene puesta una alarma,
    /// solo si la tiene, asi que editar la hora de una alarma ya programada no
    /// se distingue de no haberla tocado. Programar encima es idempotente en las
    /// dos implementaciones.
    private func sincronizarProgramador() async {
        let deben = efectivas.filter(\.isEnabled)
        let idsQueDeben = Set(deben.map(\.id))

        do {
            let puestas = try await programador.scheduledAlarmIDs()
            for id in puestas.subtracting(idsQueDeben) {
                try await programador.cancel(alarmID: id)
            }
            for alarma in deben {
                try await programador.schedule(alarma)
            }
            fallo = nil
        } catch {
            fallo = mensaje(de: error, siNo: "La alarma esta guardada, pero el sistema no la ha aceptado: puede que no suene.")
        }
    }

    /// El texto de `AlarmSchedulerError` si lo es, y si no el de repuesto. Esos
    /// mensajes estan escritos para leerse en pantalla; tirarlos y poner uno
    /// generico seria perder la unica pista que tiene el usuario.
    private func mensaje(de error: any Error, siNo repuesto: String) -> String {
        (error as? AlarmSchedulerError)?.mensaje ?? repuesto
    }

    // MARK: - Orden

    /// El mismo orden que devuelve el almacen —por hora y minuto—, para que la
    /// lista no se recoloque sola al reabrir la app. El `id` solo desempata,
    /// que si no dos alarmas a la misma hora bailan entre arranques.
    private static func ordenadas(_ alarmas: [Alarm]) -> [Alarm] {
        alarmas.sorted {
            ($0.hour, $0.minute, $0.id.uuidString) < ($1.hour, $1.minute, $1.id.uuidString)
        }
    }
}

// MARK: - Para previsualizar y para tests

/// Un `AlarmRepository` que solo vive en memoria.
///
/// No es un doble de mentira a medias: hace lo mismo que el de verdad —alta,
/// modificacion por `id` y baja— pero sin fichero. Con el, los `#Preview`
/// guardan y borran de verdad mientras dure la sesion.
public actor RepositorioEnMemoria: AlarmRepository {
    private var alarmas: [Alarm]

    public init(_ alarmas: [Alarm] = []) {
        self.alarmas = alarmas
    }

    public func all() throws -> [Alarm] { alarmas }

    public func save(_ alarm: Alarm) throws {
        if let indice = alarmas.firstIndex(where: { $0.id == alarm.id }) {
            alarmas[indice] = alarm
        } else {
            alarmas.append(alarm)
        }
    }

    public func delete(id: Alarm.ID) throws {
        alarmas.removeAll { $0.id == id }
    }
}

extension ModeloDeAlarmas {
    /// El modelo con el que se pintan los `#Preview` y la galeria: las alarmas
    /// inventadas de siempre, ya editables, en Pro para que se vean todas.
    public static func deMentira() -> ModeloDeAlarmas {
        ModeloDeAlarmas(
            repositorio: RepositorioEnMemoria(DatosDeMentira.alarmas),
            programador: PreviewAlarmScheduler(),
            plan: .deMentira,
            alarmasIniciales: DatosDeMentira.alarmas
        )
    }
}
