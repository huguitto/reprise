import SwiftUI
import AlarmCore
import AlarmScheduler

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Elegir el tono de una alarma.
///
/// Es la pantalla que faltaba. Todo el camino del tono estaba montado desde el
/// principio —`Alarm.toneID` se guarda, `ToneRegistry` lo recuerda,
/// `SystemAlarmScheduler` se lo pasa a la alerta de AlarmKit y `ChallengeSound`
/// lo sostiene durante el reto— y no habia forma de llegar a el: la fila "Tono"
/// de la hoja de alarma tenia su galon de "sigue por aqui" y no seguia a
/// ninguna parte, y el nombre que ensenaba salia de `DatosDeMentira`, asi que
/// podia decir "Amanecer" de una alarma que iba a sonar con el pitido del
/// sistema.
///
/// Dos reglas que no son de estilo:
///
///   - **El catalogo es el de verdad** (`ToneCatalog`), no el inventado. Si un
///     fichero no llegase al bundle, `tonoEfectivo` cae al sonido del sistema y
///     aqui se dice, en vez de ofrecer un tono que no va a sonar.
///   - **Se puede escuchar antes de elegir.** Un tono de alarma que se elige a
///     ciegas se descubre a las seis y media de la manana, que es el peor
///     momento posible para enterarse de que no te gusta.
public struct PantallaTonos: View {
    @Environment(\.dismiss) private var cerrar

    /// El tono elegido. Se escribe en cuanto se toca: esta pantalla no tiene
    /// boton de guardar, igual que no lo tiene elegir un dia de la semana.
    @Binding private var toneID: String

    /// El plan, para saber que se puede elegir y para poder contratar Pro sin
    /// salir de aqui. `nil` = la pantalla se mira suelta y se pinta como gratis.
    private let plan: ModeloDelPlan?

    @State private var muroDePago = false
    @State private var sonando: String?
    @State private var reproductor = ReproductorDeMuestra()

    public init(toneID: Binding<String>, plan: ModeloDelPlan? = nil) {
        self._toneID = toneID
        self.plan = plan
    }

    private var esPro: Bool { plan?.esPro ?? false }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("Tono", subtitulo: "de la alarma") {
                    Button { cerrar() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Cerrar"))
                }

                seccion("Siempre disponible") {
                    Bloque {
                        fila(ToneCatalog.sistema)
                    }
                }

                if !ToneCatalog.delBundle.isEmpty {
                    seccion("De RepRise") {
                        Bloque {
                            ForEach(Array(ToneCatalog.delBundle.enumerated()), id: \.element.id) { indice, tono in
                                if indice > 0 { Raya() }
                                fila(tono)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Espacio.corto) {
                    Text("iOS no deja usar tus tonos.")
                        .font(Tipografia.pieFuerte)
                        .foregroundStyle(Paleta.texto)
                    Text("Ni los de fábrica ni los que te hayas comprado: solo el sonido de alarma del sistema y los que vengan dentro de la app. No es una decisión nuestra.")
                        .font(Tipografia.pie)
                        .foregroundStyle(Paleta.textoSuave)
                }
                .padding(Espacio.normal)
                .hueco(.sutil, radio: Radio.medio)
                .padding(.horizontal, Espacio.margen)
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
        .onDisappear { reproductor.parar() }
        .sheet(isPresented: $muroDePago) {
            PantallaMuroDePago { plan?.contratarPro() }
        }
    }

    // MARK: - Una fila

    @ViewBuilder
    private func fila(_ tono: Tone) -> some View {
        let bloqueado = tono.isPro && !esPro
        let elegido = tono.id == toneID
        let falta = faltaSuFichero(tono)

        Button {
            if bloqueado {
                muroDePago = true
            } else if !falta {
                toneID = tono.id
                escuchar(tono)
            }
        } label: {
            FilaDeAjuste(
                icono: elegido ? "checkmark.circle.fill" : "circle",
                titulo: tono.nombre,
                detalle: detalle(de: tono, bloqueado: bloqueado, falta: falta)
            ) {
                if bloqueado {
                    Pastilla("Pro", acentuada: true)
                } else if !falta {
                    // El altavoz es de la fila entera, no un boton aparte: un
                    // segundo objetivo tocable de 20 puntos al lado de otro es
                    // como se acaba eligiendo un tono al querer escucharlo.
                    Image(systemName: sonando == tono.id ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(sonando == tono.id ? Paleta.acento : Paleta.textoTenue)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(falta)
        .accessibilityAddTraits(elegido ? [.isSelected] : [])
    }

    private func detalle(de tono: Tone, bloqueado: Bool, falta: Bool) -> String? {
        if falta { return "No ha llegado a la app: sonaría el del sistema" }
        if bloqueado { return "Con Pro" }
        if tono.fileName == nil { return "El sonido de alarma de iOS" }
        return nil
    }

    /// Un tono declarado cuyo fichero no esta en el bundle. No deberia pasar
    /// —hay un test que lo caza antes— pero si pasa, se dice en vez de dejar
    /// elegir algo que sonaria distinto.
    private func faltaSuFichero(_ tono: Tone) -> Bool {
        guard let fileName = tono.fileName else { return false }
        return ToneCatalog.url(deFichero: fileName) == nil
    }

    private func escuchar(_ tono: Tone) {
        guard let fileName = tono.fileName,
              let url = ToneCatalog.url(deFichero: fileName)
        else {
            // El del sistema no es un fichero nuestro y no se puede muestrear.
            sonando = nil
            reproductor.parar()
            return
        }
        sonando = tono.id
        reproductor.tocar(url) { sonando = nil }
    }

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

/// La muestra de un tono: unos segundos y para.
///
/// No es el sonido de la alarma —eso lo lleva `ChallengeSound`, en
/// `AlarmScheduler`, y sostiene el tono en bucle contra el modo silencio—. Esto
/// es lo contrario: suena bajito, respeta el interruptor de silencio del movil y
/// se corta solo. Elegir un tono no es despertarse.
@MainActor
@Observable
final class ReproductorDeMuestra {
    /// Cuanto dura la muestra. Suficiente para reconocer el tono y no tanto
    /// como para tener que buscar la forma de callarlo.
    private static let segundos: TimeInterval = 4

    #if canImport(AVFoundation)
    private var reproductor: AVAudioPlayer?
    #endif
    private var corte: Task<Void, Never>?

    func tocar(_ url: URL, alTerminar: @escaping @MainActor () -> Void) {
        parar()
        #if canImport(AVFoundation)
        guard let nuevo = try? AVAudioPlayer(contentsOf: url) else { return }
        nuevo.volume = 0.7
        nuevo.play()
        reproductor = nuevo
        #endif
        corte = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.segundos))
            guard !Task.isCancelled else { return }
            self?.parar()
            alTerminar()
        }
    }

    func parar() {
        corte?.cancel()
        corte = nil
        #if canImport(AVFoundation)
        reproductor?.stop()
        reproductor = nil
        #endif
    }
}

#Preview("Tonos · gratis") {
    PantallaTonos(toneID: .constant(Tone.defaultID)).preferredColorScheme(.dark)
}

#Preview("Tonos · Pro") {
    PantallaTonos(toneID: .constant("campana"), plan: .deMentira).preferredColorScheme(.dark)
}
