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
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let antesDeAmbas = calendario.date(from: DateComponents(
            year: 2026, month: 8, day: 21, hour: 5
        ))!
        let (modelo, _) = modeloDePrueba()
        await modelo.guardar(Alarm(hour: 6, minute: 30, challenge: .pasos, label: "Madrugon"))
        // Puesta despues, asi que va la primera de la lista. Pero suena mas
        // tarde: la esfera de la portada tiene que seguir dando las 6:30.
        await modelo.guardar(Alarm(hour: 23, minute: 0, challenge: .pasos, label: "Noche"))

        #expect(modelo.alarmas.first?.label == "Noche")
        #expect(modelo.proxima(desde: antesDeAmbas, calendario: calendario)?.label == "Madrugon")
    }

    @Test("Una alarma pendiente hoy gana a otra mas temprana de manana")
    func hoyGanaAManana() async throws {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let ahora = calendario.date(from: DateComponents(
            year: 2026, month: 8, day: 21, hour: 18
        ))!
        let (modelo, _) = modeloDePrueba()
        await modelo.guardar(Alarm(hour: 7, minute: 0, challenge: .pasos, label: "Mañana"))
        await modelo.guardar(Alarm(hour: 22, minute: 0, challenge: .pasos, label: "Hoy"))

        #expect(modelo.proxima(desde: ahora, calendario: calendario)?.label == "Hoy")
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

    @Test("Que el sistema no diga que tiene puesto no impide programar")
    func consultarFallaPeroSeProgramaIgual() async throws {
        // El fallo del issue #36. Consultar es para saber que sobra; si no
        // contesta, se programa igual y no se molesta al usuario con un
        // "no se ha podido programar la alarma" que ademas era falso.
        let programador = ProgramadorMudo()
        let (modelo, _) = modeloDePrueba(programador: programador)

        let alarma = Alarm(hour: 6, minute: 30, challenge: .pasos)
        await modelo.guardar(alarma)

        #expect(await programador.puestas == [alarma.id])
        #expect(modelo.fallo == nil)
    }

    @Test("Una alarma que el sistema rechaza no se lleva por delante a las demas")
    func unaMalaNoTumbaLasBuenas() async throws {
        let mala = Alarm(hour: 5, minute: 0, challenge: .pasos)
        let buena = Alarm(hour: 7, minute: 0, challenge: .sentadillas)
        let programador = ProgramadorConUnaMala(mala: mala.id)
        let (modelo, _) = modeloDePrueba(programador: programador)

        await modelo.guardar(mala)
        await modelo.guardar(buena)

        // La buena esta puesta aunque la otra fallara antes en el mismo bucle...
        #expect(await programador.puestas == [buena.id])
        // ...y del fallo de la mala se entera el usuario igualmente.
        #expect(modelo.fallo != nil)
    }

    @Test("Dos sincronizaciones no se pisan: van en cola")
    func lasSincronizacionesHacenCola() async throws {
        let programador = ProgramadorLento()
        let alarma = Alarm(hour: 6, minute: 0, challenge: .pasos)
        let (modelo, _) = modeloDePrueba(alarmas: [alarma], programador: programador)

        // Dos caminos que en la app salen de `Task` distintas: abrir la
        // pantalla y guardar. Solapados, mandaban dos `schedule` del mismo id
        // a la vez y AlarmKit contestaba a uno con un error pelado.
        async let abrir: Void = modelo.cargar()
        async let guardar = modelo.guardar(Alarm(hour: 9, minute: 15, challenge: .pasos))
        _ = await (abrir, guardar)

        #expect(await programador.seSolaparon == false)
    }

    @Test("Apagar mientras se sincroniza gana: no la revive la de antes")
    func apagarGanaALaSincronizacionEnVuelo() async throws {
        // Una sincronizacion calcula "lo que debe sonar" al empezar. Si mientras
        // esta programando el usuario apaga la alarma, la vieja la volvia a
        // poner despues de que la nueva la cancelara: quedaba puesta en el
        // sistema con el interruptor apagado en pantalla.
        let programador = ProgramadorConFreno()
        let (modelo, _) = modeloDePrueba(programador: programador)
        let alarma = Alarm(hour: 6, minute: 0, challenge: .pasos)

        let guardando = Task { await modelo.guardar(alarma) }
        await programador.esperarAQueSeFrene()

        let apagando = Task { await modelo.cambiarEncendido(id: alarma.id, a: false) }
        await programador.soltar()
        _ = await guardando.value
        _ = await apagando.value

        #expect(modelo.alarmas.first?.isEnabled == false)
        #expect(await programador.puestas.isEmpty)
    }

    @Test("Si no se puede leer el disco, no se cancela lo que estaba puesto")
    func discoRotoNoDesprogramaNada() async throws {
        // Un tropiezo del disco al abrir dejaba `alarmas` vacia, y con eso la
        // sincronizacion cancelaba todo lo que si estaba puesto en el sistema.
        let programador = PreviewAlarmScheduler()
        let yaPuesta = Alarm(hour: 6, minute: 0, challenge: .pasos)
        try await programador.schedule(yaPuesta)

        let plan = ModeloDelPlan(defaults: UserDefaults(suiteName: "reprise.tests.\(UUID().uuidString)")!)
        plan.contratarPro()
        let modelo = ModeloDeAlarmas(
            repositorio: AlmacenQueFalla(), programador: programador, plan: plan
        )

        await modelo.cargar()

        #expect(try await programador.scheduledAlarmIDs() == [yaPuesta.id])
        // Y el aviso sigue en pantalla en vez de borrarlo la sincronizacion.
        #expect(modelo.fallo != nil)
    }
}

