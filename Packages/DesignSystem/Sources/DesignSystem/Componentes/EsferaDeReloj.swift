import SwiftUI

/// La esfera del reloj: el objeto de la referencia 01.
///
/// Un disco casi blanco que sobresale del fondo, con el canto moleteado y la
/// hora en matriz de puntos a dos pisos. Es la pieza mas cara de la app en
/// atencion visual, asi que sale **una sola vez por pantalla**.
public struct EsferaDeReloj: View {
    private let hora: Int
    private let minuto: Int
    private let activa: Bool
    private let diametro: CGFloat

    public init(hora: Int, minuto: Int, activa: Bool = true, diametro: CGFloat = 260) {
        self.hora = hora
        self.minuto = minuto
        self.activa = activa
        self.diametro = diametro
    }

    public var body: some View {
        ZStack {
            Color.clear
                .relieve(.alto, forma: Circle(), color: Paleta.superficieAlta)

            CantoMoleteado()
                .padding(diametro * 0.055)

            HoraDeMatriz(
                hora: hora,
                minuto: minuto,
                altura: diametro * 0.235,
                color: activa ? Paleta.texto : Paleta.textoTenue
            )

            // El testigo de la referencia, arriba a la izquierda. Es lo unico
            // que dice si la alarma esta puesta, y por eso lleva el acento.
            Circle()
                .fill(activa ? Paleta.acento : Paleta.textoTenue)
                .frame(width: diametro * 0.035, height: diametro * 0.035)
                .offset(x: -diametro * 0.29, y: -diametro * 0.26)
        }
        .frame(width: diametro, height: diametro)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(activa ? "Alarma puesta" : "Alarma apagada"))
    }
}

/// El canto del disco: rayitas finas hacia dentro, como el moleteado de una
/// rueda de metal. Es lo que le quita cara de circulo dibujado.
private struct CantoMoleteado: View {
    var body: some View {
        Canvas { contexto, tamano in
            let centro = CGPoint(x: tamano.width / 2, y: tamano.height / 2)
            let radio = min(tamano.width, tamano.height) / 2
            let rayas = 120
            for indice in 0..<rayas {
                let angulo = Double(indice) / Double(rayas) * 2 * .pi
                let larga = indice % 10 == 0
                let dentro = radio - (larga ? radio * 0.05 : radio * 0.028)
                var trazo = Path()
                trazo.move(to: CGPoint(x: centro.x + cos(angulo) * dentro,
                                       y: centro.y + sin(angulo) * dentro))
                trazo.addLine(to: CGPoint(x: centro.x + cos(angulo) * radio,
                                          y: centro.y + sin(angulo) * radio))
                contexto.stroke(
                    trazo,
                    with: .color(Paleta.textoTenue.opacity(larga ? 0.45 : 0.22)),
                    lineWidth: 1
                )
            }
        }
    }
}

#Preview("Esfera · claro") {
    MuestraDeEsfera()
}

#Preview("Esfera · oscuro") {
    MuestraDeEsfera().preferredColorScheme(.dark)
}

struct MuestraDeEsfera: View {
    var body: some View {
        VStack(spacing: Espacio.ancho) {
            EsferaDeReloj(hora: 6, minuto: 30, activa: true)
            EsferaDeReloj(hora: 8, minuto: 0, activa: false, diametro: 140)
        }
        .padding(Espacio.ancho)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoDePantalla()
    }
}
