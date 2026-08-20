import Testing
import Foundation
@testable import AlarmCore

@Suite("Niveles e insignias")
struct ProgresoTests {

    // MARK: - Niveles

    @Test("Un usuario recien instalado ya tiene nivel, no esta fuera de la tabla")
    func usuarioNuevoTieneNivel() {
        #expect(Niveles.nivel(de: StreakState()) == Niveles.primero)
        #expect(Niveles.primero.diasNecesarios == 0)
    }

    @Test("La escalera esta ordenada y sin escalones repetidos")
    func escaleraCoherente() {
        let numeros = Niveles.todos.map(\.numero)
        let dias = Niveles.todos.map(\.diasNecesarios)
        #expect(numeros == Array(1...Niveles.todos.count))
        #expect(dias == dias.sorted())
        #expect(Set(dias).count == dias.count, "dos niveles con el mismo umbral harian inalcanzable uno de los dos")
    }

    @Test("Se sube justo al alcanzar el umbral, no un dia antes")
    func umbralExacto() {
        for nivel in Niveles.todos where nivel.diasNecesarios > 0 {
            #expect(Niveles.nivel(diasCompletados: nivel.diasNecesarios) == nivel)
            #expect(Niveles.nivel(diasCompletados: nivel.diasNecesarios - 1).numero == nivel.numero - 1)
        }
    }

    @Test("Pasarse del ultimo umbral deja en el ultimo nivel")
    func techoDeLaEscalera() {
        #expect(Niveles.nivel(diasCompletados: 10_000) == Niveles.ultimo)
        #expect(Niveles.siguiente(a: Niveles.ultimo) == nil)
    }

    @Test("Romper la racha no baja de nivel")
    func perderLaRachaNoBajaNivel() {
        let alarmID = UUID()
        var state = StreakState(current: 40, best: 40, livesRemaining: 0,
                                livesRefilledYearMonth: Day(year: 2026, month: 8, day: 1).yearMonth,
                                lastCountedDay: Day(year: 2026, month: 8, day: 9),
                                diasCompletadosTotales: 40)
        let nivelAntes = Niveles.nivel(de: state)

        state = StreakEngine.apply(outcome: .fallado(.ignorada), on: Day(year: 2026, month: 8, day: 10),
                                   alarmID: alarmID, challenge: .pasos, to: state).state

        #expect(state.current == 0, "la racha si se pierde")
        #expect(Niveles.nivel(de: state) == nivelAntes, "el nivel no, o el fallo castigaria dos veces")
        #expect(state.diasCompletadosTotales == 40)
    }

    @Test("El acumulado sube un dia por reto completado, y solo uno")
    func acumuladoSubeUnaVezPorDia() {
        let alarmID = UUID()
        var state = StreakState()
        state = StreakEngine.apply(outcome: .completado, on: Day(year: 2026, month: 8, day: 1),
                                   alarmID: alarmID, challenge: .pasos, to: state).state
        #expect(state.diasCompletadosTotales == 1)

        // El mismo dia otra vez no cuenta: idempotencia del motor.
        state = StreakEngine.apply(outcome: .completado, on: Day(year: 2026, month: 8, day: 1),
                                   alarmID: alarmID, challenge: .pasos, to: state).state
        #expect(state.diasCompletadosTotales == 1, "repetir el dia regalaria niveles")
    }

    @Test("Una vida salva la racha pero no suma dia acumulado")
    func laVidaNoSumaAlAcumulado() {
        let state = StreakEngine.apply(outcome: .fallado(.abandono), on: Day(year: 2026, month: 8, day: 2),
                                       alarmID: nil, challenge: nil,
                                       to: StreakState(current: 5, best: 5, diasCompletadosTotales: 5)).state
        #expect(state.current == 5, "la vida congela")
        #expect(state.diasCompletadosTotales == 5, "pero no te levantaste: no cuenta como dia hecho")
    }

    @Test("El progreso mide el tramo del nivel actual, no el total")
    func fraccionDelTramo() {
        // Nivel 3 (7 dias) -> nivel 4 (15 dias): tramo de 8 dias.
        let p = Niveles.progreso(de: StreakState(diasCompletadosTotales: 11))
        #expect(p.nivel.numero == 3)
        #expect(p.siguiente?.numero == 4)
        #expect(p.diasQueFaltan == 4)
        #expect(abs(p.fraccion - 0.5) < 0.0001)
    }

