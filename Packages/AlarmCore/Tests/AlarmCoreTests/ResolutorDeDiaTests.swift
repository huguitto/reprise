import Testing
import Foundation
@testable import AlarmCore

/// Almacen de mentira, en memoria. Sirve para probar el servicio sin SwiftData:
/// aqui se prueba la coreografia (leer, aplicar, escribir de una pieza), y en
/// `Persistence` se prueba que la escritura de verdad sobrevive al disco.
private actor AlmacenFalso: AlmacenDeRachas {
    var estado: StreakState
    var registros: [Day: DayRecord] = [:]
    var pendiente: PendingChallenge?
    var confirmaciones = 0
    /// Simula que el disco falla a mitad de la escritura.
    var falla = false

    init(estado: StreakState = StreakState(), pendiente: PendingChallenge? = nil) {
        self.estado = estado
        self.pendiente = pendiente
    }

    struct DiscoRoto: Error {}

    func rachaActual() throws -> StreakState { estado }
    func retoPendiente() throws -> PendingChallenge? { pendiente }

    func confirmarDia(estado nuevo: StreakState, registro: DayRecord?) throws {
        confirmaciones += 1
        // Todo o nada: si falla, no se escribe ni media escritura.
        if falla { throw DiscoRoto() }
        estado = nuevo
        // `nil` = el dia ya estaba contado. Se cierra el rastro y no se toca el
        // historial, igual que hace el almacen de verdad.
        if let registro { registros[registro.day] = registro }
        pendiente = nil
    }

    func romperElDisco() { falla = true }
}

@Suite("Resolucion del dia")
struct ResolutorDeDiaTests {

    private let alarmID = UUID()
    private func dia(_ d: Int, mes: Int = 8) -> Day { Day(year: 2026, month: mes, day: d) }

    private func pendiente(_ d: Day, reto: ChallengeType = .pasos) -> PendingChallenge {
        PendingChallenge(alarmID: alarmID, challenge: reto, day: d, startedAt: Date(timeIntervalSince1970: 0))
    }

    @Test("Completar el reto guarda estado y registro juntos")
    func completarGuardaLasDosMitades() async throws {
        let almacen = AlmacenFalso(pendiente: pendiente(dia(1)))
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        let r = try await resolutor.resolver(.completado, dia: dia(1), alarmID: alarmID, challenge: .pasos, duration: 42)

        #expect(r.estado.current == 1)
        #expect(await almacen.estado.current == 1, "el estado tiene que quedar escrito")
        #expect(await almacen.registros[dia(1)]?.outcome == .completado, "y el registro tambien")
        #expect(await almacen.registros[dia(1)]?.duration == 42)
    }

    @Test("Resolver el dia cierra el rastro del reto pendiente")
    func resolverCierraElRastro() async throws {
        let almacen = AlmacenFalso(pendiente: pendiente(dia(1)))
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        try await resolutor.resolver(.completado, dia: dia(1), alarmID: alarmID, challenge: .pasos)

        #expect(await almacen.pendiente == nil, "un rastro vivo penalizaria otra vez al siguiente arranque")
    }

    @Test("Si la escritura falla, el estado no se queda a medias")
    func escrituraFallidaNoDejaMedioDia() async throws {
        let almacen = AlmacenFalso(estado: StreakState(current: 9, best: 9, diasCompletadosTotales: 9),
                                   pendiente: pendiente(dia(1)))
        await almacen.romperElDisco()
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        await #expect(throws: AlmacenFalso.DiscoRoto.self) {
            try await resolutor.resolver(.completado, dia: dia(1), alarmID: self.alarmID, challenge: .pasos)
        }

