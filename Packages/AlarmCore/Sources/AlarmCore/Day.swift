import Foundation

/// Un dia de calendario, sin hora ni zona horaria.
///
/// Las rachas se cuentan en dias vividos por la persona, no en instantes UTC.
/// Usar `Date` para esto lleva a que un usuario que viaja pierda o gane un dia
/// sin motivo, asi que el dominio nunca ve un `Date`: la conversion ocurre una
/// sola vez, en el borde, con el calendario y la zona horaria del dispositivo.
public struct Day: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0)
    }

    /// Identificador de mes, para saber cuando toca reponer vidas.
    public var yearMonth: Int { year * 12 + month }

    public func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    public func adding(days: Int, calendar: Calendar = .current) -> Day {
        guard let d = calendar.date(byAdding: .day, value: days, to: date(calendar: calendar)) else { return self }
        return Day(d, calendar: calendar)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
