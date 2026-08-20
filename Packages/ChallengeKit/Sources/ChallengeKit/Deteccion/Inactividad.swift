import Foundation

/// El umbral de abandono, en un solo sitio para los dos retos.
///
/// No es un detalle de implementacion: `isStalled` es la senal con la que la
/// alarma vuelve a sonar cuando alguien se planta a mitad del reto, asi que el
/// numero es de producto. Si los dos detectores lo definieran por su cuenta,
/// abandonar caminando y abandonar en cuclillas se castigarian distinto.
public enum Inactividad {
    /// Segundos sin movimiento valido tras los cuales `isStalled` pasa a `true`.
    public static let umbral: Duration = .seconds(8)

    /// Cada cuanto se comprueba. Medio segundo sobra para un umbral de ocho.
    static let periodoDeRevision: Duration = .milliseconds(500)
}

extension Duration {
    /// `Duration` no da segundos en coma flotante y aqui hacen falta para las
    /// cuentas de cadencia y de deriva.
    var ensegundos: Double {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}
