import Testing
import Foundation
@testable import AlarmCore

/// El almacen de mentira de `ResolutorDeDiaTests` no se puede compartir entre
/// ficheros por ser `private`, y aqui hace falta uno igual. Se repite a
/// proposito: son dos bancos independientes y encadenarlos haria que tocar uno
/// rompiera el otro.
private actor AlmacenDePrueba: AlmacenDeRachas {
    var estado: StreakState
    var registros: [Day: DayRecord] = [:]
    var pendiente: PendingChallenge?

    init(estado: StreakState, pendiente: PendingChallenge? = nil) {
        self.estado = estado
        self.pendiente = pendiente
    }

    func rachaActual() throws -> StreakState { estado }
    func retoPendiente() throws -> PendingChallenge? { pendiente }

    func confirmarDia(estado nuevo: StreakState, registro: DayRecord?) throws {
        estado = nuevo
        if let registro { registros[registro.day] = registro }
        pendiente = nil
    }
}

@Suite("Dias perdidos")
struct DiasPerdidosTests {

    /// Gregoriano y en UTC, para que el banco de pruebas de lo mismo en Madrid
    /// que en Tokio que en el CI.
    private var calendario: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    /// Agosto de 2026: el 1 cae en sabado, asi que los laborables son 3-7,
    /// 10-14, 17-21 y 24-28.
    private func dia(_ d: Int, mes: Int = 8, ano: Int = 2026) -> Day {
        Day(year: ano, month: mes, day: d)
    }

    private let deLunesAViernes = Alarm(
        hour: 6, minute: 30,
        weekdays: [.lunes, .martes, .miercoles, .jueves, .viernes],
        challenge: .pasos
    )

    private func perdidos(
        desde ultimo: Day?,
        hasta hoy: Day,
        alarmas: [Alarm]? = nil
    ) -> [Day] {
        DiasPerdidos.entre(
            ultimoContado: ultimo,
            y: hoy,
            alarmas: alarmas ?? [deLunesAViernes],
            calendario: calendario
        ).map(\.dia)
    }

    // MARK: - Que dias cuentan

    @Test("Los dias con alarma entre el ultimo contado y hoy salen como perdidos")
    func huecoEntreSemana() {
        // Conto el martes 18 y abre el viernes 21: se dejo el 19 y el 20.
        #expect(perdidos(desde: dia(18), hasta: dia(21)) == [dia(19), dia(20)])
    }

    @Test("Hoy no se juzga: todavia se puede completar")
    func hoyQuedaFuera() {
        // Si el dia en curso entrase, abrir la app a las 06:31 para hacer el
        // reto seria justo el gesto que rompe la racha.
        #expect(perdidos(desde: dia(20), hasta: dia(21)).isEmpty)
    }

    @Test("El dia siguiente al ultimo contado tampoco se cuenta dos veces")
    func elUltimoContadoQuedaFuera() {
        #expect(!perdidos(desde: dia(19), hasta: dia(21)).contains(dia(19)))
    }

    @Test("Un fin de semana sin alarma no es un dia perdido")
    func finDeSemanaLibre() {
        // Conto el viernes 21 y abre el lunes 24: el sabado y el domingo no
        // sono nada, asi que no hay nada que penalizar.
        #expect(perdidos(desde: dia(21), hasta: dia(24)).isEmpty)
    }

    @Test("Solo cuentan los dias de la semana que tiene puestos la alarma")
    func soloLosDiasDeLaAlarma() {
        let soloLunes = Alarm(hour: 7, minute: 0, weekdays: [.lunes], challenge: .sentadillas)
        // Del lunes 10 al lunes 24: por el medio solo hay un lunes, el 17.
        #expect(perdidos(desde: dia(10), hasta: dia(24), alarmas: [soloLunes]) == [dia(17)])
    }

