import SwiftUI
import AlarmCore

/// Lista de alarmas. Es la pantalla que se ve de dia, con calma, y por eso es
/// donde el neumorfismo puede lucirse.
///
/// La proxima alarma sale como objeto — la esfera de la referencia — y el resto
/// como filas. Una sola alarma grande y las demas pequenas: la que importa a
/// las once de la noche es la de manana.
public struct PantallaListaDeAlarmas: View {
    @State private var alarmas = DatosDeMentira.alarmas

    public init() {}

    private var proxima: Alarm? { alarmas.first(where: \.isEnabled) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("Alarmas", subtitulo: subtituloDeCabecera) {
                    Button { } label: { Image(systemName: "plus") }
                        .buttonStyle(.redondo)
                }

                if let proxima {
                    VStack(spacing: Espacio.normal) {
                        EsferaDeReloj(hora: proxima.hour, minuto: proxima.minute, diametro: 250)
                        VStack(spacing: Espacio.corto) {
                            Text(proxima.label.isEmpty ? "Sin etiqueta" : proxima.label)
                                .font(Tipografia.cuerpoFuerte)
                                .foregroundStyle(Paleta.texto)
                            HStack(spacing: Espacio.corto) {
                                Pastilla(proxima.weekdays.resumen)
                                Pastilla(proxima.challenge.nombre, icono: proxima.challenge.simbolo)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Espacio.corto)
                }

                TiraDeRacha(racha: DatosDeMentira.rachaActual,
                            vidas: DatosDeMentira.vidasRestantes)
                    .padding(.horizontal, Espacio.margen)

                VStack(alignment: .leading, spacing: Espacio.medio) {
                    Text("Todas").estiloRotulo()
                        .padding(.horizontal, Espacio.margen + Espacio.mini)

                    VStack(spacing: Espacio.medio) {
                        ForEach($alarmas) { $alarma in
                            FilaDeAlarma(alarma: $alarma)
                        }
                    }
                    .padding(.horizontal, Espacio.margen)
                }

                Text("Con la versión gratis solo puede quedar una alarma activa.")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoTenue)
                    .padding(.horizontal, Espacio.margen)
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
    }

    private var subtituloDeCabecera: String {
        guard let proxima else { return "Ninguna puesta" }
        return String(format: "Mañana a las %d:%02d", proxima.hour, proxima.minute)
    }
}

/// Fila de una alarma: la hora en matriz pequena, el contexto debajo y el
/// interruptor a la derecha.
private struct FilaDeAlarma: View {
    @Binding var alarma: Alarm

    var body: some View {
        HStack(spacing: Espacio.normal) {
            TextoDeMatriz(
                String(format: "%02d:%02d", alarma.hour, alarma.minute),
                altura: 22,
                color: alarma.isEnabled ? Paleta.texto : Paleta.textoTenue
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(alarma.label.isEmpty ? alarma.challenge.nombre : alarma.label)
                    .font(Tipografia.pieFuerte)
                    .foregroundStyle(alarma.isEnabled ? Paleta.texto : Paleta.textoTenue)
                    .lineLimit(1)
                Text(alarma.weekdays.resumen)
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: Espacio.corto)

            Interruptor(encendido: $alarma.isEnabled)
        }
        .padding(.horizontal, Espacio.normal)
        .padding(.vertical, Espacio.normal)
        .relieve(.bajo, radio: Radio.medio)
        .opacity(alarma.isEnabled ? 1 : 0.7)
    }
}

/// Tira compacta con la racha y las vidas. Es el enlace de todos los dias a la
/// pantalla de racha, y de paso el recordatorio de lo que hay en juego.
struct TiraDeRacha: View {
    let racha: Int
    let vidas: Int

    var body: some View {
        HStack(spacing: Espacio.normal) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Paleta.acento)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(racha)")
                    .font(Tipografia.cifra(22, .bold))
                    .foregroundStyle(Paleta.texto)
                Text("días seguidos")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<StreakState.livesPerMonth, id: \.self) { indice in
                    Image(systemName: indice < vidas ? "heart.fill" : "heart")
                        .font(.system(size: 12))
                        .foregroundStyle(indice < vidas ? Paleta.acento : Paleta.textoTenue)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Paleta.textoTenue)
        }
        .padding(.horizontal, Espacio.normal)
        .padding(.vertical, 14)
        .relieve(.bajo, radio: Radio.medio)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Racha de \(racha) días, \(vidas) vidas este mes"))
    }
}

#Preview("Lista de alarmas · claro") {
    PantallaListaDeAlarmas()
}

#Preview("Lista de alarmas · oscuro") {
    PantallaListaDeAlarmas().preferredColorScheme(.dark)
}