@MainActor
@Suite("Modelo de alarmas · las que suenan")
struct ActivasTests {

    // Esto es lo que pinta el carrusel de la esfera, y ahi el orden se ve: se
    // arrastra de una alarma a la siguiente. Si el orden bailara entre
    // repintados, la de al lado cambiaria sola de un pintado a otro.

    @Test("Van por hora del dia, no por cuando se crearon")
    func porHora() async throws {
        let (modelo, _) = modeloDePrueba()
        // Se guardan al reves de como tienen que salir.
        await modelo.guardar(Alarm(hour: 9, minute: 0, challenge: .pasos, label: "Tarde"))
        await modelo.guardar(Alarm(hour: 6, minute: 30, challenge: .pasos, label: "Pronto"))
        await modelo.guardar(Alarm(hour: 6, minute: 5, challenge: .pasos, label: "Antes"))

        #expect(modelo.activas.map(\.label) == ["Antes", "Pronto", "Tarde"])
    }

    @Test("Las apagadas no estan")
    func soloLasEncendidas() async throws {
        let (modelo, _) = modeloDePrueba()
        await modelo.guardar(Alarm(hour: 6, minute: 0, challenge: .pasos, label: "Suena"))
        await modelo.guardar(Alarm(hour: 7, minute: 0, challenge: .pasos,
                                   label: "No suena", isEnabled: false))

        #expect(modelo.activas.map(\.label) == ["Suena"])
    }

