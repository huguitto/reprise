import Foundation

// Niveles e insignias: reglas puras sobre `StreakState`, sin fechas del sistema
// ni almacenamiento. Dos ejes distintos a proposito:
//
//   - Los NIVELES suben con `diasCompletadosTotales`, el acumulado de por vida.
//     Miden constancia y no bajan nunca. Colgarlos de la racha actual castigaria
//     dos veces el mismo fallo: pierdes la racha y ademas bajas de nivel.
//   - Las INSIGNIAS premian `best`, la mejor racha seguida. Miden hazana, y una
//     vez ganadas tampoco se pierden.
//
// Ninguna de las dos se puede comprar: por decision de producto se vende lo que
// rodea a la racha, nunca la racha misma.

// MARK: - Niveles

public struct Nivel: Identifiable, Hashable, Codable, Sendable, Comparable {
    public var id: Int { numero }

    public let numero: Int
    public let nombre: String
    /// Dias completados acumulados a partir de los cuales se tiene este nivel.
    public let diasNecesarios: Int

    public init(numero: Int, nombre: String, diasNecesarios: Int) {
        self.numero = numero
        self.nombre = nombre
        self.diasNecesarios = diasNecesarios
    }

    public static func < (lhs: Nivel, rhs: Nivel) -> Bool { lhs.numero < rhs.numero }
}

/// Cuanto falta para el siguiente nivel. Lo consume la interfaz para pintar la
/// barra de progreso; aqui vive el calculo para que no lo reinvente cada vista.
public struct ProgresoDeNivel: Hashable, Sendable {
    public let nivel: Nivel
    /// `nil` en el ultimo nivel: no hay nada mas alla.
    public let siguiente: Nivel?
    public let diasCompletados: Int

    public var diasQueFaltan: Int {
        guard let siguiente else { return 0 }
        return max(0, siguiente.diasNecesarios - diasCompletados)
    }

    /// Avance dentro del tramo actual, de 0 a 1. En el ultimo nivel, 1.
    public var fraccion: Double {
        guard let siguiente else { return 1 }
        let tramo = siguiente.diasNecesarios - nivel.diasNecesarios
        guard tramo > 0 else { return 1 }
        let hecho = diasCompletados - nivel.diasNecesarios
        return min(1, max(0, Double(hecho) / Double(tramo)))
    }
}

public enum Niveles {

    /// La escalera. El primer nivel tiene que empezar en 0 dias: un usuario
    /// recien instalado ya esta en algun sitio, no fuera de la tabla.
    public static let todos: [Nivel] = [
        Nivel(numero: 1, nombre: "Primer timbre", diasNecesarios: 0),
        Nivel(numero: 2, nombre: "Madrugador", diasNecesarios: 3),
        Nivel(numero: 3, nombre: "Semana en pie", diasNecesarios: 7),
        Nivel(numero: 4, nombre: "Quincena", diasNecesarios: 15),
        Nivel(numero: 5, nombre: "Mes en pie", diasNecesarios: 30),
        Nivel(numero: 6, nombre: "Trimestre", diasNecesarios: 90),
        Nivel(numero: 7, nombre: "Medio año", diasNecesarios: 180),
        Nivel(numero: 8, nombre: "Año en pie", diasNecesarios: 365)
    ]

    public static var primero: Nivel { todos[0] }
    public static var ultimo: Nivel { todos[todos.count - 1] }

    public static func nivel(diasCompletados: Int) -> Nivel {
        todos.last { diasCompletados >= $0.diasNecesarios } ?? primero
    }

    public static func nivel(de state: StreakState) -> Nivel {
        nivel(diasCompletados: state.diasCompletadosTotales)
    }

    public static func siguiente(a nivel: Nivel) -> Nivel? {
        todos.first { $0.numero > nivel.numero }
    }

    public static func progreso(de state: StreakState) -> ProgresoDeNivel {
        let actual = nivel(de: state)
        return ProgresoDeNivel(
            nivel: actual,
            siguiente: siguiente(a: actual),
            diasCompletados: state.diasCompletadosTotales
        )
    }

    /// El nivel nuevo si se acaba de subir, `nil` si no. Existe para que la app
    /// avise una sola vez, en el momento, y no cada vez que se lee el estado.
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
