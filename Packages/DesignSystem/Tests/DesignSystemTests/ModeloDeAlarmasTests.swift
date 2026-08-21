import Foundation
import Testing
import AlarmCore
import AlarmScheduler
@testable import DesignSystem

// Aqui los tests aportan porque cubren justo lo que estaba roto: la pantalla
// de crear alarma tenia un boton "Guardar" que solo cerraba la hoja, y nadie
// programaba nada. Eso no lo delata ni un compilador ni una captura.
//
// Lo que se comprueba es el contrato del modelo con sus tres piezas: que lo
// que el usuario cree guardado esta en el almacen, que lo que ve encendido
// esta puesto en el sistema, y que el plan corta antes de guardar y no despues.

@MainActor
private func modeloDePrueba(
    alarmas: [Alarm] = [],
    plan planContratado: PlanDeSuscripcion = .pro,
    programador: any AlarmScheduling = PreviewAlarmScheduler()
) -> (ModeloDeAlarmas, ModeloDelPlan) {
    // Un cajon de UserDefaults por test, que si no un test deja a Pro al
    // siguiente y los fallos salen segun el orden en que corran.
    let defaults = UserDefaults(suiteName: "reprise.tests.\(UUID().uuidString)")!
    let plan = ModeloDelPlan(defaults: defaults)
    if planContratado.esPro { plan.contratarPro() }
    let modelo = ModeloDeAlarmas(
        repositorio: RepositorioEnMemoria(alarmas),
        programador: programador,
        plan: plan
    )
    return (modelo, plan)
}

@MainActor
@Suite("Modelo de alarmas · guardar")
struct GuardarTests {

    @Test("Una alarma nueva acaba en el almacen, no solo en la lista")
    func guardarNueva() async throws {
        let almacen = RepositorioEnMemoria()
        let plan = ModeloDelPlan(defaults: UserDefaults(suiteName: "reprise.tests.\(UUID().uuidString)")!)
        plan.contratarPro()
        let modelo = ModeloDeAlarmas(
            repositorio: almacen, programador: PreviewAlarmScheduler(), plan: plan
        )
        await modelo.cargar()

        let nueva = Alarm(hour: 6, minute: 30, challenge: .pasos, label: "Gimnasio")
        #expect(await modelo.guardar(nueva) == .guardada)
        #expect(modelo.fallo == nil)

        // Lo que de verdad importa: releer desde cero lo encuentra.
        let releido = ModeloDeAlarmas(
            repositorio: almacen, programador: PreviewAlarmScheduler(), plan: plan
        )
        await releido.cargar()
        #expect(releido.alarmas.first?.label == "Gimnasio")
        #expect(releido.alarmas.first?.hour == 6)
    }

    @Test("Editar una alarma la modifica, no la duplica")
    func editarNoDuplica() async throws {
        let (modelo, _) = modeloDePrueba()
        let alarma = Alarm(hour: 7, minute: 0, challenge: .pasos)
        await modelo.guardar(alarma)

        var editada = alarma
        editada.minute = 45
        editada.label = "Correr"
        await modelo.guardar(editada)

        #expect(modelo.alarmas.count == 1)
        #expect(modelo.alarmas.first?.minute == 45)
        #expect(modelo.alarmas.first?.label == "Correr")
    }

    @Test("La ultima alarma creada sale la primera de la lista")
    func laUltimaCreadaSaleArriba() async throws {
        let (modelo, _) = modeloDePrueba()
        await modelo.guardar(Alarm(hour: 6, minute: 5, challenge: .pasos))
        await modelo.guardar(Alarm(hour: 6, minute: 30, challenge: .pasos))
        await modelo.guardar(Alarm(hour: 9, minute: 0, challenge: .pasos))

        // Las horas van al reves que el orden de creacion a proposito: si la
        // lista volviera a ordenarse por hora, esto lo cantaria.
        #expect(modelo.alarmas.map(\.hour) == [9, 6, 6])
        #expect(modelo.alarmas.map(\.minute) == [0, 30, 5])
    }

