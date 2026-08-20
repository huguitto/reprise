import Foundation

/// Dias de la semana en orden europeo: la semana empieza en lunes.
public enum Weekday: Int, CaseIterable, Codable, Sendable, Comparable {
    case lunes = 1, martes, miercoles, jueves, viernes, sabado, domingo

    /// Conversion desde el componente `weekday` de `Calendar`, que numera
    /// domingo = 1. Aislada aqui para que nadie la reimplemente mal.
    public init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .domingo
        default: self.init(rawValue: calendarWeekday - 1)
        }
    }

    public var calendarWeekday: Int { self == .domingo ? 1 : rawValue + 1 }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}
