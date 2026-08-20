import Foundation

// Niveles e insignias: reglas puras sobre `StreakState`, sin fechas del sistema
// ni almacenamiento.
//
//   - Los NIVELES suben con la racha actual. Se pierden al romperla, igual que
//     la racha: el nivel es una lectura de como vas ahora, no un trofeo.
//   - Las INSIGNIAS premian `best` y el acumulado de por vida. Esas no se
//     quitan nunca: son hazanas, y una hazana pasada no deja de haber ocurrido.
//
// Ninguna de las dos se puede comprar. Las vidas si son de Pro desde el
// 21/08/2026, pero niveles e insignias no: se ganan levantandose y no hay boton
// que los suba. Pagar tampoco reconstruye una racha ya rota.

// MARK: - Niveles

public struct Nivel: Identifiable, Hashable, Codable, Sendable, Comparable {
    public var id: Int { numero }

    public let numero: Int
    public let nombre: String
    /// Racha con la que empieza este nivel.
    public let desde: Int
    /// Racha con la que empieza el siguiente. `nil` en el ultimo.
    public let hasta: Int?

    public init(numero: Int, nombre: String, desde: Int, hasta: Int?) {
        self.numero = numero
        self.nombre = nombre
        self.desde = desde
        self.hasta = hasta
    }

    /// Cuanto falta para el siguiente nivel, de 0 a 1. En el ultimo, 1.
    public func progreso(conRacha racha: Int) -> Double {
        guard let hasta, hasta > desde else { return 1 }
        return min(max(Double(racha - desde) / Double(hasta - desde), 0), 1)
    }

    /// Dias que faltan para subir. En el ultimo nivel, 0.
    public func diasQueFaltan(conRacha racha: Int) -> Int {
        guard let hasta else { return 0 }
        return max(0, hasta - racha)
    }

    public static func < (lhs: Nivel, rhs: Nivel) -> Bool { lhs.numero < rhs.numero }
}

public enum Niveles {

    /// La escalera. El primer nivel empieza en 0: un usuario recien instalado
    /// ya esta en algun sitio, no fuera de la tabla.
    public static let todos: [Nivel] = [
        Nivel(numero: 1, nombre: "Te suena el despertador", desde: 0, hasta: 3),
        Nivel(numero: 2, nombre: "Te levantas", desde: 3, hasta: 7),
        Nivel(numero: 3, nombre: "Ya no cuesta tanto", desde: 7, hasta: 14),
        Nivel(numero: 4, nombre: "Constante", desde: 14, hasta: 30),
        Nivel(numero: 5, nombre: "Imparable", desde: 30, hasta: 60),
        Nivel(numero: 6, nombre: "Leyenda", desde: 60, hasta: nil)
    ]

    public static var primero: Nivel { todos[0] }
    public static var ultimo: Nivel { todos[todos.count - 1] }

    public static func nivel(racha: Int) -> Nivel {
        todos.last { racha >= $0.desde } ?? primero
    }

    public static func nivel(de state: StreakState) -> Nivel {
        nivel(racha: state.current)
    }

    public static func siguiente(a nivel: Nivel) -> Nivel? {
        todos.first { $0.numero > nivel.numero }
    }

    /// El nivel nuevo si se acaba de subir, `nil` si no. Existe para que la app
    /// avise una sola vez, en el momento, y no cada vez que se lee el estado.
    /// Bajar de nivel no se avisa: ya se avisa de que se ha roto la racha.
    public static func ascenso(de anterior: StreakState, a nuevo: StreakState) -> Nivel? {
        let antes = nivel(de: anterior)
        let ahora = nivel(de: nuevo)
        return ahora > antes ? ahora : nil
    }
}

// MARK: - Insignias

public enum Insignia: String, Identifiable, CaseIterable, Codable, Sendable {
    public var id: String { rawValue }

    case primerDia
    case semanaEnPie
    case mesEnPie
    case cienSeguidos
    case anoEnPie
    case veterano

    public var nombre: String {
        switch self {
        case .primerDia: "Primer día"
        case .semanaEnPie: "Siete seguidos"
        case .mesEnPie: "Treinta seguidos"
        case .cienSeguidos: "Cien seguidos"
        case .anoEnPie: "Un año entero"
        case .veterano: "Veterano"
        }
    }

    public var descripcion: String {
        switch self {
        case .primerDia: "Completaste tu primer reto."
        case .semanaEnPie: "Una semana sin fallar."
        case .mesEnPie: "Treinta días seguidos en pie."
        case .cienSeguidos: "Cien días seguidos."
        case .anoEnPie: "Trescientos sesenta y cinco días seguidos."
        case .veterano: "Trescientos sesenta y cinco días completados en total."
        }
    }

    /// La regla, en un solo sitio. Todas miran `best` o el acumulado, nunca la
    /// racha actual: una insignia ganada no se quita al perder la racha.
    public func concedida(_ state: StreakState) -> Bool {
        switch self {
        case .primerDia: state.diasCompletadosTotales >= 1
        case .semanaEnPie: state.best >= 7
        case .mesEnPie: state.best >= 30
        case .cienSeguidos: state.best >= 100
        case .anoEnPie: state.best >= 365
        case .veterano: state.diasCompletadosTotales >= 365
        }
    }
}

public enum Insignias {

    public static func concedidas(_ state: StreakState) -> Set<Insignia> {
        Set(Insignia.allCases.filter { $0.concedida(state) })
    }

    /// Las que se acaban de ganar. Como en el ascenso de nivel, esto es para
    /// avisar una vez y no en cada lectura del estado.
    public static func nuevas(de anterior: StreakState, a nuevo: StreakState) -> Set<Insignia> {
        concedidas(nuevo).subtracting(concedidas(anterior))
    }
}
