import Foundation
import AlarmCore

// Modelos que existen SOLO para pintar.
//
// El motor de rachas, los niveles de verdad y el ranking de verdad son de
// otros paquetes. Cuando existan, estas estructuras se caen y las pantallas
// pasan a leer las suyas. Estan aqui para que el diseno no tenga que esperar
// a nadie, no para fijar un contrato.

/// Nivel que se ensena junto a la racha.
public struct Nivel: Hashable, Sendable {
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

    /// Cuanto falta para el siguiente nivel, de 0 a 1.
    public func progreso(conRacha racha: Int) -> Double {
        guard let hasta, hasta > desde else { return 1 }
        return min(max(Double(racha - desde) / Double(hasta - desde), 0), 1)
    }
}

/// Una insignia tal y como se ve en la pantalla de racha.
public struct FichaDeInsignia: Identifiable, Hashable, Sendable {
    public let id: String
    public let simbolo: String
    public let nombre: String
    public let conseguida: Bool

    public init(id: String, simbolo: String, nombre: String, conseguida: Bool) {
        self.id = id
        self.simbolo = simbolo
        self.nombre = nombre
        self.conseguida = conseguida
    }
}

/// Una linea del ranking.
public struct PuestoDeRanking: Identifiable, Hashable, Sendable {
    public let id: Int
    public let posicion: Int
    public let nombre: String
    /// Bandera en emoji. El ranking es mundial y por paises, y una bandera
    /// ocupa lo que una letra.
    public let bandera: String
    public let racha: Int
    /// La fila del propio usuario, que va resaltada y siempre visible.
    public let eresTu: Bool

    public init(posicion: Int, nombre: String, bandera: String, racha: Int, eresTu: Bool = false) {
        self.id = posicion
        self.posicion = posicion
        self.nombre = nombre
        self.bandera = bandera
        self.racha = racha
        self.eresTu = eresTu
    }
}

/// Como se lee un desenlace de dia en el calendario de la racha.
extension DayOutcome {
    public var descripcion: String {
        switch self {
        case .completado: "Completado"
        case .fallado(let motivo): motivo.descripcion
        case .salvadoPorVida(let motivo): "Salvado por una vida · \(motivo.descripcion.lowercased())"
        }
    }
}

extension FailureReason {
    public var descripcion: String {
        switch self {
        case .paroSinReto: "Paraste sin hacer el reto"
        case .abandono: "Dejaste el reto a medias"
        case .appTerminada: "Cerraste la app durante el reto"
        case .ignorada: "No sonaste ni te enteraste"
        }
    }
}

extension ChallengeType {
    /// Simbolo del sistema con el que se identifica cada reto.
    public var simbolo: String {
        switch self {
        case .pasos: "figure.walk"
        case .sentadillas: "figure.strengthtraining.functional"
        }
    }

    /// Como se pide el reto en la pantalla del reto, en imperativo.
    public var instruccion: String {
        switch self {
        case .pasos: "Da 20 pasos"
        case .sentadillas: "Haz 10 sentadillas"
        }
    }

    /// El sustantivo suelto, para debajo del contador.
    public var unidad: String {
        switch self {
        case .pasos: "pasos"
        case .sentadillas: "sentadillas"
        }
    }
}
