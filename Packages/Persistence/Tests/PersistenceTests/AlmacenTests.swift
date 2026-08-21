import Testing
import Foundation
import AlarmCore
@testable import Persistence

@Suite("Almacen SwiftData")
struct AlmacenTests {

    // MARK: - Alarmas

    @Test("Una alarma guardada se lee igual que se guardo")
    func alarmaIdaYVuelta() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let alarma = alarmaDePrueba(hora: 6, minuto: 45, dias: [.lunes, .viernes, .domingo], reto: .sentadillas)

        try await almacen.save(alarma)
        let leidas = try await almacen.all()

        #expect(leidas == [alarma], "incluidos los dias de la semana y el reto")
    }

    @Test("Guardar la misma alarma otra vez la actualiza, no la duplica")
    func alarmaSeActualiza() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        var alarma = alarmaDePrueba()
        try await almacen.save(alarma)

        alarma.hour = 5
        alarma.isEnabled = false
        try await almacen.save(alarma)

        let leidas = try await almacen.all()
        #expect(leidas.count == 1, "dos filas con el mismo id son dos alarmas sonando")
        #expect(leidas.first?.hour == 5)
        #expect(leidas.first?.isEnabled == false)
    }

    @Test("Borrar una alarma no se lleva las demas por delante")
    func borrarAlarma() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let a = alarmaDePrueba(hora: 6)
        let b = alarmaDePrueba(hora: 8)
        try await almacen.save(a)
        try await almacen.save(b)

        try await almacen.delete(id: a.id)

        #expect(try await almacen.all() == [b])
    }

    @Test("Borrar una alarma que no existe no revienta")
    func borrarLoQueNoEsta() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        try await almacen.delete(id: UUID())
        #expect(try await almacen.all().isEmpty)
    }

    @Test("Las alarmas salen de la mas nueva a la mas vieja, no por hora")
    func alarmasOrdenadas() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let ayer = Date(timeIntervalSince1970: 1_000_000)
        // Las horas van al reves que las fechas justo para que un orden por hora
        // no pueda colarse por casualidad.
        try await almacen.save(alarmaDePrueba(hora: 6, minuto: 5, creadaEn: ayer))
        try await almacen.save(alarmaDePrueba(hora: 6, minuto: 30, creadaEn: ayer.addingTimeInterval(60)))
        try await almacen.save(alarmaDePrueba(hora: 9, minuto: 0, creadaEn: ayer.addingTimeInterval(120)))

        let horas = try await almacen.all().map { ($0.hour, $0.minute) }
        #expect(horas.map(\.0) == [9, 6, 6])
        #expect(horas.map(\.1) == [0, 30, 5])
    }

    @Test("Editar una alarma no la mueve de sitio")
    func editarNoLaSube() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let vieja = alarmaDePrueba(hora: 6, minuto: 0, creadaEn: Date(timeIntervalSince1970: 1_000_000))
        try await almacen.save(vieja)
        try await almacen.save(alarmaDePrueba(hora: 7, minuto: 0, creadaEn: Date(timeIntervalSince1970: 2_000_000)))

        // Se reescribe la vieja con una fecha de creacion nueva, que es lo que
        // llegaria de una pantalla que la reconstruyera desde cero.
        var editada = vieja
        editada.hour = 8
        editada.creadaEn = Date()
        try await almacen.save(editada)

        let guardadas = try await almacen.all()
        #expect(guardadas.count == 2)
        #expect(guardadas.last?.id == vieja.id, "editarla la ha mandado arriba: la lista bailaria al guardar")
        #expect(guardadas.last?.hour == 8, "el cambio de hora si tiene que haberse guardado")
    }

    @Test("Una alarma sin dias es de un solo uso y se guarda como tal")
    func alarmaDeUnSoloUso() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let alarma = alarmaDePrueba(dias: [])
        try await almacen.save(alarma)

        let leida = try #require(try await almacen.all().first)
        #expect(leida.weekdays.isEmpty)
        #expect(leida.repeats == false)
    }

    // MARK: - Estado de la racha

    @Test("Un almacen vacio devuelve el estado de un usuario nuevo")
    func estadoDeUsuarioNuevo() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let estado = try await almacen.load()

        #expect(estado == StreakState())
        #expect(estado.livesRefilledYearMonth == nil, "en un usuario nuevo el nil es lo correcto: le tocan sus vidas")
    }

    @Test("El estado se guarda entero, con el ultimo dia contado")
    func estadoIdaYVuelta() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let estado = StreakState(current: 12, best: 30, livesRemaining: 1,
                                 livesRefilledYearMonth: dia(1).yearMonth,
                                 lastCountedDay: dia(19), diasCompletadosTotales: 77)

        try await almacen.save(estado)

        #expect(try await almacen.load() == estado)
    }

    @Test("Guardar el estado dos veces deja una sola fila")
    func estadoEsFilaUnica() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        try await almacen.save(StreakState(current: 1))
        try await almacen.save(StreakState(current: 2))

        #expect(try await almacen.load().current == 2, "dos filas de estado harian que la racha dependiera de cual se lea")
    }

    // MARK: - Registro diario

    @Test("Los tres resultados posibles se guardan con su motivo")
    func registroDeLosTresResultados() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let registros = [
            DayRecord(day: dia(1), alarmID: UUID(), challenge: .pasos, outcome: .completado, duration: 31.5),
            DayRecord(day: dia(2), alarmID: UUID(), challenge: .sentadillas, outcome: .fallado(.paroSinReto)),
            DayRecord(day: dia(3), alarmID: nil, challenge: nil, outcome: .salvadoPorVida(.appTerminada))
        ]
        for r in registros { try await almacen.save(r) }

        #expect(try await almacen.records(from: dia(1), to: dia(3)) == registros)
    }

    @Test("El rango de dias no se lleva los de fuera")
    func rangoDeDias() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        for d in [dia(28, mes: 7), dia(1), dia(15), dia(31), dia(1, mes: 9)] {
            try await almacen.save(DayRecord(day: d, alarmID: nil, challenge: .pasos, outcome: .completado))
        }

        let agosto = try await almacen.records(from: dia(1), to: dia(31))
        #expect(agosto.map(\.day) == [dia(1), dia(15), dia(31)], "los bordes entran, los meses vecinos no")
    }

    @Test("El rango cruza el fin de ano sin perder dias")
    func rangoCruzandoAno() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        for d in [dia(30, mes: 12, ano: 2026), dia(31, mes: 12, ano: 2026), dia(1, mes: 1, ano: 2027)] {
            try await almacen.save(DayRecord(day: d, alarmID: nil, challenge: .pasos, outcome: .completado))
        }

        let cruce = try await almacen.records(from: dia(31, mes: 12, ano: 2026), to: dia(1, mes: 1, ano: 2027))
        #expect(cruce.count == 2)
    }

    @Test("Un dia solo tiene un registro, aunque se guarde dos veces")
    func registroUnicoPorDia() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        try await almacen.save(DayRecord(day: dia(5), alarmID: nil, challenge: .pasos, outcome: .completado))
        try await almacen.save(DayRecord(day: dia(5), alarmID: nil, challenge: .pasos, outcome: .fallado(.ignorada)))

        let leidos = try await almacen.records(from: dia(5), to: dia(5))
        #expect(leidos.count == 1, "dos registros del mismo dia son el mismo despertar contado dos veces")
        #expect(leidos.first?.outcome == .fallado(.ignorada))
    }

    // MARK: - Rastro del reto empezado

    @Test("Sin reto empezado no hay rastro")
    func sinRastro() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        #expect(try await almacen.current() == nil)
    }

    @Test("El rastro se guarda entero y se puede borrar")
    func rastroIdaYVuelta() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let pendiente = PendingChallenge(alarmID: UUID(), challenge: .sentadillas,
                                         day: dia(9), startedAt: Date(timeIntervalSince1970: 1_000))

        try await almacen.begin(pendiente)
        #expect(try await almacen.current() == pendiente)

        try await almacen.clear()
        #expect(try await almacen.current() == nil)
    }

    @Test("Empezar un reto nuevo sustituye al rastro anterior, no lo acumula")
    func rastroEsFilaUnica() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let viejo = PendingChallenge(alarmID: UUID(), challenge: .pasos, day: dia(9), startedAt: .init(timeIntervalSince1970: 0))
        let nuevo = PendingChallenge(alarmID: UUID(), challenge: .sentadillas, day: dia(10), startedAt: .init(timeIntervalSince1970: 100))

        try await almacen.begin(viejo)
        try await almacen.begin(nuevo)

        #expect(try await almacen.current() == nuevo, "solo puede haber un reto en marcha")
    }

    // MARK: - El dia entero, de una pieza

    @Test("Confirmar el dia escribe estado, registro y cierre del rastro")
    func confirmarDiaEscribeLasTresCosas() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        let alarmID = UUID()
        try await almacen.begin(PendingChallenge(alarmID: alarmID, challenge: .pasos, day: dia(5), startedAt: Date()))

        let estado = StreakState(current: 3, best: 3, livesRemaining: 2,
                                 livesRefilledYearMonth: dia(5).yearMonth,
                                 lastCountedDay: dia(5), diasCompletadosTotales: 3)
        let registro = DayRecord(day: dia(5), alarmID: alarmID, challenge: .pasos, outcome: .completado, duration: 22)

        try await almacen.confirmarDia(estado: estado, registro: registro)

        #expect(try await almacen.rachaActual() == estado)
        #expect(try await almacen.records(from: dia(5), to: dia(5)) == [registro])
        #expect(try await almacen.retoPendiente() == nil)
    }

    @Test("Si la transaccion falla, no se escribe ni la mitad")
    func transaccionQueFallaNoDejaRastro() async throws {
        struct DiscoRoto: Error {}
        let almacen = try Persistence.almacen(enMemoria: true)
        try await almacen.save(alarmaDePrueba(hora: 6))

        await #expect(throws: DiscoRoto.self) {
            try await almacen.ensayoDeTransaccionQueFalla(alarmaDePrueba(hora: 8), error: DiscoRoto())
        }

        let alarmas = try await almacen.all()
        #expect(alarmas.count == 1, "lo que se inserto antes del fallo tiene que haberse deshecho")
        #expect(alarmas.first?.hour == 6)
    }
}