    @Test("Editar una alarma vieja no la sube a lo alto de la lista")
    func editarNoLaSube() async throws {
        let (modelo, _) = modeloDePrueba()
        let vieja = Alarm(hour: 6, minute: 0, challenge: .pasos,
                          creadaEn: Date(timeIntervalSince1970: 1_000_000))
        await modelo.guardar(vieja)
        await modelo.guardar(Alarm(hour: 7, minute: 0, challenge: .pasos,
                                   creadaEn: Date(timeIntervalSince1970: 2_000_000)))

        var editada = vieja
        editada.minute = 45
        editada.creadaEn = Date()
        await modelo.guardar(editada)

        #expect(modelo.alarmas.count == 2)
        #expect(modelo.alarmas.last?.id == vieja.id,
                "la fila se iria de debajo del dedo justo al guardar")
        #expect(modelo.alarmas.last?.minute == 45)
    }

    @Test("La proxima es la mas temprana, no la primera de la lista")
    func laProximaEsPorHora() async throws {
        let (modelo, _) = modeloDePrueba()
        await modelo.guardar(Alarm(hour: 6, minute: 30, challenge: .pasos, label: "Madrugon"))
        // Puesta despues, asi que va la primera de la lista. Pero suena mas
        // tarde: la esfera de la portada tiene que seguir dando las 6:30.
        await modelo.guardar(Alarm(hour: 23, minute: 0, challenge: .pasos, label: "Noche"))

        #expect(modelo.alarmas.first?.label == "Noche")
        #expect(modelo.proxima?.label == "Madrugon")
    }

    @Test("La proxima ignora las apagadas")
    func laProximaIgnoraLasApagadas() async throws {
        let (modelo, _) = modeloDePrueba()
        await modelo.guardar(Alarm(hour: 5, minute: 0, challenge: .pasos,
                                   label: "Apagada", isEnabled: false))
        await modelo.guardar(Alarm(hour: 8, minute: 0, challenge: .pasos, label: "Puesta"))

        #expect(modelo.proxima?.label == "Puesta")
    }

    @Test("Si el almacen falla, la alarma no se pinta como guardada")
    func almacenQueFalla() async throws {
        let plan = ModeloDelPlan(defaults: UserDefaults(suiteName: "reprise.tests.\(UUID().uuidString)")!)
        plan.contratarPro()
        let modelo = ModeloDeAlarmas(
            repositorio: AlmacenQueFalla(), programador: PreviewAlarmScheduler(), plan: plan
        )

        let resultado = await modelo.guardar(Alarm(hour: 7, minute: 0, challenge: .pasos))

        // Lo peor posible seria ensenarla en la lista: el usuario se iria a
        // dormir creyendo que la tiene puesta.
        #expect(resultado == .noSeHaPodidoGuardar)
        #expect(modelo.alarmas.isEmpty)
        #expect(modelo.fallo != nil)
    }
}

@MainActor
@Suite("Modelo de alarmas · el sistema")
struct ProgramarTests {

    @Test("Guardar una alarma encendida la deja puesta en el sistema")
    func guardarLaProgramaste() async throws {
        let programador = PreviewAlarmScheduler()
        let (modelo, _) = modeloDePrueba(programador: programador)

        let alarma = Alarm(hour: 6, minute: 30, challenge: .pasos)
        await modelo.guardar(alarma)

        #expect(try await programador.scheduledAlarmIDs() == [alarma.id])
    }

    @Test("Guardarla apagada no la pone")
    func apagadaNoSePone() async throws {
        let programador = PreviewAlarmScheduler()
        let (modelo, _) = modeloDePrueba(programador: programador)

        let alarma = Alarm(hour: 6, minute: 30, challenge: .pasos, isEnabled: false)
        await modelo.guardar(alarma)

        #expect(try await programador.scheduledAlarmIDs().isEmpty)
    }

    @Test("Apagar desde la lista la quita del sistema, y encender la devuelve")
    func apagarYEncender() async throws {
        let programador = PreviewAlarmScheduler()
        let (modelo, _) = modeloDePrueba(programador: programador)
        let alarma = Alarm(hour: 6, minute: 0, challenge: .pasos, isEnabled: true)
        await modelo.guardar(alarma)

        await modelo.cambiarEncendido(id: alarma.id, a: false)
        #expect(modelo.alarmas.first?.isEnabled == false)
        #expect(try await programador.scheduledAlarmIDs().isEmpty)

        await modelo.cambiarEncendido(id: alarma.id, a: true)
        #expect(try await programador.scheduledAlarmIDs() == [alarma.id])
    }

