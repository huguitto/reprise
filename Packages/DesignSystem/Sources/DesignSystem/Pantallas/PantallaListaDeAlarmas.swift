import SwiftUI
import AlarmCore

/// Lista de alarmas. Es la pantalla que se ve de dia, con calma, y por eso es
/// donde el neumorfismo puede lucirse.
///
/// La proxima alarma sale como objeto — la esfera de la referencia — y el resto
/// como filas. Una sola alarma grande y las demas pequenas: la que importa a
/// las once de la noche es la de manana.
public struct PantallaListaDeAlarmas: View {
    /// Las alarmas de verdad. Quien lo construye decide contra que disco
    /// escribe: la app le pasa `Persistence`, los `#Preview` uno de memoria.
    @State private var modelo: ModeloDeAlarmas
    @State private var creandoAlarma = false
    @State private var alarmaEnEdicion: Alarm?
    /// El muro de pago, cuando el plan corta desde la propia lista: encender
    /// una segunda alarma con el interruptor no pasa por la hoja de edicion.
    @State private var muroDePago: MotivoDelMuro?

    /// Que hacer cuando se toca la tira de racha. Lo pone la navegacion, que es
    /// la unica que sabe cambiar de seccion; suelta, la pantalla no navega y su
    /// `#Preview` sigue funcionando.
    private let alIrARacha: (() -> Void)?

    /// El plan, para poder contratar Pro desde el muro y para pasarselo a la
    /// hoja de edicion.
    private let plan: ModeloDelPlan?

    /// La racha que ensena la tira. Es el mismo dato que pinta `PantallaRacha`,
    /// y por eso entra por parametro en vez de leerse de `DatosDeMentira`: dos
    /// lecturas distintas del mismo numero acaban ensenando dos numeros.
    private let racha: DatosDeRacha

    public init(
        modelo: ModeloDeAlarmas? = nil,
        plan: ModeloDelPlan? = nil,
        racha: DatosDeRacha = .deMentira,
        alIrARacha: (() -> Void)? = nil
    ) {
        self._modelo = State(initialValue: modelo ?? .deMentira())
        self.plan = plan
        self.racha = racha
        self.alIrARacha = alIrARacha
    }

    /// Lo que se pinta es lo que va a sonar, no lo que hay en disco. Con el
    /// plan gratis pueden no coincidir: quien tuvo Pro conserva sus cinco
    /// alarmas guardadas pero solo le suena una. Ensenar las cinco encendidas
    /// seria prometer cuatro despertares que no van a existir.
    private var alarmas: [Alarm] { modelo.efectivas }

