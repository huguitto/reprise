import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Un color fijo, escrito con el mismo hexadecimal que usa el diseno.
///
/// No se usa directamente en las vistas: solo sirve para construir los pares
/// claro/oscuro de `Paleta`.
public struct Tinte: Sendable, Hashable {
    public let rojo: Double
    public let verde: Double
    public let azul: Double
    public let opacidad: Double

    public init(_ hex: UInt32, _ opacidad: Double = 1) {
        self.rojo = Double((hex >> 16) & 0xFF) / 255
        self.verde = Double((hex >> 8) & 0xFF) / 255
        self.azul = Double(hex & 0xFF) / 255
        self.opacidad = opacidad
    }

    public var color: Color {
        Color(.sRGB, red: rojo, green: verde, blue: azul, opacity: opacidad)
    }
}

extension Color {
    /// Color que cambia solo con el modo claro/oscuro del sistema.
    ///
    /// Devuelve un `Color` de verdad, no un `ShapeStyle`, para que valga
    /// tambien donde SwiftUI exige un color concreto: sombras y degradados.
    public static func dinamico(claro: Tinte, oscuro: Tinte) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { rasgos in
            rasgos.userInterfaceStyle == .dark ? oscuro.uiKit : claro.uiKit
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { apariencia in
            apariencia.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? oscuro.appKit : claro.appKit
        })
        #else
        return claro.color
        #endif
    }
}

#if canImport(UIKit)
extension Tinte {
    var uiKit: UIColor {
        UIColor(red: rojo, green: verde, blue: azul, alpha: opacidad)
    }
}
#elseif canImport(AppKit)
extension Tinte {
    var appKit: NSColor {
        NSColor(srgbRed: rojo, green: verde, blue: azul, alpha: opacidad)
    }
}
#endif

/// Los colores de RepRise.
///
/// Base monocroma en gris calido, como el reloj fisico de la referencia, y
/// **un solo color de acento**: el naranja. Si algo necesita destacar y no es
/// el acento, se resuelve con peso tipografico o con relieve, nunca con un
/// segundo color.
public enum Paleta {

    // MARK: - Superficies

    /// El papel sobre el que se apoya todo.
    public static let fondo = Color.dinamico(claro: Tinte(0xEDEBE7), oscuro: Tinte(0x171614))
    /// Lo que sobresale del fondo: tarjetas, filas, botones.
    public static let superficie = Color.dinamico(claro: Tinte(0xF3F1ED), oscuro: Tinte(0x201F1C))
    /// Lo que sobresale del todo: la esfera del reloj, el mando del dial.
    public static let superficieAlta = Color.dinamico(claro: Tinte(0xFBFAF7), oscuro: Tinte(0x2A2825))
    /// Lo que se hunde: campos, pozos, canales.
    public static let hueco = Color.dinamico(claro: Tinte(0xE4E1DB), oscuro: Tinte(0x121110))

    // MARK: - Luz y sombra del neumorfismo

    /// La sombra proyectada. En claro es calida, no negra: un gris neutro
    /// sobre un fondo calido lo ensucia.
    public static let sombra = Color.dinamico(claro: Tinte(0xB4AC9F, 0.72), oscuro: Tinte(0x000000, 0.78))
    /// El brillo del lado contrario, que es lo que hace que parezca volumen.
    public static let luz = Color.dinamico(claro: Tinte(0xFFFFFF, 0.95), oscuro: Tinte(0xFFFFFF, 0.055))
    /// Filo de un pixel en el borde superior de las piezas en relieve.
    public static let filo = Color.dinamico(claro: Tinte(0xFFFFFF, 0.75), oscuro: Tinte(0xFFFFFF, 0.09))

    // MARK: - Tinta

    public static let texto = Color.dinamico(claro: Tinte(0x191817), oscuro: Tinte(0xF6F4EF))
    /// Segundas lineas de titular, valores secundarios, unidades.
    public static let textoSuave = Color.dinamico(claro: Tinte(0x7C776E), oscuro: Tinte(0x9A948A))
    /// Lo que esta apagado, bloqueado o todavia no ha pasado.
    public static let textoTenue = Color.dinamico(claro: Tinte(0xADA79C), oscuro: Tinte(0x6A655D))

    // MARK: - Acento

    /// El unico color de la app. Se usa con cuentagotas: lo que esta activo,
    /// lo que progresa y poco mas.
    public static let acento = Color.dinamico(claro: Tinte(0xE2611B), oscuro: Tinte(0xFF7A2F))
    /// Fondo de las pastillas de acento. Nunca lleva texto de acento encima.
    public static let acentoTenue = Color.dinamico(claro: Tinte(0xF6DCCB), oscuro: Tinte(0x3B2314))

    // MARK: - Pantalla del reto

    // El reto se mira a las seis de la manana, a oscuras y con los ojos a medio
    // abrir. Ahi el neumorfismo estorba: hace falta contraste bruto. Estos
    // colores son los unicos de la app que no son sutiles a proposito.

    /// Fondo del reto: blanco puro de dia, casi negro de noche. De noche NO se
    /// enciende una pantalla blanca en la cara de alguien que acaba de abrir
    /// los ojos.
    public static let retoFondo = Color.dinamico(claro: Tinte(0xFFFFFF), oscuro: Tinte(0x0A0A09))
    /// Maximo contraste contra `retoFondo`. Sin grises sobre grises.
    public static let retoTinta = Color.dinamico(claro: Tinte(0x000000), oscuro: Tinte(0xFFFFFF))
    /// Lo que falta por hacer: puntos apagados y pista del anillo.
    public static let retoApagado = Color.dinamico(claro: Tinte(0xD5D1C9), oscuro: Tinte(0x302E2A))
}
