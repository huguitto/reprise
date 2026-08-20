import SwiftUI
import AlarmCore

/// Crear o editar una alarma.
///
/// La hora no se pone con el selector de ruedas del sistema: es la unica pieza
/// de iOS que no se puede vestir, y en medio de esta pantalla parece de otra
/// app. En su lugar, la esfera de la referencia y la regla de su pie.
public struct PantallaEditarAlarma: View {
    @State private var alarma: Alarm
    @State private var moviendo: Movimiento = .hora
    private let esNueva: Bool

    public init(alarma: Alarm? = nil, esNueva: Bool = false) {
        // Una alarma nueva empieza en blanco: las siete en punto y sin dias.
        // Heredar la alarma de ejemplo confunde al que la esta creando.
        let inicial = alarma ?? (esNueva
            ? Alarm(hour: 7, minute: 0, challenge: .pasos)
            : DatosDeMentira.alarmas[0])
        self._alarma = State(initialValue: inicial)
        self.esNueva = esNueva
    }

    private enum Movimiento: String, CaseIterable {
        case hora = "Hora"
        case minuto = "Minuto"
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera(esNueva ? "Nueva" : "Editar", subtitulo: "alarma") {
                    Button { } label: { Image(systemName: "xmark") }
                        .buttonStyle(.redondo)
                }

                selectorDeHora

                seccion("Se repite") {
                    VStack(alignment: .leading, spacing: Espacio.medio) {
                        SelectorDeDias(dias: $alarma.weekdays)
                        Text(alarma.weekdays.resumen)
                            .font(Tipografia.pie)
                            .foregroundStyle(Paleta.textoSuave)
                    }
                }

                seccion("Para apagarla") {
                    HStack(spacing: Espacio.medio) {
                        ForEach(ChallengeType.allCases, id: \.self) { reto in
                            TarjetaDeReto(reto: reto, elegido: alarma.challenge == reto) {
                                withAnimation(.easeOut(duration: 0.15)) { alarma.challenge = reto }
                            }
                        }
                    }
                }

                seccion("Detalles") {
                    VStack(spacing: Espacio.medio) {
                        Bloque {
                            FilaDeAjuste(icono: "speaker.wave.2", titulo: "Tono",
                                         detalle: nombreDelTono) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Paleta.textoTenue)
                            }
                        }
                        CampoDeTexto("Etiqueta", texto: $alarma.label)
                    }
                }

                VStack(spacing: Espacio.medio) {
                    Button("Guardar") {}.buttonStyle(.principal)
                    if !esNueva {
                        Button("Eliminar la alarma") {}.buttonStyle(.texto)
                    }
                }
                .padding(.horizontal, Espacio.margen)

                Text("No hay snooze. Nunca lo habrá.")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoTenue)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
    }

    // MARK: - Hora

    private var selectorDeHora: some View {
        VStack(spacing: Espacio.amplio) {
            EsferaDeReloj(hora: alarma.hour, minuto: alarma.minute, diametro: 230)

            VStack(spacing: Espacio.normal) {
                SelectorSegmentado(opciones: Movimiento.allCases, seleccion: $moviendo) { $0.rawValue }
                    .frame(maxWidth: 220)

                ReglaHorizontal(progreso: progresoDeLaRegla)
                    .contentShape(Rectangle())
                    .gesture(arrastreDeLaRegla)
            }
            .padding(.horizontal, Espacio.margen)
        }
        .frame(maxWidth: .infinity)
    }

    private var progresoDeLaRegla: Double {
        switch moviendo {
        case .hora: Double(alarma.hour) / 23
        case .minuto: Double(alarma.minute) / 59
        }
    }

    /// Arrastrar sobre la regla mueve la hora o el minuto. La regla ocupa el
    /// ancho de la pantalla menos los margenes; se calcula sobre la posicion
    /// absoluta del dedo, no sobre el desplazamiento, para que no se acumule
    /// error al arrastrar despacio.
    private var arrastreDeLaRegla: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesto in
                let ancho = max(gesto.startLocation.x + 1, 300)
                let fraccion = min(max(gesto.location.x / ancho, 0), 1)
                switch moviendo {
                case .hora: alarma.hour = Int((fraccion * 23).rounded())
                case .minuto: alarma.minute = Int((fraccion * 59).rounded())
                }
            }
    }

    private var nombreDelTono: String {
        DatosDeMentira.tonos.first { $0.id == alarma.toneID }?.nombre ?? "El del sistema"
    }

    // MARK: - Andamiaje

    private func seccion<Contenido: View>(
        _ rotulo: String,
        @ViewBuilder contenido: () -> Contenido
    ) -> some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            Text(rotulo).estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)
            contenido()
                .padding(.horizontal, Espacio.margen)
        }
    }
}

/// Tarjeta de reto. Elegida = hundida y con el acento, igual que un dia del
/// selector: en esta app lo pulsado se hunde, siempre.
private struct TarjetaDeReto: View {
    let reto: ChallengeType
    let elegido: Bool
    let alPulsar: () -> Void

    var body: some View {
        Button(action: alPulsar) {
            VStack(spacing: Espacio.corto) {
                Image(systemName: reto.simbolo)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(elegido ? Paleta.acento : Paleta.textoSuave)
                Text(reto.nombre)
                    .font(Tipografia.pieFuerte)
                    .foregroundStyle(elegido ? Paleta.texto : Paleta.textoSuave)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Espacio.amplio)
            .background {
                if elegido {
                    Color.clear.hueco(.sutil, radio: Radio.medio, color: Paleta.acentoTenue)
                } else {
                    Color.clear.relieve(.bajo, radio: Radio.medio)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegido ? [.isSelected] : [])
    }
}

#Preview("Editar alarma") {
    PantallaEditarAlarma().preferredColorScheme(.dark)
}

#Preview("Nueva alarma") {
    PantallaEditarAlarma(
        alarma: Alarm(hour: 7, minute: 0, challenge: .sentadillas),
        esNueva: true
    )
    .preferredColorScheme(.dark)
}
