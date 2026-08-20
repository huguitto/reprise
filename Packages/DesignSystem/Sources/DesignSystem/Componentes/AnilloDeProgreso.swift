import SwiftUI

/// El anillo de la referencia 02: pista punteada y arco macizo de acento.
///
/// Los puntos de la pista no son decoracion, son la misma rejilla que las
/// cifras: la app entera esta hecha de puntos.
public struct AnilloDeProgreso<Contenido: View>: View {
    private let progreso: Double
    private let grosor: CGFloat
    private let colorArco: Color
    private let colorPista: Color
    private let contenido: Contenido

    public init(
        progreso: Double,
        grosor: CGFloat = 10,
        colorArco: Color = Paleta.acento,
        colorPista: Color = Paleta.retoApagado,
        @ViewBuilder contenido: () -> Contenido = { EmptyView() }
    ) {
        self.progreso = min(max(progreso, 0), 1)
        self.grosor = grosor
        self.colorArco = colorArco
        self.colorPista = colorPista
        self.contenido = contenido()
    }

    public var body: some View {
        ZStack {
            PistaPunteada(color: colorPista, diametroDelPunto: grosor * 0.42)

            Circle()
                .trim(from: 0, to: progreso)
                .stroke(colorArco, style: StrokeStyle(lineWidth: grosor, lineCap: .round))
                // Empezar arriba, no a las tres en punto.
                .rotationEffect(.degrees(-90))
                .padding(grosor / 2)

            contenido
        }
        .animation(.easeOut(duration: 0.35), value: progreso)
        .accessibilityElement(children: .combine)
    }
}

private struct PistaPunteada: View {
    let color: Color
    let diametroDelPunto: CGFloat

    var body: some View {
        Canvas { contexto, tamano in
            let centro = CGPoint(x: tamano.width / 2, y: tamano.height / 2)
            let radio = min(tamano.width, tamano.height) / 2 - diametroDelPunto
            let puntos = 72
            for indice in 0..<puntos {
                let angulo = Double(indice) / Double(puntos) * 2 * .pi - .pi / 2
                let centroDelPunto = CGPoint(x: centro.x + cos(angulo) * radio,
                                             y: centro.y + sin(angulo) * radio)
                let marco = CGRect(
                    x: centroDelPunto.x - diametroDelPunto / 2,
                    y: centroDelPunto.y - diametroDelPunto / 2,
                    width: diametroDelPunto,
                    height: diametroDelPunto
                )
                contexto.fill(Path(ellipseIn: marco), with: .color(color))
            }
        }
    }
}

#Preview("Anillo") {
    MuestraDeAnillo().preferredColorScheme(.dark)
}

struct MuestraDeAnillo: View {
    var body: some View {
        HStack(spacing: Espacio.amplio) {
            AnilloDeProgreso(progreso: 0.35) {
                TextoDeMatriz("07", altura: 54)
            }
            .frame(width: 160, height: 160)

            AnilloDeProgreso(progreso: 1) {
                TextoDeMatriz("20", altura: 54, color: Paleta.acento)
            }
            .frame(width: 160, height: 160)
        }
        .padding(Espacio.amplio)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoDePantalla()
    }
}
