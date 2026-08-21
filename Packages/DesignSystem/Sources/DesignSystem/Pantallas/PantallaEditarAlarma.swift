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
    /// Ancho real de la regla, medido. Antes se adivinaba y la hora no salia
    /// donde apuntaba el dedo; ver `arrastreDeLaRegla`.
    @State private var anchoDeLaRegla: CGFloat = 0
    @Environment(\.dismiss) private var cerrar
    private let esNueva: Bool

    /// Que hacer con la alarma al pulsar "Guardar" y "Eliminar".
    ///
    /// Son opcionales porque la hoja tambien se abre suelta desde los
    /// `#Preview` y desde la galeria, donde no hay nada que guardar. Sueltos,
    /// los botones solo cierran, que es lo que hacian antes.
    ///
    /// `alGuardar` devuelve el resultado y no `Void` a proposito: guardar puede
    /// no salir, y la hoja **no se cierra** cuando no sale. Cerrarla y ensenar
    /// el muro de pago detras tiraria todo lo que el usuario acababa de
    /// rellenar, y al volver de pagar tendria que ponerlo otra vez.
    private let alGuardar: ((Alarm) async -> ModeloDeAlarmas.Resultado)?
    private let alEliminar: ((Alarm.ID) async -> Void)?
    /// El plan, para poder contratar Pro desde el muro sin salir de aqui.
    private let plan: ModeloDelPlan?

    /// El muro de pago abierto, con el motivo por el que se abrio.
    @State private var muroDePago: MotivoDelMuro?
    @State private var guardando = false
    @State private var errorAlGuardar: String?

    public init(
        alarma: Alarm? = nil,
        esNueva: Bool = false,
        plan: ModeloDelPlan? = nil,
        alGuardar: ((Alarm) async -> ModeloDeAlarmas.Resultado)? = nil,
        alEliminar: ((Alarm.ID) async -> Void)? = nil
    ) {
        // Una alarma nueva empieza en blanco: las siete en punto y sin dias.
        // Heredar la alarma de ejemplo confunde al que la esta creando.
        let inicial = alarma ?? (esNueva
            ? Alarm(hour: 7, minute: 0, challenge: .pasos)
            : DatosDeMentira.alarmas[0])
        self._alarma = State(initialValue: inicial)
        self.esNueva = esNueva
        self.plan = plan
        self.alGuardar = alGuardar
        self.alEliminar = alEliminar
    }

    private enum Movimiento: String, CaseIterable {
        case hora = "Hora"
        case minuto = "Minuto"
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera(esNueva ? "Nueva" : "Editar", subtitulo: "alarma") {
                    Button { cerrar() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Cerrar"))
                }

                selectorDeHora

                seccion("Se repite") {
                    VStack(alignment: .leading, spacing: Espacio.medio) {
                        SelectorDeDias(dias: $alarma.weekdays)
                        Text(alarma.weekdays.resumen)
                            .font(Tipografia.pie)
                            .foregroundStyle(Paleta.textoSuave)
                        // Avisar antes de que lo elija, no despues de que lo
                        // guarde: dejarle marcar cinco dias para luego cortarle
                        // al guardar es hacerle trabajar para nada.
                        if let plan, !plan.plan.limites.permiteRepeticionPorDias {
                            Text("Repetir en días concretos es de Pro. Sin ello suena una vez y se apaga sola.")
                                .font(Tipografia.pie)
                                .foregroundStyle(Paleta.textoTenue)
                        }
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
                    Button("Guardar", action: guardar)
                        .buttonStyle(.principal)
                        .disabled(guardando)

                    if let errorAlGuardar {
                        Text(errorAlGuardar)
                            .font(Tipografia.pie)
                            .foregroundStyle(Paleta.acento)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !esNueva {
                        Button("Eliminar la alarma") {
                            let id = alarma.id
                            Task {
                                await alEliminar?(id)
                                cerrar()
                            }
                        }
                        .buttonStyle(.texto)
                        .disabled(guardando)
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
        .sheet(item: $muroDePago) { muro in
            PantallaMuroDePago(motivo: muro.restriccion) {
                plan?.contratarPro()
            }
        }
    }

    // MARK: - Guardar

    /// Guardar es una peticion, no un hecho: puede toparse con el plan o con el
    /// disco. Solo se cierra la hoja si la alarma queda guardada de verdad.
    private func guardar() {
        guard let alGuardar else { cerrar(); return }
        guardando = true
        errorAlGuardar = nil
        let queGuardar = alarma
        Task {
            switch await alGuardar(queGuardar) {
            case .guardada:
                cerrar()
            case let .loImpideElPlan(motivo):
                muroDePago = MotivoDelMuro(motivo)
            case .noSeHaPodidoGuardar:
                errorAlGuardar = "No se ha podido guardar. Inténtalo otra vez."
            }
            guardando = false
        }
    }

    // MARK: - Hora

    private var selectorDeHora: some View {
        VStack(spacing: Espacio.amplio) {
            EsferaDeReloj(hora: alarma.hour, minuto: alarma.minute, diametro: 230)

            VStack(spacing: Espacio.normal) {
                SelectorSegmentado(opciones: Movimiento.allCases, seleccion: $moviendo) { $0.rawValue }
                    .frame(maxWidth: 220)

                ReglaHorizontal(progreso: progresoDeLaRegla)
                    .onGeometryChange(for: CGFloat.self) { medida in
                        medida.size.width
                    } action: { ancho in
                        anchoDeLaRegla = ancho
                    }
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

    /// Arrastrar sobre la regla mueve la hora o el minuto. Se calcula sobre la
    /// posicion absoluta del dedo, no sobre el desplazamiento, para que no se
    /// acumule error al arrastrar despacio.
    ///
    /// El ancho viene medido (`anchoDeLaRegla`) y no estimado. Antes se sacaba
    /// de donde habia caido el dedo la primera vez —`max(startLocation.x + 1,
    /// 300)`—, y eso hacia dos cosas raras: la hora no era la de la rayita que
    /// tocabas (en el centro salian las 13:00, no las 12:00) y el recorrido
    /// cambiaba segun por donde empezaras a arrastrar. Es el mismo ancho con el
    /// que `ReglaHorizontal` coloca su bolita, asi que ahora dedo y bolita van
    /// juntos.
    private var arrastreDeLaRegla: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesto in
                guard anchoDeLaRegla > 0 else { return }
                let fraccion = min(max(gesto.location.x / anchoDeLaRegla, 0), 1)
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
