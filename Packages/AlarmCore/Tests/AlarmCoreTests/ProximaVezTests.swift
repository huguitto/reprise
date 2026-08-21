import Testing
import Foundation
@testable import AlarmCore

/// La proxima vez que suena una alarma.
///
/// Se prueba con un calendario fijo —zona horaria de Madrid, semana que empieza
/// en lunes— para que no dependa de donde corra.
@Suite("Alarma · cuando suena la proxima vez")
struct ProximaVezTests {
    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        c.locale = Locale(identifier: "es_ES")
        return c
    }

    /// Un momento concreto: viernes 21 de agosto de 2026, a las 10:00.
    private func momento(dia: Int, hora: Int, minuto: Int = 0) -> Date {
        calendario.date(from: DateComponents(
            year: 2026, month: 8, day: dia, hour: hora, minute: minuto
        ))!
    }

    private func partes(_ fecha: Date) -> (dia: Int, hora: Int, minuto: Int) {
        let c = calendario.dateComponents([.day, .hour, .minute], from: fecha)
        return (c.day!, c.hour!, c.minute!)
    }

    @Test("De un solo uso: si la hora aun no ha pasado, suena hoy")
    func hoyMismo() throws {
        let alarma = Alarm(hour: 22, minute: 30, challenge: .pasos)
        let cuando = try #require(alarma.proximaVez(desde: momento(dia: 21, hora: 10), calendario: calendario))
        #expect(partes(cuando) == (21, 22, 30))
    }

    @Test("De un solo uso: si la hora ya paso, suena manana")
    func manana() throws {
        let alarma = Alarm(hour: 7, minute: 30, challenge: .pasos)
        let cuando = try #require(alarma.proximaVez(desde: momento(dia: 21, hora: 10), calendario: calendario))
        #expect(partes(cuando) == (22, 7, 30))
    }

    /// El minuto justo cuenta como pasado: quien acaba de apagar la de las 7:30
    /// no quiere leer que la proxima es dentro de cero segundos.
    @Test("El minuto exacto ya es pasado")
    func minutoExacto() throws {
        let alarma = Alarm(hour: 7, minute: 30, challenge: .pasos)
        let cuando = try #require(alarma.proximaVez(desde: momento(dia: 21, hora: 7, minuto: 30), calendario: calendario))
        #expect(partes(cuando) == (22, 7, 30))
    }

    @Test("Con dias: el proximo dia marcado, aunque sea la semana que viene")
    func proximoDiaMarcado() throws {
        // Viernes 21. La alarma es de lunes: toca el lunes 24.
        let alarma = Alarm(hour: 7, minute: 0, weekdays: [.lunes], challenge: .pasos)
        let cuando = try #require(alarma.proximaVez(desde: momento(dia: 21, hora: 10), calendario: calendario))
        #expect(partes(cuando) == (24, 7, 0))
    }

    @Test("Con dias: hoy cuenta si la hora esta por llegar")
    func hoyTambienCuenta() throws {
        // Viernes 21, son las 10:00 y la alarma de los viernes es a las 22:00.
        let alarma = Alarm(hour: 22, minute: 0, weekdays: [.viernes], challenge: .pasos)
        let cuando = try #require(alarma.proximaVez(desde: momento(dia: 21, hora: 10), calendario: calendario))
        #expect(partes(cuando) == (21, 22, 0))
    }

    /// El caso que obliga a mirar ocho dias y no siete.
    @Test("Solo un dia a la semana y ya paso: toca dentro de siete dias")
    func laSemanaQueViene() throws {
        let alarma = Alarm(hour: 7, minute: 0, weekdays: [.viernes], challenge: .pasos)
        let cuando = try #require(alarma.proximaVez(desde: momento(dia: 21, hora: 10), calendario: calendario))
        #expect(partes(cuando) == (28, 7, 0))
    }

    @Test("Varios dias: gana el primero que llegue")
    func elPrimeroQueLlegue() throws {
        // Viernes 21 a las 10:00. Lunes, miercoles y sabado: toca el sabado 22.
        let alarma = Alarm(hour: 6, minute: 15, weekdays: [.lunes, .miercoles, .sabado], challenge: .pasos)
        let cuando = try #require(alarma.proximaVez(desde: momento(dia: 21, hora: 10), calendario: calendario))
        #expect(partes(cuando) == (22, 6, 15))
    }

    @Test("Todos los dias: manana si hoy ya paso")
    func todosLosDias() throws {
        let alarma = Alarm(hour: 7, minute: 0, weekdays: Set(Weekday.allCases), challenge: .pasos)
        let cuando = try #require(alarma.proximaVez(desde: momento(dia: 21, hora: 10), calendario: calendario))
        #expect(partes(cuando) == (22, 7, 0))
    }
}