    @Test("En el ultimo nivel el progreso esta lleno y no falta nada")
    func progresoEnElTecho() {
        let p = Niveles.progreso(de: StreakState(diasCompletadosTotales: 900))
        #expect(p.siguiente == nil)
        #expect(p.fraccion == 1)
        #expect(p.diasQueFaltan == 0)
    }

    @Test("El ascenso se avisa una sola vez")
    func ascensoSoloUnaVez() {
        let antes = StreakState(diasCompletadosTotales: 2)
        let justo = StreakState(diasCompletadosTotales: 3)
        let despues = StreakState(diasCompletadosTotales: 4)

        #expect(Niveles.ascenso(de: antes, a: justo)?.numero == 2)
        #expect(Niveles.ascenso(de: justo, a: despues) == nil, "seguir en el mismo nivel no es un ascenso")
        #expect(Niveles.ascenso(de: justo, a: justo) == nil)
    }

    // MARK: - Insignias

    @Test("Sin nada hecho no hay ninguna insignia")
    func usuarioNuevoSinInsignias() {
        #expect(Insignias.concedidas(StreakState()).isEmpty)
    }

    @Test("Cada insignia se concede en su umbral exacto")
    func umbralesDeInsignias() {
        #expect(Insignia.primerDia.concedida(StreakState(diasCompletadosTotales: 1)))
        #expect(!Insignia.primerDia.concedida(StreakState(diasCompletadosTotales: 0)))

        #expect(Insignia.semanaEnPie.concedida(StreakState(best: 7)))
        #expect(!Insignia.semanaEnPie.concedida(StreakState(best: 6)))

        #expect(Insignia.mesEnPie.concedida(StreakState(best: 30)))
        #expect(!Insignia.mesEnPie.concedida(StreakState(best: 29)))

        #expect(Insignia.cienSeguidos.concedida(StreakState(best: 100)))
        #expect(!Insignia.cienSeguidos.concedida(StreakState(best: 99)))

        #expect(Insignia.anoEnPie.concedida(StreakState(best: 365)))
        #expect(!Insignia.anoEnPie.concedida(StreakState(best: 364)))

        #expect(Insignia.veterano.concedida(StreakState(diasCompletadosTotales: 365)))
        #expect(!Insignia.veterano.concedida(StreakState(diasCompletadosTotales: 364)))
    }

    @Test("Una insignia ganada no se pierde al romperse la racha")
    func insigniaNoSeQuita() {
        let conRacha = StreakState(current: 30, best: 30, diasCompletadosTotales: 30)
        let rota = StreakState(current: 0, best: 30, diasCompletadosTotales: 30)
        #expect(Insignias.concedidas(conRacha) == Insignias.concedidas(rota))
        #expect(Insignias.concedidas(rota).contains(.mesEnPie))
    }

    @Test("Las insignias nuevas son solo las que no se tenian")
    func insigniasNuevas() {
        let antes = StreakState(current: 6, best: 6, diasCompletadosTotales: 6)
        let despues = StreakState(current: 7, best: 7, diasCompletadosTotales: 7)
        #expect(Insignias.nuevas(de: antes, a: despues) == [.semanaEnPie])
        #expect(Insignias.nuevas(de: despues, a: despues).isEmpty)
    }

    @Test("Los umbrales altos arrastran los bajos, no los saltan")
    func lasInsigniasSeAcumulan() {
        let veterano = StreakState(current: 400, best: 400, diasCompletadosTotales: 400)
        #expect(Insignias.concedidas(veterano) == Set(Insignia.allCases))
    }

    @Test("Ningun identificador de insignia cambia sin darse cuenta")
    func identificadoresEstables() {
        // Se guardan en disco y viajan al ranking: renombrar un `rawValue`
        // significa que un usuario pierde la insignia al actualizar la app.
        #expect(Set(Insignia.allCases.map(\.rawValue)) == [
            "primerDia", "semanaEnPie", "mesEnPie", "cienSeguidos", "anoEnPie", "veterano"
        ])
    }
}