    @Test("Eliminar la quita del almacen y del sistema")
    func eliminar() async throws {
        let programador = PreviewAlarmScheduler()
        let almacen = RepositorioEnMemoria()
        let plan = ModeloDelPlan(defaults: UserDefaults(suiteName: "reprise.tests.\(UUID().uuidString)")!)
        plan.contratarPro()
        let modelo = ModeloDeAlarmas(repositorio: almacen, programador: programador, plan: plan)
        let alarma = Alarm(hour: 8, minute: 0, challenge: .sentadillas)
        await modelo.guardar(alarma)

        await modelo.eliminar(id: alarma.id)

        #expect(modelo.alarmas.isEmpty)
        #expect(try await almacen.all().isEmpty)
        #expect(try await programador.scheduledAlarmIDs().isEmpty)
    }

    @Test("Al arrancar se limpia lo que quedo puesto y ya no toca")
    func arranqueLimpiaLoQueSobra() async throws {
        // El caso feo: el sistema tiene puesta una alarma que ya no esta en
        // disco. Pasa si la app muere entre borrar y cancelar. Si nadie la
        // limpia, suena un dia sin que exista en ningun sitio.
        let programador = PreviewAlarmScheduler()
        let fantasma = Alarm(hour: 4, minute: 0, challenge: .pasos)
        try await programador.schedule(fantasma)

        let (modelo, _) = modeloDePrueba(programador: programador)
        await modelo.cargar()

        #expect(try await programador.scheduledAlarmIDs().isEmpty)
    }

    @Test("Si el sistema no la acepta, se dice y se dice con su mensaje")
    func elSistemaLaRechaza() async throws {
        let (modelo, _) = modeloDePrueba(programador: ProgramadorQueNiega())

        await modelo.guardar(Alarm(hour: 7, minute: 0, challenge: .pasos))

        // Guardada si esta —el disco fue bien—, pero el usuario tiene que
        // enterarse de que no va a sonar.
        #expect(modelo.alarmas.count == 1)
        #expect(modelo.fallo == AlarmSchedulerError.sinAutorizacion.mensaje)
    }

    @Test("Permiso denegado se refleja en el aviso de la lista")
    func permisoDenegado() async throws {
        let (modelo, _) = modeloDePrueba(programador: PreviewAlarmScheduler(authorization: .denegado))
        await modelo.cargar()

        #expect(modelo.autorizacion == .denegado)
        #expect(modelo.avisoDePermiso == AlarmAuthorizationCopy.avisoEnLista)
    }
}

@MainActor
@Suite("Modelo de alarmas · el plan")
struct PlanTests {

    @Test("En gratis, la segunda alarma encendida topa con el muro y no se guarda")
    func segundaAlarmaEnGratis() async throws {
        let (modelo, _) = modeloDePrueba(plan: .gratis)
        #expect(await modelo.guardar(Alarm(hour: 6, minute: 0, challenge: .pasos)) == .guardada)

        let segunda = Alarm(hour: 7, minute: 0, challenge: .pasos)
        let resultado = await modelo.guardar(segunda)

        #expect(resultado == .loImpideElPlan(.limiteDeAlarmasActivas(maximo: 1)))
        // Cortar antes significa antes de tocar el disco: si se guardara y
        // luego se ensenara el muro, el usuario acabaria con una alarma que no
        // pidio y que ademas no suena.
        #expect(modelo.alarmas.count == 1)
    }

    @Test("En gratis, repetir por dias topa con su propio muro")
    func repeticionEnGratis() async throws {
        let (modelo, _) = modeloDePrueba(plan: .gratis)

        let conDias = Alarm(hour: 6, minute: 0, weekdays: [.lunes, .martes], challenge: .pasos)
        let resultado = await modelo.guardar(conDias)

        // El motivo importa: la pantalla ensena un muro distinto para cada uno.
        #expect(resultado == .loImpideElPlan(.repeticionPorDias))
        #expect(modelo.alarmas.isEmpty)
    }

    @Test("En gratis se puede guardar una segunda alarma si va apagada")
    func segundaApagadaSiCabe() async throws {
        let (modelo, _) = modeloDePrueba(plan: .gratis)
        await modelo.guardar(Alarm(hour: 6, minute: 0, challenge: .pasos))

        let segunda = Alarm(hour: 7, minute: 0, challenge: .pasos, isEnabled: false)
        #expect(await modelo.guardar(segunda) == .guardada)
        #expect(modelo.alarmas.count == 2)
    }

