import SwiftUI

/// Texto dibujado con la matriz de puntos de RepRise.
///
/// Solo acepta cifras y unos pocos signos: es un display, no una tipografia.
/// Para cualquier texto de verdad esta `Tipografia`.
public struct TextoDeMatriz: View {
    private let texto: String
    private let altura: CGFloat
    private let grosor: CGFloat
    private let color: Color
    private let colorApagado: Color?

    /// - Parameters:
    ///   - altura: alto total del display, de la primera fila de puntos a la
    ///     ultima. Es la medida con la que se piensa en la pantalla.
    ///   - grosor: diametro del punto respecto a su celda. Por debajo de 0,5
    ///     las cifras se deshilachan; por encima de 0,8 se cierran los huecos y
    ///     deja de leerse como matriz.
    ///   - colorApagado: si se pasa, dibuja tambien los puntos que no forman la
    ///     cifra. Da la textura de panel encendido, pero baja el contraste: en
    ///     la pantalla del reto se usa con cuidado.
    public init(
        _ texto: String,
        altura: CGFloat,
        grosor: CGFloat = 0.66,
        color: Color = Paleta.texto,
        colorApagado: Color? = nil
    ) {
        self.texto = texto
        self.altura = altura
        self.grosor = grosor
        self.color = color
        self.colorApagado = colorApagado
    }

    private var paso: CGFloat { altura / CGFloat(FuenteDePuntos.filas) }
    private var diametro: CGFloat { paso * grosor }

    public var body: some View {
        let compuesto = FuenteDePuntos.componer(texto)
        let ancho = paso * CGFloat(compuesto.columnas)

        Canvas(rendersAsynchronously: false) { contexto, _ in
            if let colorApagado {
                dibujar(compuesto.apagadas, en: contexto, con: colorApagado)
            }
            dibujar(compuesto.encendidas, en: contexto, con: color)
        }
        .frame(width: ancho, height: altura)
        .accessibilityLabel(Text(texto))
    }

    private func dibujar(_ puntos: [Punto], en contexto: GraphicsContext, con color: Color) {
        let margen = (paso - diametro) / 2
        for punto in puntos {
            let marco = CGRect(
                x: CGFloat(punto.columna) * paso + margen,
                y: CGFloat(punto.fila) * paso + margen,
                width: diametro,
                height: diametro
            )
            contexto.fill(Path(ellipseIn: marco), with: .color(color))
        }
    }
}

/// La hora en dos pisos, como en el reloj de la referencia: las horas encima de
/// los minutos, no separadas por dos puntos.
public struct HoraDeMatriz: View {
    private let hora: Int
    private let minuto: Int
    private let altura: CGFloat
    private let color: Color
    private let colorApagado: Color?

    /// Lo que se separan los dos pisos, en alturas de piso.
    ///
    /// `nonisolated` porque las cuentas de la esfera se hacen fuera de la
    /// pantalla, y un `View` es del actor principal solo por serlo.
    nonisolated static let separacionEntrePisos: CGFloat = 0.16

    /// Lo que ocupa el bloque entero cuando cada piso mide `altura`.
    ///
    /// No es un adorno de la vista: la esfera lo necesita para saber por donde
    /// no puede pasar la bolita de la hora. Antes ese hueco se calculaba a ojo
    /// en el otro fichero y la bolita acababa pisando los digitos.
    nonisolated static func tamano(altura: CGFloat) -> CGSize {
        let paso = altura / CGFloat(FuenteDePuntos.filas)
        // Dos cifras, y todos los digitos miden lo mismo de ancho: el bloque no
        // cambia de tamano con la hora que marque.
        let columnas = FuenteDePuntos.componer("00").columnas
        return CGSize(width: paso * CGFloat(columnas),
                      height: altura * (2 + separacionEntrePisos))
    }

    public init(
        hora: Int,
        minuto: Int,
        altura: CGFloat,
        color: Color = Paleta.texto,
        colorApagado: Color? = nil
    ) {
        self.hora = hora
        self.minuto = minuto
        self.altura = altura
        self.color = color
        self.colorApagado = colorApagado
    }

    public var body: some View {
        VStack(spacing: altura * Self.separacionEntrePisos) {
            TextoDeMatriz(dosCifras(hora), altura: altura, color: color, colorApagado: colorApagado)
            TextoDeMatriz(dosCifras(minuto), altura: altura, color: color, colorApagado: colorApagado)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(hora) y \(minuto) minutos"))
    }

    private func dosCifras(_ valor: Int) -> String {
        String(format: "%02d", valor)
    }
}

#Preview("Matriz de puntos") {
    MuestraDeMatriz().preferredColorScheme(.dark)
}

struct MuestraDeMatriz: View {
    var body: some View {
        VStack(spacing: Espacio.amplio) {
            TextoDeMatriz("0123456789", altura: 44)
            TextoDeMatriz("07/20", altura: 60, color: Paleta.acento)
            TextoDeMatriz("12", altura: 90, colorApagado: Paleta.retoApagado)
            HoraDeMatriz(hora: 10, minuto: 15, altura: 56)
        }
        .padding(Espacio.ancho)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoDePantalla()
    }
}
