import SwiftUI

/// Espaciado. Escala de 4, para que nada quede a ojo.
public enum Espacio {
    public static let mini: CGFloat = 4
    public static let corto: CGFloat = 8
    public static let medio: CGFloat = 12
    public static let normal: CGFloat = 16
    public static let amplio: CGFloat = 24
    public static let ancho: CGFloat = 32
    public static let enorme: CGFloat = 48

    /// Margen lateral de todas las pantallas. El titular se pega a el.
    public static let margen: CGFloat = 24
}

/// Radios de esquina. Las piezas neumorficas necesitan radios generosos: con
/// esquinas cerradas la sombra se acumula en el vertice y parece sucia.
public enum Radio {
    public static let chico: CGFloat = 14
    public static let medio: CGFloat = 20
    public static let grande: CGFloat = 28
    public static let enorme: CGFloat = 40
}

/// Cuanto se separa una pieza del plano del fondo.
///
/// El neumorfismo solo funciona si la luz viene **siempre del mismo sitio**:
/// arriba a la izquierda. Por eso el desplazamiento no se elige por pieza, se
/// deriva del nivel.
public enum Relieve: Sendable, Hashable {
    /// Filas de lista, pastillas, botones secundarios.
    case bajo
    /// Tarjetas y botones principales.
    case medio
    /// La esfera del reloj y el mando del dial: lo que se toca con el dedo.
    case alto

    public var desplazamiento: CGFloat {
        switch self {
        case .bajo: 3
        case .medio: 6
        case .alto: 10
        }
    }

    public var difuminado: CGFloat {
        switch self {
        case .bajo: 6
        case .medio: 12
        case .alto: 20
        }
    }

    /// Hasta donde llega la sombra mas alla del borde de la pieza.
    ///
    /// Hace falta cada vez que una pieza en relieve se mete dentro de algo que
    /// recorta —un `ScrollView`, una mascara—: recortando a ras del marco, la
    /// sombra se corta en seco y la pieza se queda plana. Y no se nota como
    /// "falta sombra", se nota como una raya recta donde no hay nada.
    ///
    /// Medido sobre una captura del disco de la lista (relieve `.alto`): desde
    /// el borde, la sombra tarda **35 puntos** en llegar al color del fondo.
    /// La cuenta de aqui da 50 para ese caso, que sobra a proposito: pasarse
    /// con un recorte no cuesta nada y quedarse corto se ve.
    public var alcance: CGFloat { desplazamiento + difuminado * 2 }
}

/// Cuanto se hunde una pieza por debajo del plano del fondo.
public enum Hundido: Sendable, Hashable {
    /// Canales, pistas, celdas de calendario.
    case sutil
    /// Campos de texto y pozos del dial.
    case marcado

    public var desplazamiento: CGFloat {
        switch self {
        case .sutil: 2
        case .marcado: 4
        }
    }

    public var difuminado: CGFloat {
        switch self {
        case .sutil: 4
        case .marcado: 8
        }
    }
}