    @Test("Contratar Pro desbloquea lo que antes topaba")
    func contratarProDesbloquea() async throws {
        let (modelo, plan) = modeloDePrueba(plan: .gratis)
        await modelo.guardar(Alarm(hour: 6, minute: 0, challenge: .pasos))
        let segunda = Alarm(hour: 7, minute: 0, challenge: .pasos)
        #expect(await modelo.guardar(segunda) != .guardada)

        plan.contratarPro()

        #expect(await modelo.guardar(segunda) == .guardada)
        #expect(modelo.alarmas.count == 2)
    }

    @Test("Encender la que el plan tapa abre el muro, no se queda muda")
    func encenderLaQueElPlanTapa() async throws {
        // El caso que se escapa mirando solo el codigo: la alarma esta guardada
        // encendida, pero el plan gratis la tapa y sale apagada. Al pulsarle el
        // interruptor, lo guardado ya coincide con lo pedido, asi que si se
        // compara contra disco no pasa absolutamente nada: el interruptor vuelve
        // solo a su sitio y el usuario no sabe por que.
        let (modelo, plan) = modeloDePrueba()
        // La que sobrevive al plan gratis es la de arriba de la lista, o sea la
        // ultima creada. La tapada es esta, la vieja.
        let vieja = Alarm(hour: 6, minute: 0, challenge: .pasos)
        await modelo.guardar(vieja)
        await modelo.guardar(Alarm(hour: 7, minute: 0, challenge: .pasos))
        plan.volverAGratis()

        #expect(modelo.efectivas.first { $0.id == vieja.id }?.isEnabled == false)
        #expect(modelo.alarmas.first { $0.id == vieja.id }?.isEnabled == true)

        let resultado = await modelo.cambiarEncendido(id: vieja.id, a: true)

        #expect(resultado == .loImpideElPlan(.limiteDeAlarmasActivas(maximo: 1)))
    }

    @Test("Al caer a gratis no se borra nada: sobra apagado y sin dias")
    func caerAGratisNoBorra() async throws {
        let programador = PreviewAlarmScheduler()
        let (modelo, plan) = modeloDePrueba(programador: programador)
        let vieja = Alarm(hour: 6, minute: 0, weekdays: [.lunes, .martes], challenge: .pasos)
        let ultima = Alarm(hour: 7, minute: 0, weekdays: [.sabado], challenge: .pasos)
        await modelo.guardar(vieja)
        await modelo.guardar(ultima)
        #expect(try await programador.scheduledAlarmIDs().count == 2)

        plan.volverAGratis()
        await modelo.cargar()

        // En disco siguen las dos, con sus dias intactos.
        #expect(modelo.alarmas.count == 2)
        #expect(modelo.alarmas.last?.weekdays == [.lunes, .martes])
        // Lo que suena es solo la de arriba —la ultima puesta—, y de un solo uso.
        #expect(modelo.efectivas.filter(\.isEnabled).count == 1)
        #expect(modelo.efectivas.first?.weekdays.isEmpty == true)
        #expect(try await programador.scheduledAlarmIDs() == [ultima.id])
        #expect(modelo.elPlanRecortaAlgo)
    }
}

/// Un almacen que no puede con nada, para el caso del disco roto.
private struct AlmacenQueFalla: AlarmRepository {
    struct Roto: Error {}

    func all() async throws -> [Alarm] { throw Roto() }
    func save(_ alarm: Alarm) async throws { throw Roto() }
    func delete(id: Alarm.ID) async throws { throw Roto() }
}

/// Un programador con el permiso denegado que no acepta nada.
private struct ProgramadorQueNiega: AlarmScheduling {
    func authorizationState() async -> AlarmAuthorizationState { .denegado }
    func requestAuthorization() async throws -> AlarmAuthorizationState { .denegado }
    func schedule(_ alarm: Alarm) async throws { throw AlarmSchedulerError.sinAutorizacion }
    func cancel(alarmID: Alarm.ID) async throws {}
    func scheduledAlarmIDs() async throws -> Set<Alarm.ID> { [] }
    func silenceCurrentAlarm() async {}
    func resumeCurrentAlarm() async {}
}
