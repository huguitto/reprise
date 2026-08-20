import Foundation

public struct StreakState: Hashable, Codable, Sendable {
    /// Vidas que se conceden al empezar cada mes **con Pro**. No se acumulan:
    /// lo que no gastas en agosto no lo tienes en septiembre.
    ///
    /// El plan gratis no tiene vidas: se rompe la racha al primer fallo. Quien
    /// manda es `PlanDeSuscripcion.limites.vidasAlMes`, y esta constante es
    /// solo el tope de Pro. En pantalla sirve para dibujar los huecos: un
    /// usuario gratis ve las dos casillas vacias, que es exactamente lo que le
    /// falta.
    public static let livesPerMonth = 2

    public var current: Int
    public var best: Int
    /// Dias completados en toda la vida del usuario. No baja nunca, ni siquiera
    /// al romperse la racha.
    ///
    /// Los niveles NO cuelgan de aqui: van con la racha actual, y bajan con
    /// ella. Esto sostiene la insignia de veterano y las estadisticas de Pro.
    ///
    /// Se guarda en vez de contarse desde el historial porque el historial se
    /// puede podar y esto no se puede reconstruir despues.
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