    @Test("La alarma apagada no penaliza")
    func alarmaApagada() {
        var apagada = deLunesAViernes
        apagada.isEnabled = false
        #expect(perdidos(desde: dia(18), hasta: dia(21), alarmas: [apagada]).isEmpty)
    }

    @Test("La alarma de un solo uso no penaliza ningun dia")
    func alarmaDeUnSoloUso() {
        // Sin dias de la semana no hay forma de saber que dia sono, y ante la
        // duda no se inventa un fallo. Es el caso del plan gratis entero.
        let suelta = Alarm(hour: 6, minute: 0, weekdays: [], challenge: .pasos)
        #expect(perdidos(desde: dia(18), hasta: dia(21), alarmas: [suelta]).isEmpty)
    }

    @Test("Sin ningun dia contado todavia no hay pasado que juzgar")
    func usuarioNuevo() {
        // Instalar la app un viernes no puede traer un ano de fallos detras.
        #expect(perdidos(desde: nil, hasta: dia(21)).isEmpty)
    }

    @Test("Un dia con dos alarmas es un solo dia perdido, el de la mas temprana")
    func dosAlarmasElMismoDia() {
        let temprana = Alarm(hour: 6, minute: 0, weekdays: [.miercoles], challenge: .pasos)
        let tardia = Alarm(hour: 8, minute: 0, weekdays: [.miercoles], challenge: .sentadillas)

        let salida = DiasPerdidos.entre(
            ultimoContado: dia(18), y: dia(21),
            alarmas: [tardia, temprana], calendario: calendario
        )

        #expect(salida.count == 1, "un dia es un dia, aunque suenen dos alarmas")
        #expect(salida.first?.dia == dia(19))
        #expect(salida.first?.alarmID == temprana.id, "se apunta la primera que sono")
        #expect(salida.first?.challenge == .pasos)
    }

    @Test("El barrido no se remonta mas de un ano")
    func topeDeUnAno() {
        // Un reloj movido a 2019 no puede convertir el arranque en miles de
        // escrituras: la racha se rompe con el primer dia perdido igual.
        let salida = perdidos(desde: dia(1, mes: 1, ano: 2019), hasta: dia(21))
        #expect(salida.count <= DiasPerdidos.topeDeDias)
        #expect(salida.first.map { $0 >= dia(21).adding(days: -DiasPerdidos.topeDeDias, calendar: calendario) } == true)
    }

    @Test("El hueco cruza el final de mes")
    func cruzaElMes() {
        // Conto el miercoles 30 de septiembre y abre el lunes 5 de octubre.
        let salida = perdidos(desde: dia(30, mes: 9), hasta: dia(5, mes: 10))
        #expect(salida == [dia(1, mes: 10), dia(2, mes: 10)], "el 3 y el 4 son sabado y domingo")
    }

    // MARK: - Lo que le hace a la racha

    @Test("Ignorar la alarma tres mananas rompe la racha")
    func ignorarRompeLaRacha() async throws {
        // El agujero que existia: sin barrido, el usuario pulsaba Stop el 19, el
        // 20 y el 21 sin abrir la app, completaba el 24 y se encontraba la racha
        // en 13 como si no hubiera pasado nada.
        let almacen = AlmacenDePrueba(
            estado: StreakState(current: 12, best: 12, livesRemaining: 0,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(18), diasCompletadosTotales: 12)
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .gratis })

        let salida = try await resolutor.resolverDiasPerdidos(
            hasta: dia(24), alarmas: [deLunesAViernes], calendario: calendario
        )

