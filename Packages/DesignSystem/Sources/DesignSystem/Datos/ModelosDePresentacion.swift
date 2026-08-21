import Foundation
import AlarmCore

// Modelos que existen SOLO para pintar, y como se lee lo de AlarmCore.
//
// Aqui ya no hay niveles ni insignias propios: los trae AlarmCore y las
// pantallas leen los suyos. Lo que queda son dos cosas distintas:
//
//   - `PuestoDeRanking` y `TemporadaDeRanking`, que siguen siendo de mentira
//     porque el ranking es de red y todavia no existe. Se caen igual cuando
//     exista.
//   - Las extensiones de abajo, que NO se caen: son la capa de presentacion
//     de tipos de dominio. Como se pinta una insignia o como se lee un
//     desenlace es cosa del diseno, no del motor, y por eso vive de este lado.

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

/// Una temporada de ranking ya cerrada.
///
/// El ranking se pone a cero el dia 1 de cada mes, pero lo que hiciste no se
/// borra: cada mes cerrado deja una linea aqui. Es el "record historico
/// aparte" de las decisiones de producto.
public struct TemporadaDeRanking: Identifiable, Hashable, Sendable {
    public let id: String
    /// Como se lee el mes: "Julio 2026".
    public let mes: String
    public let puestoMundial: Int
    public let puestoEnPais: Int
    /// La racha con la que acabo el mes, que es lo que ordenaba el ranking.
    public let rachaFinal: Int

    public init(id: String, mes: String, puestoMundial: Int, puestoEnPais: Int, rachaFinal: Int) {
        self.id = id
        self.mes = mes
        self.puestoMundial = puestoMundial
        self.puestoEnPais = puestoEnPais
        self.rachaFinal = rachaFinal
    }
}

extension Insignia {
    /// Simbolo del sistema con el que se pinta cada insignia.
    ///
    /// Vive aqui y no en AlarmCore a proposito: el motor decide que se
    /// concede y como se llama, el diseno decide con que se dibuja.
    public var simbolo: String {
        switch self {
        case .primerDia: "sunrise.fill"
        case .semanaEnPie: "flame.fill"
        case .mesEnPie: "crown.fill"
        case .cienSeguidos: "trophy.fill"
        case .anoEnPie: "rosette"
        case .veterano: "checkmark.seal.fill"
        }
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
        case .ignorada: "Sonó y no te levantaste"
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
