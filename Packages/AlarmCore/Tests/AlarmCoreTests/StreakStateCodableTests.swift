import Testing
import Foundation
@testable import AlarmCore

@Suite("Estado guardado")
struct StreakStateCodableTests {

    @Test("Un estado guardado antes de existir el acumulado se sigue leyendo")
    func estadoViejoNoSePierde() throws {
        // Exactamente lo que habria en disco de una version anterior de la app:
        // sin `diasCompletadosTotales`. Si esto deja de decodificar, un usuario
        // con racha de 40 dias abre la app y se la encuentra a cero.
        let viejo = """
        {"current":40,"best":40,"livesRemaining":1,"livesRefilledYearMonth":24320,
         "lastCountedDay":{"year":2026,"month":8,"day":19}}
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(StreakState.self, from: viejo)

        #expect(state.current == 40)
        #expect(state.best == 40)
        #expect(state.livesRemaining == 1)
        #expect(state.livesRefilledYearMonth == 24320, "si esto llega a nil, se le reponen las vidas de balde")
        #expect(state.lastCountedDay == Day(year: 2026, month: 8, day: 19))
        #expect(state.diasCompletadosTotales == 0, "no se sabe: se empieza a contar desde ahora")
    }

    @Test("Guardar y volver a leer no cambia nada")
    func idaYVuelta() throws {
        let original = StreakState(current: 12, best: 30, livesRemaining: 1,
                                   livesRefilledYearMonth: 24320,
                                   lastCountedDay: Day(year: 2026, month: 8, day: 20),
                                   diasCompletadosTotales: 77)
        let datos = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(StreakState.self, from: datos) == original)
    }

    @Test("Un usuario nuevo se guarda con el mes a nil, que es lo que repone vidas")
    func usuarioNuevoConservaElNil() throws {
        let datos = try JSONEncoder().encode(StreakState())
        let leido = try JSONDecoder().decode(StreakState.self, from: datos)
        #expect(leido.livesRefilledYearMonth == nil)
        #expect(leido.lastCountedDay == nil)
    }
}
