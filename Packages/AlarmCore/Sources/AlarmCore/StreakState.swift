import Foundation

public struct StreakState: Hashable, Codable, Sendable {
    /// Vidas que se conceden al empezar cada mes. No se acumulan: lo que no
    /// gastas en agosto no lo tienes en septiembre.
    public static let livesPerMonth = 2

    public var current: Int
    public var best: Int
    public var livesRemaining: Int
    /// Mes en el que se repusieron las vidas por ultima vez, para no reponerlas
    /// dos veces ni olvidarnos si el usuario no abre la app en semanas.
    public var livesRefilledYearMonth: Int?
    public var lastCountedDay: Day?

    public init(
        current: Int = 0,
        best: Int = 0,
        livesRemaining: Int = StreakState.livesPerMonth,
        livesRefilledYearMonth: Int? = nil,
        lastCountedDay: Day? = nil
    ) {
        self.current = current
        self.best = best
        self.livesRemaining = livesRemaining
        self.livesRefilledYearMonth = livesRefilledYearMonth
        self.lastCountedDay = lastCountedDay
    }
}