    private var proxima: Alarm? { alarmas.first(where: \.isEnabled) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("Alarmas", subtitulo: subtituloDeCabecera) {
                    Button { creandoAlarma = true } label: { Image(systemName: "plus") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Nueva alarma"))
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

                Button { alIrARacha?() } label: {
                    TiraDeRacha(racha: racha.racha, vidas: racha.vidas)
                }
                .buttonStyle(.plain)
                .disabled(alIrARacha == nil)
                .padding(.horizontal, Espacio.margen)

                VStack(alignment: .leading, spacing: Espacio.medio) {
                    Text("Todas").estiloRotulo()
                        .padding(.horizontal, Espacio.margen + Espacio.mini)

                    VStack(spacing: Espacio.medio) {
                        if alarmas.isEmpty && !modelo.cargando {
                            Text("Todavía no hay ninguna. Toca + para poner la primera.")
                                .font(Tipografia.pie)
                                .foregroundStyle(Paleta.textoSuave)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, Espacio.normal)
                        }
                        ForEach(alarmas) { alarma in
                            FilaDeAlarma(alarma: alarma) {
                                alarmaEnEdicion = alarma
                            } alCambiarEncendido: { encendido in
                                Task {
                                    let resultado = await modelo.cambiarEncendido(
                                        id: alarma.id, a: encendido
                                    )
                                    if case let .loImpideElPlan(motivo) = resultado {
                                        muroDePago = MotivoDelMuro(motivo)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Espacio.margen)
                }

                // El permiso va primero de los tres avisos: sin el no suena
                // nada, y da igual lo bien configurado que este lo demas.
                if let avisoDePermiso = modelo.avisoDePermiso {
                    Text(avisoDePermiso)
                        .font(Tipografia.pieFuerte)
                        .foregroundStyle(Paleta.acento)
                        .padding(.horizontal, Espacio.margen)
                }

                if let fallo = modelo.fallo {
                    Text(fallo)
                        .font(Tipografia.pie)
                        .foregroundStyle(Paleta.acento)
                        .padding(.horizontal, Espacio.margen)
                }

                if modelo.elPlanRecortaAlgo {
                    // Una alarma que sale apagada sola sin que nadie la haya
                    // tocado es de las cosas que mas desconcierta. Se dice.
                    Text("Tu plan no da para todo lo que tienes guardado: lo que sobra sale apagado, pero no se ha borrado nada.")
                        .font(Tipografia.pie)
                        .foregroundStyle(Paleta.textoSuave)
                        .padding(.horizontal, Espacio.margen)
                } else if let plan, !plan.esPro {
                    Text("Con la versión gratis solo puede quedar una alarma activa.")
                        .font(Tipografia.pie)
                        .foregroundStyle(Paleta.textoTenue)
                        .padding(.horizontal, Espacio.margen)
                }
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
        .task { await modelo.cargar() }
        .sheet(isPresented: $creandoAlarma) {
            PantallaEditarAlarma(esNueva: true, plan: plan) { nueva in
                await modelo.guardar(nueva)
            }
        }
        .sheet(item: $alarmaEnEdicion) { alarma in
            // Se edita lo **guardado**, no lo efectivo: si el plan le esta
            // recortando los dias, al abrirla tiene que ver los que puso, y no
            // un hueco en blanco que al guardar se los borraria de disco.
            PantallaEditarAlarma(alarma: guardada(alarma), plan: plan) { editada in
                await modelo.guardar(editada)
            } alEliminar: { id in
                await modelo.eliminar(id: id)
            }
        }
        .sheet(item: $muroDePago) { muro in
            PantallaMuroDePago(motivo: muro.restriccion) {
                plan?.contratarPro()
            }
        }
    }

    /// La version guardada de una alarma que se ve recortada por el plan.
    private func guardada(_ alarma: Alarm) -> Alarm {
        modelo.alarmas.first { $0.id == alarma.id } ?? alarma
    }

    private var subtituloDeCabecera: String {
        if modelo.cargando { return "Un momento" }
        guard let proxima else { return "Ninguna puesta" }
        return String(format: "Mañana a las %d:%02d", proxima.hour, proxima.minute)
    }
}

/// Fila de una alarma: la hora en matriz pequena, el contexto debajo y el
/// interruptor a la derecha.
private struct FilaDeAlarma: View {
    let alarma: Alarm
    let alEditar: () -> Void
    let alCambiarEncendido: (Bool) -> Void

    var body: some View {
        HStack(spacing: Espacio.normal) {
            // Solo esta mitad abre la edicion. El interruptor es de la fila
            // pero no de este gesto: apagar una alarma sin entrar en ella es
            // lo que mas se hace, y no puede costar dos pasos.
            editable {
            TextoDeMatriz(
                String(format: "%02d:%02d", alarma.hour, alarma.minute),
                altura: 22,
                // Apagada va en gris medio, no en el gris de "esto ni se lee":
                // la hora es justo el dato que hace falta para decidir si se
                // vuelve a encender. Quien dice que esta apagada es el
                // interruptor, que no deja lugar a dudas.
                color: alarma.isEnabled ? Paleta.texto : Paleta.textoSuave
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(alarma.label.isEmpty ? alarma.challenge.nombre : alarma.label)
                    .font(Tipografia.pieFuerte)
                    .foregroundStyle(alarma.isEnabled ? Paleta.texto : Paleta.textoSuave)
                    .lineLimit(1)
                Text(alarma.weekdays.resumen)
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            }

            Spacer(minLength: Espacio.corto)

            // El interruptor escribe en disco, no en una copia local: por eso
            // pide el cambio en vez de mutar un `Binding`. La fila no se pinta
            // encendida hasta que el almacen lo confirma.
            Interruptor(encendido: alarma.isEnabled, alCambiar: alCambiarEncendido)
        }
        .padding(.horizontal, Espacio.normal)
        .padding(.vertical, Espacio.normal)
        .relieve(.bajo, radio: Radio.medio)
    }

    /// Junta lo que abre la edicion en un solo objetivo tocable.
    @ViewBuilder
    private func editable<Contenido: View>(@ViewBuilder _ contenido: () -> Contenido) -> some View {
        HStack(spacing: Espacio.normal) { contenido() }
            .contentShape(Rectangle())
            .onTapGesture(perform: alEditar)
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

#Preview("Lista de alarmas") {
    PantallaListaDeAlarmas().preferredColorScheme(.dark)
}
