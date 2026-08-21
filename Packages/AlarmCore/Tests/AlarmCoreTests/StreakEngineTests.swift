import Testing
import Foundation
@testable import AlarmCore

// Este banco prueba el motor con Pro, que es el plan que tiene vidas. El plan
// gratis no tiene ninguna y su comportamiento se prueba aparte, en
// `LimitesDelPlanTests`.
@Suite("Motor de rachas")
struct StreakEngineTests {

    private let alarmID = UUID()
    private func day(_ d: Int, month: Int = 8, year: Int = 2026) -> Day {
        Day(year: year, month: month, day: d)
    }

    private func apply(
        _ outcome: DayOutcome,
        _ d: Day,
        to state: StreakState,
        plan: PlanDeSuscripcion = .pro
    ) -> StreakState {
        StreakEngine.apply(outcome: outcome, on: d, alarmID: alarmID, challenge: .pasos,
                           to: state, plan: plan).state
    }

    @Test("Completar el reto suma un dia y actualiza el record")
    func completarSuma() {
        var state = StreakState()
        state = apply(.completado, day(1), to: state)
        state = apply(.completado, day(2), to: state)
        #expect(state.current == 2)
        #expect(state.best == 2)
    }

    @Test("Fallar con vidas mantiene la racha pero no la incrementa")
    func vidaCongela() {
        var state = StreakState()
        state = apply(.completado, day(1), to: state)
        state = apply(.fallado(.paroSinReto), day(2), to: state)
        #expect(state.current == 1, "la vida congela la racha, no la hace avanzar")
        #expect(state.livesRemaining == 1)
    }

    @Test("Fallar sin vidas rompe la racha pero conserva el record")
    func sinVidasRompe() {
        var state = StreakState(current: 10, best: 10, livesRemaining: 0,
                                livesRefilledYearMonth: day(5).yearMonth)
        state = apply(.fallado(.abandono), day(5), to: state)
        #expect(state.current == 0)
        #expect(state.best == 10)
    }

    @Test("Las cuatro formas de fallar penalizan igual")
    func todosLosFallosPenalizanIgual() {
        let razones: [FailureReason] = [.paroSinReto, .abandono, .appTerminada, .ignorada]
        for razon in razones {
            let sinVidas = StreakState(current: 7, livesRemaining: 0,
                                       livesRefilledYearMonth: day(5).yearMonth)
            let state = apply(.fallado(razon), day(5), to: sinVidas)
            #expect(state.current == 0, "\(razon) deberia romper la racha")
        }
    }

    @Test("Las vidas se reponen al cambiar de mes y no se acumulan")
    func vidasNoSeAcumulan() {
        var state = StreakState(current: 3, livesRemaining: 2, livesRefilledYearMonth: day(1).yearMonth)
        state = apply(.fallado(.abandono), day(10), to: state)
        #expect(state.livesRemaining == 1)

        // Mes nuevo: vuelve a 2, no a 3.
        state = StreakEngine.refillingLives(state, on: day(1, month: 9), plan: .pro)
        #expect(state.livesRemaining == StreakState.livesPerMonth)
    }

    @Test("Un mes sin abrir la app repone las vidas igualmente")
    func reposicionTrasMesesInactivo() {
        let state = StreakState(livesRemaining: 0, livesRefilledYearMonth: Day(year: 2026, month: 3, day: 1).yearMonth)
        let repuesto = StreakEngine.refillingLives(state, on: day(4, month: 11), plan: .pro)
        #expect(repuesto.livesRemaining == StreakState.livesPerMonth)
    }

    @Test("El mismo dia no se cuenta dos veces")
    func idempotencia() {
        var state = StreakState()
        state = apply(.completado, day(1), to: state)
        let repetido = apply(.completado, day(1), to: state)
        #expect(repetido.current == 1, "reintentar el mismo dia no debe inflar la racha")
    }

    @Test("Un dia anterior al ultimo contado no altera el estado")
    func noSeReescribeElPasado() {
        var state = StreakState()
        state = apply(.completado, day(5), to: state)
        let atrasado = apply(.fallado(.ignorada), day(3), to: state)
        #expect(atrasado.current == 1)
        #expect(atrasado.livesRemaining == StreakState.livesPerMonth, "no debe gastar una vida por un dia viejo")
    }

    @Test("El registro guardado refleja que la vida absorbio el fallo")
    func registroReflejaLaVida() {
        let result = StreakEngine.apply(
            outcome: .fallado(.appTerminada), on: day(2),
            alarmID: alarmID, challenge: .sentadillas, to: StreakState(current: 4),
            plan: .pro
        )
        #expect(result.record?.outcome == .salvadoPorVida(.appTerminada))
    }
}