        #expect(salida.count == 3, "el 19, el 20 y el 21; el sabado y el domingo no")
        #expect(await almacen.estado.current == 0)
        #expect(await almacen.estado.best == 12, "el record no se toca")
        #expect(await almacen.estado.lastCountedDay == dia(21))
        #expect(await almacen.registros[dia(20)]?.outcome == .fallado(.ignorada))
        #expect(await almacen.registros[dia(22)] == nil, "el sabado no lleva registro")
    }

    @Test("Las vidas absorben los dias perdidos de uno en uno, por orden")
    func lasVidasSeGastanPorOrden() async throws {
        let almacen = AlmacenDePrueba(
            estado: StreakState(current: 12, best: 12, livesRemaining: 2,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(17), diasCompletadosTotales: 12)
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        // Se dejo el 18, el 19 y el 20. Las dos vidas cubren los dos primeros y
        // el tercero rompe.
        try await resolutor.resolverDiasPerdidos(
            hasta: dia(21), alarmas: [deLunesAViernes], calendario: calendario
        )

        #expect(await almacen.registros[dia(18)]?.outcome == .salvadoPorVida(.ignorada))
        #expect(await almacen.registros[dia(19)]?.outcome == .salvadoPorVida(.ignorada))
        #expect(await almacen.registros[dia(20)]?.outcome == .fallado(.ignorada))
        #expect(await almacen.estado.current == 0)
        #expect(await almacen.estado.livesRemaining == 0)
    }

    @Test("Un arranque al dia siguiente de haber cumplido no penaliza nada")
    func arranqueNormal() async throws {
        let almacen = AlmacenDePrueba(
            estado: StreakState(current: 12, best: 12,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(20), diasCompletadosTotales: 12)
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        let salida = try await resolutor.resolverDiasPerdidos(
            hasta: dia(21), alarmas: [deLunesAViernes], calendario: calendario
        )

        #expect(salida.isEmpty)
        #expect(await almacen.estado.current == 12)
        #expect(await almacen.registros.isEmpty)
    }

    @Test("Barrer dos veces el mismo arranque no penaliza dos veces")
    func barridoIdempotente() async throws {
        let almacen = AlmacenDePrueba(
            estado: StreakState(current: 12, best: 12, livesRemaining: 2,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(19), diasCompletadosTotales: 12)
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        try await resolutor.resolverDiasPerdidos(hasta: dia(21), alarmas: [deLunesAViernes], calendario: calendario)
        let vidasTrasElPrimero = await almacen.estado.livesRemaining

        let segundo = try await resolutor.resolverDiasPerdidos(hasta: dia(21), alarmas: [deLunesAViernes], calendario: calendario)

        #expect(segundo.isEmpty, "el primer barrido ya movio la frontera")
        #expect(await almacen.estado.livesRemaining == vidasTrasElPrimero, "ni una vida de mas")
    }

    // MARK: - El historial no se pisa

    @Test("Un dia ya completado no se reescribe con el fallo del rastro huerfano")
    func elRastroHuerfanoNoPisaUnDiaHecho() async throws {
        // Dos alarmas el mismo dia: la primera se completa, la segunda se
        // empieza y muere la app a mitad. Al arrancar, el rastro trae un
        // `.appTerminada` del dia 5, que ya esta contado como completado.
        let almacen = AlmacenDePrueba(
            estado: StreakState(current: 12, best: 12,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(5), diasCompletadosTotales: 12),
            pendiente: PendingChallenge(alarmID: UUID(), challenge: .sentadillas,
                                        day: dia(5), startedAt: Date(timeIntervalSince1970: 0))
        )
        await almacen.sembrar(DayRecord(day: dia(5), alarmID: nil, challenge: .pasos, outcome: .completado))

        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })
        let r = try #require(try await resolutor.resolverRetoHuerfano())

        #expect(r.yaEstabaContado)
        #expect(r.registro == nil, "no hay nada que escribir: el dia ya tiene su registro")
        #expect(await almacen.registros[dia(5)]?.outcome == .completado,
                "el calendario no puede pintar un fallo en un dia que si se hizo")
        #expect(await almacen.pendiente == nil, "pero el rastro se cierra igual")
    }
}

extension AlmacenDePrueba {
    func sembrar(_ registro: DayRecord) { registros[registro.day] = registro }
}
