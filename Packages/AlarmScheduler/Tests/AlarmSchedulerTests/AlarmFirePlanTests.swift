import Testing
import Foundation
import AlarmCore
@testable import AlarmScheduler

/// Lo que se puede probar sin iPhone ni entitlement: que los dias que le
/// pasamos a AlarmKit son los dias que pidio el usuario. Es el fallo tipico
/// —domingo vale 1 en `Calendar` y lunes vale 1 para nosotros— y se manifiesta
/// como una alarma que suena el dia equivocado, que es de las peores formas de
/// enterarse.
@Suite("Plan de disparo")
struct AlarmFirePlanTests {
    private func alarma(
        hour: Int = 7,
        minute: Int = 0,
        weekdays: Set<Weekday> = []
    ) -> DomainAlarm {
        DomainAlarm(hour: hour, minute: minute, weekdays: weekdays, challenge: .pasos)
    }

    @Test("Sin dias marcados es una alarma de un solo uso")
    func unSoloUso() throws {
        let plan = try AlarmFirePlan(alarm: alarma())
        #expect(plan.repeats == false)
        #expect(plan.localeWeekdays.isEmpty)
    }

    @Test("Con dias marcados repite")
    func repite() throws {
        let plan = try AlarmFirePlan(alarm: alarma(weekdays: [.lunes, .viernes]))
        #expect(plan.repeats)
    }

    @Test("Los dias salen ordenados de lunes a domingo, no como entraron")
    func ordenados() throws {
        let plan = try AlarmFirePlan(alarm: alarma(weekdays: [.domingo, .miercoles, .lunes]))
        #expect(plan.weekdays == [.lunes, .miercoles, .domingo])
    }

    @Test("Cada dia nuestro se traduce al dia que espera AlarmKit")
    func traduccionDeDias() throws {
        let esperado: [Weekday: Locale.Weekday] = [
            .lunes: .monday,
            .martes: .tuesday,
            .miercoles: .wednesday,
            .jueves: .thursday,
            .viernes: .friday,
            .sabado: .saturday,
            .domingo: .sunday
        ]
        for (nuestro, suyo) in esperado {
            let plan = try AlarmFirePlan(alarm: alarma(weekdays: [nuestro]))
            #expect(plan.localeWeekdays == [suyo], "\(nuestro) deberia ser \(suyo)")
        }
    }

    @Test("El domingo no se desplaza: es el fallo clasico del desfase")
    func domingoNoSeDesplaza() throws {
        let plan = try AlarmFirePlan(alarm: alarma(weekdays: [.domingo]))
        #expect(plan.localeWeekdays == [.sunday])
        #expect(plan.localeWeekdays != [.saturday])
        #expect(plan.localeWeekdays != [.monday])
    }

    @Test("La hora y el minuto se respetan tal cual")
    func horaYMinuto() throws {
        let plan = try AlarmFirePlan(alarm: alarma(hour: 6, minute: 45))
        #expect(plan.hour == 6)
        #expect(plan.minute == 45)
    }

    @Test("Una hora imposible no llega a AlarmKit", arguments: [(24, 0), (-1, 0), (7, 60), (7, -1)])
    func horaImposible(hour: Int, minute: Int) {
        #expect(throws: AlarmSchedulerError.horaInvalida(hour: hour, minute: minute)) {
            try AlarmFirePlan(alarm: alarma(hour: hour, minute: minute))
        }
    }

    @Test("Medianoche y las 23:59 si son horas validas")
    func extremosValidos() throws {
        #expect(throws: Never.self) { try AlarmFirePlan(alarm: alarma(hour: 0, minute: 0)) }
        #expect(throws: Never.self) { try AlarmFirePlan(alarm: alarma(hour: 23, minute: 59)) }
    }
}
