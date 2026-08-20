import SwiftUI
import AlarmCore

/// Ajustes. Corto a proposito: cada opcion que se anade es una decision que el
/// usuario tiene que tomar a cambio de nada.
public struct PantallaAjustes: View {
    @State private var tema: Tema = .sistema
    @State private var retoPorDefecto: ChallengeType = .pasos
    @State private var vibrar = true
    private let esPro: Bool

    public init(esPro: Bool = false) {
        self.esPro = esPro
    }

    enum Tema: String, CaseIterable {
        case sistema = "Sistema"
        case claro = "Claro"
        case oscuro = "Oscuro"
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("Ajustes") {
                    Button { } label: { Image(systemName: "xmark") }
                        .buttonStyle(.redondo)
                }

                if !esPro {
                    tarjetaDePro
                }

                seccion("Cuenta") {
                    Bloque {
                        FilaDeAjuste(icono: "person.crop.circle", titulo: "Entrar",
                                     detalle: "Para aparecer en el ranking") {
                            chevron
                        }
                    }
                    // La regla de producto que mas tranquiliza y que casi nadie
                    // se espera: la alarma no necesita cuenta.
                    Text("La alarma y la racha funcionan sin cuenta. Entrar solo sirve para el ranking.")
                        .font(Tipografia.pie)
                        .foregroundStyle(Paleta.textoTenue)
                        .padding(.horizontal, Espacio.mini)
                }

                seccion("Alarma") {
                    Bloque {
                        FilaDeAjuste(icono: "speaker.wave.2", titulo: "Tono por defecto",
                                     detalle: "Amanecer") { chevron }
                        Raya()
                        FilaApilada(icono: retoPorDefecto.simbolo, titulo: "Reto por defecto") {
                            SelectorSegmentado(
                                opciones: ChallengeType.allCases,
                                seleccion: $retoPorDefecto
                            ) { $0 == .pasos ? "20 pasos" : "10 sentadillas" }
                        }
                        Raya()
                        FilaDeAjuste(icono: "iphone.gen3.radiowaves.left.and.right",
                                     titulo: "Vibrar con la alarma") {
                            Interruptor(encendido: $vibrar)
                        }
                    }
                }

                seccion("Apariencia") {
                    Bloque {
                        FilaApilada(icono: "circle.lefthalf.filled", titulo: "Tema") {
                            SelectorSegmentado(opciones: Tema.allCases, seleccion: $tema) { $0.rawValue }
                        }
                    }
                }

                seccion("La app") {
                    Bloque {
                        FilaDeAjuste(icono: "questionmark.circle", titulo: "Cómo funciona la racha") { chevron }
                        Raya()
                        FilaDeAjuste(icono: "envelope", titulo: "Escribirnos") { chevron }
                        Raya()
                        FilaDeAjuste(icono: "doc.text", titulo: "Privacidad y condiciones") { chevron }
                        Raya()
                        FilaDeAjuste(icono: "info.circle", titulo: "Versión", detalle: "1.0 (1)")
                    }
                }
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Paleta.textoTenue)
    }

    private var tarjetaDePro: some View {
        HStack(spacing: Espacio.normal) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Paleta.acento)
            VStack(alignment: .leading, spacing: 2) {
                Text("RepRise Pro")
                    .font(Tipografia.cuerpoFuerte)
                    .foregroundStyle(Paleta.texto)
                Text("Alarmas ilimitadas, tonos y estadísticas")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
            }
            Spacer(minLength: Espacio.corto)
            chevron
        }
        .padding(Espacio.normal)
        .relieve(.medio, radio: Radio.medio, color: Paleta.superficieAlta)
        .padding(.horizontal, Espacio.margen)
    }

    private func seccion<Contenido: View>(
        _ rotulo: String,
        @ViewBuilder contenido: () -> Contenido
    ) -> some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            Text(rotulo).estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)
            VStack(alignment: .leading, spacing: Espacio.corto) {
                contenido()
            }
            .padding(.horizontal, Espacio.margen)
        }
    }
}

#Preview("Ajustes · claro") {
    PantallaAjustes()
}

#Preview("Ajustes · oscuro") {
    PantallaAjustes().preferredColorScheme(.dark)
}