    @Test("La proxima esta en el pase, aunque no sea la primera")
    func laProximaEstaEnElPase() async throws {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let (modelo, _) = modeloDePrueba()
        #expect(modelo.proxima == nil)

        await modelo.guardar(Alarm(hour: 6, minute: 30, challenge: .pasos, label: "Madrugon"))
        await modelo.guardar(Alarm(hour: 22, minute: 0, challenge: .pasos, label: "Noche"))

        // A las nueve de la noche la que antes suena es la de las 22:00, pero
        // el pase sigue yendo por hora del reloj y empieza por la de las 6:30.
        // Son dos preguntas distintas y aqui se ve: la pantalla no ordena por
        // `proxima`, la usa para decidir en cual **abrir** el carrusel.
        let laNueve = calendario.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 21))!
        let proxima = modelo.proxima(desde: laNueve, calendario: calendario)

        #expect(proxima?.label == "Noche")
        #expect(modelo.activas.map(\.label) == ["Madrugon", "Noche"])
        #expect(modelo.activas.contains { $0.id == proxima?.id })
    }

    @Test("Dos a la misma hora quedan en un orden fijo, no en el que salga")
    func empateEstable() async throws {
        let (modelo, _) = modeloDePrueba()
        let una = Alarm(hour: 7, minute: 0, challenge: .pasos, label: "Una")
        let otra = Alarm(hour: 7, minute: 0, challenge: .sentadillas, label: "Otra")
        await modelo.guardar(una)
        await modelo.guardar(otra)

        // El desempate es el `id`, y por eso se puede predecir aqui. Sin el,
        // `sorted` no promete nada con dos elementos que empatan: el pase
        // podria ensenarlas en un orden hoy y en otro al reabrir la app.
        let esperado = [una, otra].sorted { $0.id.uuidString < $1.id.uuidString }
        #expect(modelo.activas.map(\.id) == esperado.map(\.id))
    }

    @Test("En gratis solo pasa una: no hay carrusel que ensenar")
    func enGratisSoloUna() async throws {
        let (modelo, _) = modeloDePrueba(plan: .gratis)
        await modelo.guardar(Alarm(hour: 6, minute: 0, challenge: .pasos))
        // La segunda ni entra —la corta el plan—, pero aunque el disco tuviera
        // dos encendidas de una epoca Pro, lo efectivo deja una sola.
        #expect(modelo.activas.count <= 1)
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
        // Las fechas van a mano: creadas asi seguidas, `Date()` puede darles la
        // misma y entonces desempata el `id`, que es aleatorio. El test miraba
        // "la de arriba" y una vez de cada quince salia la otra.
        let vieja = Alarm(
            hour: 6, minute: 0, weekdays: [.lunes, .martes], challenge: .pasos,
            creadaEn: Date(timeIntervalSince1970: 1_000)
        )
        let ultima = Alarm(
            hour: 7, minute: 0, weekdays: [.sabado], challenge: .pasos,
            creadaEn: Date(timeIntervalSince1970: 2_000)
        )
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

/// Un programador que programa bien pero no sabe decir que tiene puesto.
///
/// Es el caso real del `com.apple.AlarmKit code=0`: consultar es lo unico que
/// falla, y eso no puede impedir que se programe.
private actor ProgramadorMudo: AlarmScheduling {
    struct NoContesta: Error {}
    private(set) var puestas: Set<Alarm.ID> = []

    func authorizationState() async -> AlarmAuthorizationState { .autorizado }
    func requestAuthorization() async throws -> AlarmAuthorizationState { .autorizado }
    func schedule(_ alarm: Alarm) async throws { puestas.insert(alarm.id) }
    func cancel(alarmID: Alarm.ID) async throws { puestas.remove(alarmID) }
    func scheduledAlarmIDs() async throws -> Set<Alarm.ID> { throw NoContesta() }
    func silenceCurrentAlarm() async {}
    func resumeCurrentAlarm() async {}
}

/// Un programador al que se le atraganta una alarma concreta y las demas le
/// entran bien.
private actor ProgramadorConUnaMala: AlarmScheduling {
    private let mala: Alarm.ID
    private(set) var puestas: Set<Alarm.ID> = []

    init(mala: Alarm.ID) { self.mala = mala }

    func authorizationState() async -> AlarmAuthorizationState { .autorizado }
    func requestAuthorization() async throws -> AlarmAuthorizationState { .autorizado }

    func schedule(_ alarm: Alarm) async throws {
        guard alarm.id != mala else {
            throw AlarmSchedulerError.fallaDeAlarmKit(
                descripcion: "Error Domain=com.apple.AlarmKit code=0 \"(null)\""
            )
        }
        puestas.insert(alarm.id)
    }

    func cancel(alarmID: Alarm.ID) async throws { puestas.remove(alarmID) }
    func scheduledAlarmIDs() async throws -> Set<Alarm.ID> { puestas }
    func silenceCurrentAlarm() async {}
    func resumeCurrentAlarm() async {}
}

/// Un programador que tarda en programar, para poder mirar que pasa mientras.
private actor ProgramadorLento: AlarmScheduling {
    private(set) var puestas: Set<Alarm.ID> = []
    /// Si en algun momento hubo dos `schedule` a la vez.
    private(set) var seSolaparon = false
    private var enCurso = 0

    func authorizationState() async -> AlarmAuthorizationState { .autorizado }
    func requestAuthorization() async throws -> AlarmAuthorizationState { .autorizado }

    func schedule(_ alarm: Alarm) async throws {
        enCurso += 1
        if enCurso > 1 { seSolaparon = true }
        try? await Task.sleep(for: .milliseconds(30))
        enCurso -= 1
        puestas.insert(alarm.id)
    }

    func cancel(alarmID: Alarm.ID) async throws { puestas.remove(alarmID) }
    func scheduledAlarmIDs() async throws -> Set<Alarm.ID> { puestas }
    func silenceCurrentAlarm() async {}
    func resumeCurrentAlarm() async {}
}

/// Un programador que se queda parado dentro de `schedule` hasta que el test lo
/// suelta. Con el se mira que pasa mientras una sincronizacion esta a medias,
/// sin depender de ningun `sleep` ni de que maquina lo corra.
private actor ProgramadorConFreno: AlarmScheduling {
    private(set) var puestas: Set<Alarm.ID> = []
    private var frenados: [CheckedContinuation<Void, Never>] = []
    private var suelto = false
    private var quienEspera: CheckedContinuation<Void, Never>?

    /// Vuelve cuando hay alguien parado dentro de `schedule`.
    func esperarAQueSeFrene() async {
        guard frenados.isEmpty else { return }
        await withCheckedContinuation { quienEspera = $0 }
    }

    func soltar() {
        suelto = true
        frenados.forEach { $0.resume() }
        frenados = []
    }

    func authorizationState() async -> AlarmAuthorizationState { .autorizado }
    func requestAuthorization() async throws -> AlarmAuthorizationState { .autorizado }

    func schedule(_ alarm: Alarm) async throws {
        if !suelto {
            await withCheckedContinuation { continuacion in
                frenados.append(continuacion)
                quienEspera?.resume()
                quienEspera = nil
            }
        }
        puestas.insert(alarm.id)
    }

    func cancel(alarmID: Alarm.ID) async throws { puestas.remove(alarmID) }
    func scheduledAlarmIDs() async throws -> Set<Alarm.ID> { puestas }
    func silenceCurrentAlarm() async {}
    func resumeCurrentAlarm() async {}
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
