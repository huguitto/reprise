import SwiftUI
import AlarmCore
import AlarmScheduler

/// Ajustes. Corto a proposito: cada opcion que se anade es una decision que el
/// usuario tiene que tomar a cambio de nada.
public struct PantallaAjustes: View {
    /// Las dos preferencias de la alarma nueva. Van a disco —de ahi el
    /// `@AppStorage`— y las lee `PantallaEditarAlarma` al crear. Eran dos
    /// `@State` que se olvidaban al cerrar la hoja y no llegaban a ninguna
    /// alarma: se movian, se veian moverse y no hacian nada.
    ///
    /// El reto se guarda por su `rawValue` porque `@AppStorage` no admite
    /// enumeraciones sin mas; `retoPorDefecto` lo traduce en las dos
    /// direcciones para que la pantalla siga hablando de `ChallengeType`.
    @AppStorage(PreferenciasDeAlarma.claveDelReto) private var retoCrudo = ChallengeType.pasos.rawValue
    @AppStorage(PreferenciasDeAlarma.claveDelTono) private var tonoPorDefecto = Tone.defaultID
    /// La hoja abierta encima de Ajustes.
    ///
    /// Una sola `@State` y una sola `.sheet` para cinco destinos: con cinco
    /// banderas sueltas nada impide que dos se pongan a `true` a la vez, y
    /// entonces cual sale depende del orden en que esten escritos los
    /// modificadores. Con un destino unico, ese estado imposible no se puede
    /// ni representar.
    @State private var hoja: Hoja?
    @Environment(\.dismiss) private var cerrar
    /// El plan de verdad. `nil` = la pantalla se esta mirando suelta (galeria,
    /// `#Preview`) y se pinta como plan gratis.
    private let plan: ModeloDelPlan?

    public init(plan: ModeloDelPlan? = nil) {
        self.plan = plan
    }

    private var esPro: Bool { plan?.esPro ?? false }

    private var retoPorDefecto: Binding<ChallengeType> {
        Binding(
            get: { ChallengeType(rawValue: retoCrudo) ?? .pasos },
            set: { retoCrudo = $0.rawValue }
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("Ajustes") {
                    Button { cerrar() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Cerrar"))
                }

                if !esPro {
                    Button { hoja = .pro } label: { tarjetaDePro }
                        .buttonStyle(.plain)
                } else if let plan {
                    // Andamio, no funcion: hasta que entre StoreKit no hay
                    // gestion de suscripcion de verdad, y hace falta poder
                    // volver a gratis para probar que al dejar de pagar no se
                    // borra nada. Se va el dia que entren las compras.
                    Bloque {
                        FilaDeAjuste(icono: "checkmark.seal", titulo: "RepRise Pro",
                                     detalle: "Activo (sin cobro: falta StoreKit)") {
                            Button("Volver a gratis") { plan.volverAGratis() }
                                .buttonStyle(.textoMenudo)
                        }
                    }
                    .padding(.horizontal, Espacio.margen)
                }

                seccion("Cuenta") {
                    // Sin galon y apagada, no con un galon que no lleva a
                    // ningun sitio: la cuenta va con el ranking de verdad, y el
                    // ranking de verdad va en otra rama. Ensenar "Entrar" como
                    // si se pudiera entrar es prometer una pantalla que no
                    // existe; ensenarla apagada y con el motivo es decir la
                    // verdad y quedarse el sitio hecho.
                    Bloque {
                        FilaDeAjuste(icono: "person.crop.circle", titulo: "Entrar",
                                     detalle: "Todavía no: el ranking aún no es de verdad") {
                            Pastilla("Pronto")
                        }
                        .opacity(0.55)
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
                        // El detalle sale del catalogo, no escrito a mano: aqui
                        // ponia "Amanecer" siempre, tuviera el usuario el tono
                        // que tuviera.
                        Button { hoja = .tonos } label: {
                            FilaDeAjuste(icono: "speaker.wave.2", titulo: "Tono por defecto",
                                         detalle: ToneCatalog.tonoEfectivo(id: tonoPorDefecto).nombre) { chevron }
                        }
                        .buttonStyle(.plain)
                        Raya()
                        FilaApilada(icono: retoPorDefecto.wrappedValue.simbolo, titulo: "Reto por defecto") {
                            SelectorSegmentado(
                                opciones: ChallengeType.allCases,
                                seleccion: retoPorDefecto
                            ) { $0 == .pasos ? "20 pasos" : "10 sentadillas" }
                        }
                    }
                    Text("Es lo que trae puesto una alarma nueva. Cada alarma se puede cambiar por su cuenta.")
                        .font(Tipografia.pie)
                        .foregroundStyle(Paleta.textoTenue)
                        .padding(.horizontal, Espacio.mini)
                }

                seccion("La app") {
                    Bloque {
                        Button { hoja = .racha } label: {
                            FilaDeAjuste(icono: "questionmark.circle", titulo: "Cómo funciona la racha") { chevron }
                        }
                        .buttonStyle(.plain)
                        Raya()
                        // Un `mailto:` y no un formulario: no hay servidor al
                        // que mandar nada, y el correo del movil si existe. Si
                        // el aparato no tiene cliente de correo no se pinta la
                        // fila, en vez de pintar un boton que no abre nada.
                        if let correo = Self.correo {
                            Link(destination: correo) {
                                FilaDeAjuste(icono: "envelope", titulo: "Escribirnos",
                                             detalle: Self.buzon) { chevron }
                            }
                            .buttonStyle(.plain)
                            Raya()
                        }
                        Button { hoja = .condiciones } label: {
                            FilaDeAjuste(icono: "doc.text", titulo: "Privacidad y condiciones") { chevron }
                        }
                        .buttonStyle(.plain)
                        Raya()
                        FilaDeAjuste(icono: "info.circle", titulo: "Versión", detalle: Self.version)
                    }
                }

                // Puerta de servicio: el muestrario del sistema de diseno, para
                // poder mirar las piezas en el movil de verdad. Se ira cuando
                // la app este montada del todo.
                seccion("Para el equipo") {
                    Bloque {
                        Button { hoja = .galeria } label: {
                            FilaDeAjuste(icono: "swatchpalette", titulo: "Sistema de diseño",
                                         detalle: "Pantallas y piezas") { chevron }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
        .sheet(item: $hoja) { cual in
            switch cual {
            case .pro: PantallaMuroDePago { plan?.contratarPro() }
            case .tonos: PantallaTonos(toneID: $tonoPorDefecto, plan: plan)
            case .racha: PantallaComoFuncionaLaRacha()
            case .condiciones: PantallaCondiciones()
            case .galeria: GaleriaDeDiseno()
            }
        }
    }

    private enum Hoja: String, Identifiable {
        case pro, tonos, racha, condiciones, galeria

        var id: String { rawValue }
    }

    /// El buzon de soporte. En un sitio con nombre porque lo ensena la fila y
    /// lo usa el enlace, y dos copias a mano acaban siendo dos direcciones.
    static let buzon = "hola@reprise.app"
    static let correo = URL(string: "mailto:\(buzon)?subject=RepRise")

    /// La version, leida del bundle. Estaba escrita "1.0 (1)" a mano, asi que
    /// la primera actualizacion habria seguido diciendo 1.0 desde Ajustes.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let corta = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let compilacion = info?["CFBundleVersion"] as? String ?? "1"
        return "\(corta) (\(compilacion))"
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

#Preview("Ajustes") {
    PantallaAjustes().preferredColorScheme(.dark)
}
