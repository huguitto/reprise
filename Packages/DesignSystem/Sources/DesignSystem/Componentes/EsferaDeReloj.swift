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

            // Las dos marcas de la hora que muestra la esfera.
            //
            // Antes habia una sola bolita, clavada arriba a la izquierda, que
            // venia de la referencia y no significaba nada. Enganaba: en una
            // esfera con canto moleteado, un punto sobre el circulo se lee como
            // una aguja, y estaba siempre en el mismo sitio dijera la hora lo
            // que dijera.
            //
            // Ahora son dos y apuntan de verdad. Se reparten como las agujas de
            // un reloj, que es lo que todo el mundo sabe leer sin pensar: la de
            // la hora corta y por dentro, la de los minutos larga y por fuera.
            // Con radios distintos ademas no se pisan cuando coinciden, que
            // pasa a cada hora en punto y a y media.
            marca(angulo: anguloDeLaHora, radio: diametro * 0.315, tamano: diametro * 0.042)
            marca(angulo: anguloDelMinuto, radio: diametro * 0.415, tamano: diametro * 0.030)
        }
        .frame(width: diametro, height: diametro)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            String(format: activa ? "Alarma puesta a las %d:%02d" : "Alarma apagada, %d:%02d",
                   hora, minuto)
        ))
    }

    // MARK: - Las marcas

    /// Angulo de la marca de la hora, en radianes desde las doce.
    ///
    /// Salta de hora en hora y **no** avanza con los minutos. A las 7:05 sigue
    /// clavada en el 7: aqui la esfera se lee de un vistazo desde la cama, y
    /// una marca a medio camino entre dos numeros es justo lo que obliga a
    /// mirar dos veces.
    private var anguloDeLaHora: Double {
        Double(hora % 12) / 12 * 2 * .pi
    }

    /// Angulo de la marca de los minutos, en radianes desde las doce.
    private var anguloDelMinuto: Double {
        Double(minuto % 60) / 60 * 2 * .pi
    }

    /// Una marca sobre la esfera. El angulo se mide desde las doce y en el
    /// sentido de las agujas, no desde el eje X: es como se piensa una hora.
    private func marca(angulo: Double, radio: CGFloat, tamano: CGFloat) -> some View {
        Circle()
            .fill(activa ? Paleta.acento : Paleta.textoTenue)
            .frame(width: tamano, height: tamano)
            .offset(x: radio * sin(angulo), y: -radio * cos(angulo))
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

#Preview("Esfera") {
    MuestraDeEsfera().preferredColorScheme(.dark)
}

struct MuestraDeEsfera: View {
    // Las horas elegidas son las que hacen dano: 12:00 pone las dos marcas en
    // el mismo angulo, 6:30 tambien, y 7:05 es la que pidio el usuario.
    private let horas = [(6, 30), (7, 5), (12, 0), (9, 45)]

    var body: some View {
        ScrollView {
            VStack(spacing: Espacio.ancho) {
                EsferaDeReloj(hora: 7, minuto: 0, activa: true)
                HStack(spacing: Espacio.normal) {
                    ForEach(horas, id: \.0) { hora, minuto in
                        EsferaDeReloj(hora: hora, minuto: minuto, diametro: 82)
                    }
                }
                EsferaDeReloj(hora: 8, minuto: 20, activa: false, diametro: 140)
            }
            .padding(Espacio.ancho)
            .frame(maxWidth: .infinity)
        }
        .fondoDePantalla()
    }
}
