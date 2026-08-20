import SwiftUI

/// Puerta de entrada al sistema de diseno.
///
/// Sirve para dos cosas: ver las pantallas en el iPhone de verdad, que es donde
/// se juzga un neumorfismo, y tener a mano el muestrario de piezas cuando haya
/// que montar la app encima.
///
/// Todo lo que hay debajo es estatico y con datos inventados.
public struct GaleriaDeDiseno: View {
    @State private var tema: Tema = .sistema

    public init() {}

    enum Tema: String, CaseIterable {
        case sistema = "Sistema"
        case claro = "Claro"
        case oscuro = "Oscuro"

        var esquema: ColorScheme? {
            switch self {
            case .sistema: nil
            case .claro: .light
            case .oscuro: .dark
            }
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.amplio) {
                    Cabecera("RepRise", subtitulo: "sistema de diseño")

                    SelectorSegmentado(opciones: Tema.allCases, seleccion: $tema) { $0.rawValue }
                        .padding(.horizontal, Espacio.margen)

                    grupo("Pantallas") {
                        enlace("Lista de alarmas", "alarm") { PantallaListaDeAlarmas() }
                        Raya()
                        enlace("Crear y editar alarma", "plus.circle") {
                            PantallaEditarAlarma(esNueva: true)
                        }
                        Raya()
                        enlace("El reto en curso", "figure.walk") {
                            PantallaReto(reto: .pasos, hechos: 7, segundos: 47)
                        }
                        Raya()
                        enlace("El reto terminado", "checkmark.circle") {
                            PantallaReto(reto: .sentadillas, hechos: 10, segundos: 62)
                        }
                        Raya()
                        enlace("Racha, niveles e insignias", "flame") { PantallaRacha() }
                        Raya()
                        enlace("Ranking", "list.number") { PantallaRanking() }
                        Raya()
                        enlace("Ajustes", "gearshape") { PantallaAjustes() }
                        Raya()
                        enlace("Muro de pago", "bolt") { PantallaMuroDePago() }
                    }

                    grupo("Piezas") {
                        enlace("Superficies", "square.on.square") { MuestraDeSuperficies() }
                        Raya()
                        enlace("Matriz de puntos", "circle.grid.3x3") { MuestraDeMatriz() }
                        Raya()
                        enlace("Esfera de reloj", "clock") { MuestraDeEsfera() }
                        Raya()
                        enlace("Dial de apagado", "power") { MuestraDeDial() }
                        Raya()
                        enlace("Anillo de progreso", "circle.dashed") { MuestraDeAnillo() }
                        Raya()
                        enlace("Botones", "hand.tap") { MuestraDeBotones() }
                        Raya()
                        enlace("Controles", "switch.2") { MuestraDeControles() }
                        Raya()
                        enlace("Selector de días", "calendar") { MuestraDeDias() }
                        Raya()
                        enlace("Pastillas, cifras e insignias", "rosette") { MuestraDePiezas() }
                    }
                }
                .padding(.vertical, Espacio.amplio)
            }
            .fondoDePantalla()
        }
        .tint(Paleta.acento)
        .preferredColorScheme(tema.esquema)
    }

    private func grupo<Contenido: View>(
        _ rotulo: String,
        @ViewBuilder contenido: () -> Contenido
    ) -> some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            Text(rotulo).estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)
            Bloque { contenido() }
                .padding(.horizontal, Espacio.margen)
        }
    }

    private func enlace<Destino: View>(
        _ titulo: String,
        _ icono: String,
        @ViewBuilder destino: @escaping () -> Destino
    ) -> some View {
        NavigationLink {
            destino()
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
        } label: {
            FilaDeAjuste(icono: icono, titulo: titulo) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paleta.textoTenue)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Galeria · claro") {
    GaleriaDeDiseno()
}

#Preview("Galeria · oscuro") {
    GaleriaDeDiseno().preferredColorScheme(.dark)
}
