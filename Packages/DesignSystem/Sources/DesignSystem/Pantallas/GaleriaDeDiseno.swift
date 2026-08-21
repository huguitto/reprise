import SwiftUI
import AlarmCore
import AlarmScheduler

/// Puerta de entrada al sistema de diseno.
///
/// Sirve para dos cosas: ver las pantallas en el iPhone de verdad, que es donde
/// se juzga un neumorfismo, y tener a mano el muestrario de piezas cuando haya
/// que montar la app encima.
///
/// Todo lo que hay debajo es estatico y con datos inventados.
public struct GaleriaDeDiseno: View {
    @Environment(\.dismiss) private var cerrar

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Espacio.amplio) {
                    Cabecera("RepRise", subtitulo: "sistema de diseño") {
                        Button { cerrar() } label: { Image(systemName: "xmark") }
                            .buttonStyle(.redondo)
                            .accessibilityLabel(Text("Cerrar"))
                    }

                    grupo("Pantallas") {
                        enlace("Presentación", "hand.wave") { FlujoDeEntrada(recordar: false) }
                        Raya()
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
                            PantallaReto(reto: .sentadillas, hechos: 10, segundos: 62, estado: .completado)
                        }
                        Raya()
                        enlace("El reto sin sensor", "exclamationmark.triangle") {
                            PantallaReto(
                                reto: .sentadillas,
                                hechos: 0,
                                segundos: 12,
                                estado: .sinSensor("Sin permiso de movimiento")
                            )
                        }
                        Raya()
                        enlace("Racha, niveles e insignias", "flame") { PantallaRacha() }
                        Raya()
                        enlace("Ranking", "list.number") { PantallaRanking() }
                        Raya()
                        enlace("Histórico del ranking", "clock.arrow.circlepath") {
                            PantallaHistoricoDeRanking()
                        }
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
                        enlace("Carrusel de alarmas", "rectangle.stack") { MuestraDeCarrusel() }
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

                    #if DEBUG
                    grupo("Pruebas") {
                        simularAlarma(.pasos)
                        Raya()
                        simularAlarma(.sentadillas)
                    }
                    #endif
                }
                .padding(.vertical, Espacio.amplio)
            }
            .fondoDePantalla()
        }
        .tint(Paleta.acento)
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

    #if DEBUG
    /// Finge el recado que deja el boton "Hacer el reto" de la alerta del
    /// sistema, para poder ver el reto de verdad —contando, con el cronometro
    /// y con el dial— sin esperar a las seis de la manana.
    ///
    /// Solo en DEBUG, y a proposito. El reto **no se visita** (decision de
    /// producto: ponerlo a un toque de distancia seria dar la forma de
    /// saltarselo), asi que esto no puede existir en lo que se publica. Va por
    /// el buzon y no llamando a la pantalla directamente para que lo que se
    /// prueba sea el camino entero, no una maqueta.
    private func simularAlarma(_ reto: ChallengeType) -> some View {
        Button {
            ChallengeInbox.post(
                ChallengeRequest(alarmID: UUID(), challenge: reto, requestedAt: Date())
            )
            cerrar()
        } label: {
            FilaDeAjuste(icono: reto.simbolo, titulo: "Simular la alarma · \(reto.nombre)") {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Paleta.textoTenue)
            }
        }
        .buttonStyle(.plain)
    }
    #endif

    private func enlace<Destino: View>(
        _ titulo: String,
        _ icono: String,
        @ViewBuilder destino: @escaping () -> Destino
    ) -> some View {
        NavigationLink {
            Empujada { destino() }
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

/// Lo que la galeria empuja encima de si misma.
///
/// Las pantallas traen su propia cabecera, asi que la barra de navegacion del
/// sistema se esconde: dos titulos uno sobre otro quedan fatal. El precio es
/// que se va con ella el boton de volver, y sin el te quedas encerrado con el
/// gesto de deslizar como unica salida, que nadie adivina. Asi que la galeria
/// pone el suyo, flotando abajo a la izquierda para no chocar con el titular.
private struct Empujada<Contenido: View>: View {
    @Environment(\.dismiss) private var volver
    @ViewBuilder let contenido: Contenido

    var body: some View {
        contenido
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .overlay(alignment: .bottomLeading) {
                Button { volver() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.redondo)
                    .padding(Espacio.margen)
                    .accessibilityLabel(Text("Volver al muestrario"))
            }
    }
}

#Preview("Galeria") {
    GaleriaDeDiseno().preferredColorScheme(.dark)
}