        #expect(await almacen.estado.current == 9, "la racha se queda como estaba")
        #expect(await almacen.registros.isEmpty)
        #expect(await almacen.pendiente != nil, "el rastro sigue vivo, asi que el dia se reintenta al arrancar")
    }

    // MARK: - El reto huerfano

    @Test("Sin rastro pendiente no hay nada que resolver")
    func arranqueLimpio() async throws {
        let almacen = AlmacenFalso(estado: StreakState(current: 3, best: 3, diasCompletadosTotales: 3))
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        #expect(try await resolutor.resolverRetoHuerfano() == nil)
        #expect(await almacen.estado.current == 3, "un arranque normal no toca la racha")
        #expect(await almacen.confirmaciones == 0)
    }

    @Test("Matar la app a mitad del reto penaliza el dia al volver a abrir")
    func matarLaAppPenaliza() async throws {
        let almacen = AlmacenFalso(
            estado: StreakState(current: 12, best: 12, livesRemaining: 0,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(4), diasCompletadosTotales: 12),
            pendiente: pendiente(dia(5), reto: .sentadillas)
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        let r = try #require(try await resolutor.resolverRetoHuerfano())

        #expect(r.registro?.outcome == .fallado(.appTerminada))
        #expect(r.registro?.challenge == .sentadillas, "el registro conserva que reto se abandono")
        #expect(r.estado.current == 0, "sin vidas, matar la app rompe la racha")
        #expect(await almacen.pendiente == nil)
    }

    @Test("Con vidas, matar la app congela la racha en vez de romperla")
    func matarLaAppConVidas() async throws {
        let almacen = AlmacenFalso(
            estado: StreakState(current: 12, best: 12, livesRemaining: 2,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(4), diasCompletadosTotales: 12),
            pendiente: pendiente(dia(5))
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })
        let r = try #require(try await resolutor.resolverRetoHuerfano())

        #expect(r.registro?.outcome == .salvadoPorVida(.appTerminada))
        #expect(r.estado.current == 12)
        #expect(r.estado.livesRemaining == 1)
    }

    @Test("El segundo arranque ya no penaliza: el rastro se cerro en el primero")
    func noPenalizaDosVeces() async throws {
        let almacen = AlmacenFalso(
            estado: StreakState(current: 12, best: 12, livesRemaining: 0,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(4), diasCompletadosTotales: 12),
            pendiente: pendiente(dia(5))
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        try await resolutor.resolverRetoHuerfano()
        let segundo = try await resolutor.resolverRetoHuerfano()

        #expect(segundo == nil)
        #expect(await almacen.confirmaciones == 1)
    }

    @Test("El reto huerfano de hace dias penaliza el dia en que se abandono")
    func huerfanoViejo() async throws {
        // La app murio el dia 5 y el usuario no vuelve a abrirla hasta el 8.
        let almacen = AlmacenFalso(
            estado: StreakState(current: 12, best: 12, livesRemaining: 0,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(4), diasCompletadosTotales: 12),
            pendiente: pendiente(dia(5))
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        let r = try #require(try await resolutor.resolverRetoHuerfano())
        #expect(r.registro?.day == dia(5), "el fallo es del dia 5, no del dia que se abre la app")
    }

    @Test("Un dia ya contado no se cuenta otra vez, pero el rastro se cierra igual")
    func rastroDeUnDiaYaContado() async throws {
        let almacen = AlmacenFalso(
            estado: StreakState(current: 12, best: 12,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(5), diasCompletadosTotales: 12),
            pendiente: pendiente(dia(5))
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        let r = try #require(try await resolutor.resolverRetoHuerfano())

        #expect(r.yaEstabaContado)
        #expect(r.estado.current == 12, "el dia 5 ya se conto: no se toca")
        #expect(r.estado.livesRemaining == StreakState.livesPerMonth, "ni se gasta una vida de mas")
        #expect(await almacen.pendiente == nil, "pero el rastro no puede quedarse vivo para siempre")
    }

    // MARK: - Lo que la interfaz necesita saber

    @Test("La resolucion avisa del ascenso de nivel y de las insignias nuevas")
    func avisosDeProgreso() async throws {
        let almacen = AlmacenFalso(
            estado: StreakState(current: 6, best: 6,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(6), diasCompletadosTotales: 6)
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        let r = try await resolutor.resolver(.completado, dia: dia(7), alarmID: alarmID, challenge: .pasos)

        #expect(r.ascenso?.numero == 3, "el septimo dia acumulado sube al nivel 3")
        #expect(r.insigniasNuevas == [.semanaEnPie])
        #expect(!r.yaEstabaContado)
    }

    @Test("Un dia normal no inventa ascensos ni insignias")
    func diaSinAvisos() async throws {
        let almacen = AlmacenFalso(
            estado: StreakState(current: 8, best: 8,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(8), diasCompletadosTotales: 8)
        )
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        let r = try await resolutor.resolver(.completado, dia: dia(9), alarmID: alarmID, challenge: .pasos)

        #expect(r.ascenso == nil)
        #expect(r.insigniasNuevas.isEmpty)
    }
}
