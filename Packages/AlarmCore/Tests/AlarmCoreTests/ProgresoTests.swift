import Testing
import Foundation
@testable import AlarmCore

@Suite("Niveles e insignias")
struct ProgresoTests {

    // MARK: - Niveles

    @Test("Un usuario recien instalado ya tiene nivel, no esta fuera de la tabla")
    func usuarioNuevoTieneNivel() {
        #expect(Niveles.nivel(de: StreakState()) == Niveles.primero)
        #expect(Niveles.primero.desde == 0)
    }

    @Test("La escalera esta ordenada y no deja huecos entre tramos")
    func escaleraCoherente() {
        let numeros = Niveles.todos.map(\.numero)
        #expect(numeros == Array(1...Niveles.todos.count))

        for (nivel, siguiente) in zip(Niveles.todos, Niveles.todos.dropFirst()) {
            #expect(nivel.hasta == siguiente.desde, "el tramo de un nivel tiene que acabar donde empieza el siguiente")
            #expect(nivel.desde < siguiente.desde)
        }
        #expect(Niveles.ultimo.hasta == nil, "el ultimo nivel no tiene techo")
    }

    @Test("Se sube justo al alcanzar el umbral, no un dia antes")
    func umbralExacto() {
        for nivel in Niveles.todos where nivel.desde > 0 {
            #expect(Niveles.nivel(racha: nivel.desde) == nivel)
            #expect(Niveles.nivel(racha: nivel.desde - 1).numero == nivel.numero - 1)
        }
    }

    @Test("Pasarse del ultimo umbral deja en el ultimo nivel")
    func techoDeLaEscalera() {
        #expect(Niveles.nivel(racha: 10_000) == Niveles.ultimo)
        #expect(Niveles.siguiente(a: Niveles.ultimo) == nil)
    }

    @Test("La tabla de niveles es la del sistema de diseno, tramo por tramo")
    func laTablaNoSePuedeDesviar() {
        // Clavada aqui a proposito. El nivel se pinta en la pantalla de racha, y
        // si esta tabla y la del diseno dejan de coincidir, el usuario ve un
        // nivel distinto segun donde mire. Ya paso una vez.
        let esperada = [(1, 0), (2, 3), (3, 7), (4, 14), (5, 30), (6, 60)]
        #expect(Niveles.todos.map { ($0.numero, $0.desde) }.elementsEqual(esperada, by: ==))
    }

    @Test("Romper la racha baja de nivel")
    func romperLaRachaBajaDeNivel() {
        // Decision de producto: el nivel va con la racha actual, no con lo
        // acumulado. Es una lectura de como vas ahora, no un trofeo, asi que
        // se pierde con ella.
        let alarmID = UUID()
        var state = StreakState(current: 40, best: 40, livesRemaining: 0,
                                livesRefilledYearMonth: Day(year: 2026, month: 8, day: 1).yearMonth,
                                lastCountedDay: Day(year: 2026, month: 8, day: 9),
                                diasCompletadosTotales: 40)
        #expect(Niveles.nivel(de: state).numero == 5)

        state = StreakEngine.apply(outcome: .fallado(.ignorada), on: Day(year: 2026, month: 8, day: 10),
                                   alarmID: alarmID, challenge: .pasos, to: state,
                                   plan: .pro).state

        #expect(state.current == 0)
        #expect(Niveles.nivel(de: state) == Niveles.primero, "sin racha, se vuelve al primer nivel")
        #expect(state.diasCompletadosTotales == 40, "lo acumulado no se toca: sostiene insignias y estadisticas")
        #expect(state.best == 40, "y el record tampoco")
    }

    @Test("El acumulado sube un dia por reto completado, y solo uno")
    func acumuladoSubeUnaVezPorDia() {
        let alarmID = UUID()
        var state = StreakState()
        state = StreakEngine.apply(outcome: .completado, on: Day(year: 2026, month: 8, day: 1),
                                   alarmID: alarmID, challenge: .pasos, to: state,
                                   plan: .pro).state
        #expect(state.diasCompletadosTotales == 1)

        // El mismo dia otra vez no cuenta: idempotencia del motor.
        state = StreakEngine.apply(outcome: .completado, on: Day(year: 2026, month: 8, day: 1),
                                   alarmID: alarmID, challenge: .pasos, to: state,
                                   plan: .pro).state
        #expect(state.diasCompletadosTotales == 1, "repetir el dia regalaria insignias")
    }

    @Test("Una vida salva la racha pero no suma dia acumulado")
    func laVidaNoSumaAlAcumulado() {
        let state = StreakEngine.apply(outcome: .fallado(.abandono), on: Day(year: 2026, month: 8, day: 2),
                                       alarmID: nil, challenge: nil,
                                       to: StreakState(current: 5, best: 5, diasCompletadosTotales: 5),
                                       plan: .pro).state
        #expect(state.current == 5, "la vida congela")
        #expect(state.diasCompletadosTotales == 5, "pero no te levantaste: no cuenta como dia hecho")
    }

    @Test("El progreso mide el tramo del nivel actual, no la racha entera")
    func progresoDelTramo() {
        // Nivel 3 va de racha 7 a racha 14: tramo de 7 dias.
        let nivel = Niveles.nivel(racha: 10)
        #expect(nivel.numero == 3)
        #expect(nivel.diasQueFaltan(conRacha: 10) == 4)
        #expect(abs(nivel.progreso(conRacha: 10) - 3.0 / 7.0) < 0.0001)
    }

    @Test("En el ultimo nivel el progreso esta lleno y no falta nada")
    func progresoEnElTecho() {
        let nivel = Niveles.nivel(racha: 900)
        #expect(nivel == Niveles.ultimo)
        #expect(nivel.progreso(conRacha: 900) == 1)
        #expect(nivel.diasQueFaltan(conRacha: 900) == 0)
    }

    @Test("El progreso no se sale de sus limites")
    func progresoAcotado() {
        for nivel in Niveles.todos {
            for racha in [0, 1, 5, 13, 29, 59, 400] {
                let p = nivel.progreso(conRacha: racha)
                #expect(p >= 0 && p <= 1, "nivel \(nivel.numero) con racha \(racha) dio \(p)")
            }
        }
    }

    @Test("El ascenso se avisa una sola vez, y bajar no se avisa")
    func ascensoSoloUnaVez() {
        let antes = StreakState(current: 2, best: 2, diasCompletadosTotales: 2)
        let justo = StreakState(current: 3, best: 3, diasCompletadosTotales: 3)
        let despues = StreakState(current: 4, best: 4, diasCompletadosTotales: 4)

        #expect(Niveles.ascenso(de: antes, a: justo)?.numero == 2)
        #expect(Niveles.ascenso(de: justo, a: despues) == nil, "seguir en el mismo nivel no es un ascenso")
        #expect(Niveles.ascenso(de: justo, a: justo) == nil)

        let rota = StreakState(current: 0, best: 3, diasCompletadosTotales: 3)
        #expect(Niveles.ascenso(de: justo, a: rota) == nil, "bajar no es un ascenso: ya se avisa de la racha rota")
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
