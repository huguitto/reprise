import Testing
import Foundation
@testable import AlarmCore

@Suite("Dia de calendario")
struct DayTests {

    @Test("Los dias se ordenan cronologicamente cruzando meses y anos")
    func orden() {
        #expect(Day(year: 2026, month: 1, day: 31) < Day(year: 2026, month: 2, day: 1))
        #expect(Day(year: 2025, month: 12, day: 31) < Day(year: 2026, month: 1, day: 1))
    }

    @Test("yearMonth distingue el mismo mes de anos distintos")
    func yearMonthNoColisiona() {
        #expect(Day(year: 2026, month: 8, day: 1).yearMonth != Day(year: 2025, month: 8, day: 1).yearMonth)
    }

    @Test("Sumar dias cruza el final de mes")
    func sumaCruzaMes() {
        #expect(Day(year: 2026, month: 8, day: 31).adding(days: 1) == Day(year: 2026, month: 9, day: 1))
    }

    @Test("La semana empieza en lunes y domingo se convierte bien")
    func semanaEuropea() {
        #expect(Weekday(calendarWeekday: 1) == .domingo)
        #expect(Weekday(calendarWeekday: 2) == .lunes)
        #expect(Weekday.domingo.calendarWeekday == 1)
        for d in Weekday.allCases {
            #expect(Weekday(calendarWeekday: d.calendarWeekday) == d)
        }
    }
}
