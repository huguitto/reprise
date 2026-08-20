import SwiftUI

/// Un color fijo, escrito con el mismo hexadecimal que usa el diseno.
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

/// Los colores de RepRise.
///
/// Base monocroma en gris calido muy oscuro y **un solo color de acento**: el
/// azul del sistema. Si algo necesita destacar y no es el acento, se resuelve con peso
/// tipografico o con relieve, nunca con un segundo color.
///
/// **La app es solo oscura.** No hay pareja clara ni color que cambie con el
/// sistema: cada token es un color y ya esta. Se decidio asi porque el
/// despertador se mira a las seis de la manana con la habitacion a oscuras, y
/// un modo claro solo servia para deslumbrar al que acaba de abrir los ojos.
/// Si algun dia vuelve el claro, esto es lo que hay que volver a partir en dos.
public enum Paleta {

    // MARK: - Superficies

    /// El papel sobre el que se apoya todo.
    public static let fondo = Tinte(0x171614).color
    /// Lo que sobresale del fondo: tarjetas, filas, botones.
    public static let superficie = Tinte(0x201F1C).color
    /// Lo que sobresale del todo: la esfera del reloj, el mando del dial.
    public static let superficieAlta = Tinte(0x2A2825).color
    /// Lo que se hunde: campos, pozos, canales.
    public static let hueco = Tinte(0x121110).color

    // MARK: - Luz y sombra del neumorfismo

    /// La sombra proyectada.
    public static let sombra = Tinte(0x000000, 0.78).color
    /// El brillo del lado contrario, que es lo que hace que parezca volumen.
    /// En oscuro es un blanco casi invisible: subirlo convierte el plastico en
    /// plastico barato con purpurina.
    public static let luz = Tinte(0xFFFFFF, 0.055).color
    /// Filo de un pixel en el borde superior de las piezas en relieve.
    public static let filo = Tinte(0xFFFFFF, 0.09).color

    // MARK: - Tinta

    public static let texto = Tinte(0xF6F4EF).color
    /// Segundas lineas de titular, valores secundarios, unidades.
    public static let textoSuave = Tinte(0x9A948A).color
    /// Lo que esta apagado, bloqueado o todavia no ha pasado.
    public static let textoTenue = Tinte(0x6A655D).color

    // MARK: - Acento

    /// El unico color de la app. Se usa con cuentagotas: lo que esta activo,
    /// lo que progresa y poco mas.
    ///
    /// Es el azul de sistema de Apple en su version oscura (`systemBlue` en
    /// modo oscuro), no el claro: el claro esta calibrado para ir sobre blanco
    /// y aqui se apaga.
    public static let acento = Tinte(0x0A84FF).color
    /// Fondo de las pastillas de acento. Nunca lleva texto de acento encima.
    public static let acentoTenue = Tinte(0x12283F).color

    // MARK: - Pantalla del reto

    // El reto se mira a las seis de la manana y con los ojos a medio abrir. Ahi
    // el neumorfismo estorba: hace falta contraste bruto. Estos colores son los
    // unicos de la app que no son sutiles a proposito.

    /// Fondo del reto: casi negro. NO se enciende una pantalla blanca en la
    /// cara de alguien que acaba de abrir los ojos.
    public static let retoFondo = Tinte(0x0A0A09).color
    /// Maximo contraste contra `retoFondo`. Sin grises sobre grises.
    public static let retoTinta = Tinte(0xFFFFFF).color
    /// Lo que falta por hacer: puntos apagados y pista del anillo.
    public static let retoApagado = Tinte(0x302E2A).color
}
