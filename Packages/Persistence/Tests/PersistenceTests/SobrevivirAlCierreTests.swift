import Testing
import Foundation
import AlarmCore
@testable import Persistence

/// Lo que solo se ve con fichero de verdad: que lo guardado siga ahi cuando la
/// app se cierra y se vuelve a abrir. Cada `abrir()` es un arranque nuevo de la
/// app sobre el mismo almacen.
@Suite("Sobrevivir al cierre de la app")
struct SobrevivirAlCierreTests {

    @Test("Cerrar la app y reabrirla conserva las alarmas")
    func lasAlarmasSobreviven() async throws {
        let temporal = AlmacenTemporal()
        let alarma = alarmaDePrueba(hora: 6, minuto: 15, dias: [.martes, .jueves], reto: .sentadillas)

        do {
            let almacen = try temporal.abrir()
            try await almacen.save(alarma)
        }

        let segundoArranque = try temporal.abrir()
        #expect(try await segundoArranque.all() == [alarma])
    }

    @Test("Cerrar la app y reabrirla conserva racha, record y vidas")
    func laRachaSobrevive() async throws {
        let temporal = AlmacenTemporal()
        let estado = StreakState(current: 40, best: 55, livesRemaining: 1,
                                 livesRefilledYearMonth: dia(1).yearMonth,
                                 lastCountedDay: dia(19), diasCompletadosTotales: 120)

        do {
            let almacen = try temporal.abrir()
            try await almacen.save(estado)
        }

        let segundoArranque = try temporal.abrir()
        let leido = try await segundoArranque.load()

        #expect(leido == estado)
        #expect(leido.current == 40)
        #expect(leido.livesRemaining == 1, "las vidas gastadas siguen gastadas")
        #expect(leido.livesRefilledYearMonth == dia(1).yearMonth, "si esto vuelve a nil, se le regalan las dos vidas")
    }

    @Test("Cerrar la app y reabrirla conserva el historial de dias")
    func elHistorialSobrevive() async throws {
        let temporal = AlmacenTemporal()

        do {
            let almacen = try temporal.abrir()
            try await almacen.save(DayRecord(day: dia(1), alarmID: nil, challenge: .pasos, outcome: .completado, duration: 18))
            try await almacen.save(DayRecord(day: dia(2), alarmID: nil, challenge: .pasos, outcome: .fallado(.ignorada)))
        }

        let segundoArranque = try temporal.abrir()
        let historial = try await segundoArranque.records(from: dia(1), to: dia(2))

        #expect(historial.count == 2)
        #expect(historial.first?.duration == 18)
        #expect(historial.last?.outcome == .fallado(.ignorada))
    }

    // MARK: - Matar la app a mitad del reto

    @Test("Matar la app a mitad del reto deja el rastro en disco")
    func elRastroSobreviveALaMuerte() async throws {
        let temporal = AlmacenTemporal()
        let pendiente = PendingChallenge(alarmID: UUID(), challenge: .sentadillas,
                                         day: dia(5), startedAt: Date(timeIntervalSince1970: 500))

        do {
            let almacen = try temporal.abrir()
            // `begin` se llama antes de arrancar el reto. Aqui no se llama a
            // `clear` a proposito: es exactamente lo que pasa cuando matan la app.
            try await almacen.begin(pendiente)
        }

        let segundoArranque = try temporal.abrir()
        #expect(try await segundoArranque.current() == pendiente, "sin este rastro, matar la app sale gratis")
    }

    @Test("Matar el proceso a mitad de un reto y reabrir penaliza el dia")
    func reabrirPenaliza() async throws {
        let temporal = AlmacenTemporal()
        let alarmID = UUID()
        let racha = StreakState(current: 12, best: 12, livesRemaining: 0,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                lastCountedDay: dia(4), diasCompletadosTotales: 12)

        // Primer arranque: suena la alarma del dia 5, empieza el reto, muere la app.
        do {
            let almacen = try temporal.abrir()
            try await almacen.save(racha)
            try await almacen.begin(PendingChallenge(alarmID: alarmID, challenge: .pasos,
                                                     day: dia(5), startedAt: Date()))
        }

        // Segundo arranque: lo primero que hace la app es buscar el rastro.
        let segundoArranque = try temporal.abrir()
        let resolutor = ResolutorDeDia(almacen: segundoArranque)
        let resultado = try #require(try await resolutor.resolverRetoHuerfano())

        #expect(resultado.registro.outcome == .fallado(.appTerminada))
        #expect(resultado.estado.current == 0, "sin vidas, matar la app rompe la racha")
        #expect(try await segundoArranque.load().current == 0, "y queda escrito en disco")
        #expect(try await segundoArranque.current() == nil, "el rastro se cierra al resolverlo")

        // Tercer arranque: ya no hay nada que penalizar.
        let tercerArranque = try temporal.abrir()
        let segundoResolutor = ResolutorDeDia(almacen: tercerArranque)
        #expect(try await segundoResolutor.resolverRetoHuerfano() == nil, "no se puede penalizar dos veces el mismo dia")
        #expect(try await tercerArranque.records(from: dia(5), to: dia(5)).count == 1)
    }

    @Test("Completar el reto y reabrir conserva el dia ganado")
    func completarSobrevive() async throws {
        let temporal = AlmacenTemporal()
        let alarmID = UUID()

        do {
            let almacen = try temporal.abrir()
            try await almacen.begin(PendingChallenge(alarmID: alarmID, challenge: .pasos,
                                                     day: dia(5), startedAt: Date()))
            let resolutor = ResolutorDeDia(almacen: almacen)
            try await resolutor.resolver(.completado, dia: dia(5), alarmID: alarmID, challenge: .pasos, duration: 25)
        }

        let segundoArranque = try temporal.abrir()
        let resolutor = ResolutorDeDia(almacen: segundoArranque)

        #expect(try await segundoArranque.load().current == 1)
        #expect(try await segundoArranque.load().diasCompletadosTotales == 1)
        #expect(try await resolutor.resolverRetoHuerfano() == nil, "el reto se completo: no hay huerfano que penalizar")
    }
}
