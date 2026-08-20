import Foundation

public struct StreakState: Hashable, Codable, Sendable {
    /// Vidas que se conceden al empezar cada mes. No se acumulan: lo que no
    /// gastas en agosto no lo tienes en septiembre.
    public static let livesPerMonth = 2

    public var current: Int
    public var best: Int
    /// Dias completados en toda la vida del usuario. No baja nunca, ni siquiera
    /// al romperse la racha: es el eje sobre el que suben los niveles.
    ///
    /// Va aparte de `best` a proposito. `best` mide la mejor racha seguida y es
    /// lo que premian las insignias; esto mide constancia acumulada. Colgar los
    /// niveles de la racha actual castigaria dos veces el mismo fallo: pierdes
    /// la racha y ademas bajas de nivel.
    public var diasCompletadosTotales: Int
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
        lastCountedDay: Day? = nil,
        diasCompletadosTotales: Int = 0
    ) {
        self.current = current
        self.best = best
        self.livesRemaining = livesRemaining
        self.livesRefilledYearMonth = livesRefilledYearMonth
        self.lastCountedDay = lastCountedDay
        self.diasCompletadosTotales = diasCompletadosTotales
    }
}

// MARK: - Decodificacion tolerante

extension StreakState {
    private enum CodingKeys: String, CodingKey {
        case current, best, livesRemaining, livesRefilledYearMonth, lastCountedDay, diasCompletadosTotales
    }

    /// Se escribe a mano por un solo motivo: `diasCompletadosTotales` se anadio
    /// despues, y con la sintesis automatica un estado guardado sin ese campo
    /// dejaria de decodificar entero. Es decir, un usuario con racha de 40 dias
    /// abriria la app y se encontraria la racha a cero. Ausente = 0, y lo demas
    /// se conserva.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            current: try c.decode(Int.self, forKey: .current),
            best: try c.decode(Int.self, forKey: .best),
            livesRemaining: try c.decode(Int.self, forKey: .livesRemaining),
            livesRefilledYearMonth: try c.decodeIfPresent(Int.self, forKey: .livesRefilledYearMonth),
            lastCountedDay: try c.decodeIfPresent(Day.self, forKey: .lastCountedDay),
            diasCompletadosTotales: try c.decodeIfPresent(Int.self, forKey: .diasCompletadosTotales) ?? 0
        )
    }
}
