import SwiftUI

/// La tipografia de RepRise.
///
/// Uso editorial, tomado de la referencia 02: titulares grandes y apretados,
/// segunda linea del titular en gris, y el numero como protagonista de la
/// pantalla. La jerarquia se hace con **tamano y peso**, nunca con color: el
/// unico color que entra es el acento.
public enum Tipografia {

    /// Titular de pantalla. Va pegado al margen izquierdo y ocupa dos lineas
    /// siempre que se pueda: la primera en tinta, la segunda en `textoSuave`.
    public static let titular = Font.system(size: 34, weight: .bold).width(.standard)
    /// Titular de una seccion dentro de una pantalla.
    public static let titulo = Font.system(size: 22, weight: .bold)
    /// Encabezado de lista. Va en mayusculas y muy espaciado.
    public static let rotulo = Font.system(size: 11, weight: .semibold)
    public static let cuerpo = Font.system(size: 17, weight: .regular)
    public static let cuerpoFuerte = Font.system(size: 17, weight: .semibold)
    public static let pie = Font.system(size: 13, weight: .regular)
    public static let pieFuerte = Font.system(size: 13, weight: .semibold)

    /// Cifras que se comparan en columna (posiciones, rachas de otros): las
    /// cifras tienen que ocupar todas lo mismo o la lista baila.
    public static func cifra(_ tamano: CGFloat, _ peso: Font.Weight = .semibold) -> Font {
        Font.system(size: tamano, weight: peso).monospacedDigit()
    }

    /// Espaciado entre letras. Los titulares grandes de SF necesitan
    /// apretarse; los rotulos en mayusculas, abrirse.
    public static let apretadoTitular: CGFloat = -1.0
    public static let apretadoTitulo: CGFloat = -0.5
    public static let abiertoRotulo: CGFloat = 1.3
}

extension View {
    /// Titular de pantalla, con su interletraje ya aplicado.
    public func estiloTitular() -> some View {
        font(Tipografia.titular).tracking(Tipografia.apretadoTitular)
    }

    /// Rotulo de seccion: mayusculas, pequeno, abierto y en gris.
    public func estiloRotulo() -> some View {
        font(Tipografia.rotulo)
            .tracking(Tipografia.abiertoRotulo)
            .textCase(.uppercase)
            .foregroundStyle(Paleta.textoSuave)
    }
}
