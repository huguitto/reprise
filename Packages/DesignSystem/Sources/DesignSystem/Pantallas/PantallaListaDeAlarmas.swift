import SwiftUI
import Foundation
import AlarmCore
import AlarmScheduler

/// Lista de alarmas. Es la pantalla que se ve de dia, con calma, y por eso es
/// donde el neumorfismo puede lucirse.
///
/// Las alarmas encendidas salen como objeto — la esfera de la referencia — y
/// todas las guardadas como filas. Un disco grande arriba y la lista pequena
/// debajo: lo que importa a las once de la noche es a que hora suena manana.
///
/// Cuando hay mas de una encendida, el disco se pasa con el dedo. Ver
/// `CarruselDeAlarmas`.
public struct PantallaListaDeAlarmas: View {
    /// Las alarmas de verdad. Quien lo construye decide contra que disco
    /// escribe: la app le pasa `Persistence`, los `#Preview` uno de memoria.
    @State private var modelo: ModeloDeAlarmas
    @State private var creandoAlarma = false
    @State private var alarmaEnEdicion: Alarm?
    /// La fila que tiene la papelera fuera, si hay alguna. Vive aqui y no en
    /// cada fila porque abrir una tiene que cerrar la que estuviera abierta.
    @State private var filaConPapelera: AnyHashable?
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

    /// Las que van a sonar, por hora. **No** es el orden de la lista, que va
    /// por fecha de creacion. Lo decide el modelo.
    private var activas: [Alarm] { modelo.activas }


    public var body: some View {
        // Esta pantalla ya no se desplaza entera: cabe y se queda quieta. Lo
        // unico que crece sin limite es la lista de "Todas", y es lo unico que
        // lleva `ScrollView` vertical. Lo demas —cabecera, esfera, tira de
        // racha y los avisos— tiene sitio fijo, asi que la esfera esta siempre
        // donde se dejo y los avisos no se esconden por debajo del borde.
        GeometryReader { medida in
            // Los bloques van a `normal` y no a `amplio`: los cuatro respiros
            // de esta columna son cuatro filas de la lista, y la lista es lo
            // que se venia a mirar.
            VStack(alignment: .leading, spacing: Espacio.normal) {
                Cabecera("Alarmas", subtitulo: subtituloDeCabecera) {
                    Button { creandoAlarma = true } label: { Image(systemName: "plus") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Nueva alarma"))
                }

                laEsfera(diametro: diametroDeLaEsfera(en: medida.size))

                Button { alIrARacha?() } label: {
                    TiraDeRacha(racha: racha.racha, vidas: racha.vidas)
                }
                .buttonStyle(.plain)
                .disabled(alIrARacha == nil)
                .padding(.horizontal, Espacio.margen)

                todas

                avisos
            }
            .padding(.top, Espacio.amplio)
            .padding(.bottom, Espacio.normal)
            .frame(width: medida.size.width, height: medida.size.height, alignment: .top)
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

    // MARK: - Piezas

    /// La zona del disco: el carrusel de lo que esta puesto o, si no hay nada,
    /// el reloj de la hora que es.
    ///
    /// El alto va fijado. Mientras se lee el disco no se sabe todavia si hay
    /// alarma, y sin reservarle el sitio la pantalla entera daria un salto al
    /// terminar de cargar.
    private func laEsfera(diametro: CGFloat) -> some View {
        VStack(spacing: 0) {
            if !activas.isEmpty {
                // Con una sola alarma esto es la esfera de siempre. Con varias
                // se arrastra de una a otra, y los puntos de su pie son lo que
                // cuenta de un vistazo que hay mas de una puesta. Ver
                // `CarruselDeAlarmas`.
                CarruselDeAlarmas(alarmas: activas, empezandoPor: modelo.proxima?.id,
                                  diametro: diametro)
            } else if !modelo.cargando {
                // Sin alarma que ensenar, la esfera se queda igual pero cuenta
                // la hora que es. El sitio no se deja en blanco: es el centro
                // de la pantalla, y vacio parece una app rota en vez de una app
                // sin alarmas.
                //
                // Solo cuando ya se ha leido el disco. Durante el parpadeo del
                // arranque no se sabe todavia si hay alguna, y poner "ninguna
                // alarma puesta" debajo de la esfera para tener que desdecirse
                // un instante despues es peor que esperar.
                RelojDeAhora(diametro: diametro)
                Text("Ninguna alarma puesta")
                    .font(Tipografia.cuerpoFuerte)
                    .foregroundStyle(Paleta.textoSuave)
                    .padding(.top, Espacio.medio)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: altoDeLaEsfera(diametro: diametro), alignment: .top)
    }

    /// Lo que se le reserva a la zona del disco: el disco, la frase de debajo y,
    /// solo cuando hay mas de una alarma puesta, la fila de puntos del carrusel.
    private func altoDeLaEsfera(diametro: CGFloat) -> CGFloat {
        diametro + Espacio.medio + Self.altoDeLaFrase
            + (activas.count > 1 ? Self.altoDeLosPuntos : 0)
    }

    /// Lo que ocupa la frase de debajo de la esfera, para poder reservarle el
    /// sitio antes de tener nada que escribir en ella.
    private static let altoDeLaFrase: CGFloat = 22
    /// Lo que ocupa la fila de puntos del carrusel, tocable de 34.
    private static let altoDeLosPuntos: CGFloat = 34

    /// Cuanto mide la esfera aqui.
    ///
    /// Antes eran 250 fijos y podian serlo: la pantalla se desplazaba, asi que
    /// lo que no cabia se empujaba hacia abajo. Ahora no se desplaza y la
    /// esfera le quita el sitio a la lista: cada 60 puntos de disco son una
    /// alarma menos que se ve. Baja a 230 —sigue siendo la pieza mas grande con
    /// diferencia— y encoge mas en los telefonos pequenos, donde a 250 no
    /// quedaba ni una fila entera.
    private func diametroDeLaEsfera(en tamano: CGSize) -> CGFloat {
        min(230, tamano.width - Espacio.margen * 2, max(170, tamano.height * 0.30))
    }

    /// Todas las alarmas guardadas. Es lo unico que se desplaza.
    private var todas: some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            Text("Todas").estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)

            ScrollView {
                VStack(spacing: Espacio.medio) {
                    if alarmas.isEmpty && !modelo.cargando {
                        Text("Todavía no hay ninguna. Toca + para poner la primera.")
                            .font(Tipografia.pie)
                            .foregroundStyle(Paleta.textoSuave)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Espacio.normal)
                    }
                    ForEach(alarmas) { alarma in
                        DeslizarParaBorrar(
                            id: alarma.id,
                            abierta: $filaConPapelera,
                            queSeBorra: descripcion(de: alarma)
                        ) {
                            Task { await modelo.eliminar(id: alarma.id) }
                        } contenido: {
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
                }
                .padding(.horizontal, Espacio.margen)
                // El relieve de las filas se sale de su marco: sin este respiro,
                // la sombra de la primera y la ultima se corta contra el borde
                // del ScrollView.
                .padding(.vertical, Espacio.mini)
            }
            // Con dos alarmas la lista no rebota como si hubiera algo mas
            // abajo: solo se desplaza cuando de verdad no cabe.
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// Los tres avisos, al pie y quietos. Van fuera del ScrollView a proposito:
    /// el del permiso es lo mas importante que puede haber en esta pantalla
    /// —sin el no suena nada— y no puede quedarse escondido debajo de una lista
    /// larga.
    @ViewBuilder
    private var avisos: some View {
        VStack(alignment: .leading, spacing: Espacio.corto) {
            // El permiso va primero de los tres: sin el no suena nada, y da
            // igual lo bien configurado que este lo demas.
            if let avisoDePermiso = modelo.avisoDePermiso {
                Text(avisoDePermiso)
                    .font(Tipografia.pieFuerte)
                    .foregroundStyle(Paleta.acento)
            }

            if let fallo = modelo.fallo {
                Text(fallo)
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.acento)
            }

            if modelo.elPlanRecortaAlgo {
                // Una alarma que sale apagada sola sin que nadie la haya tocado
                // es de las cosas que mas desconcierta. Se dice.
                Text("Tu plan no da para todo lo que tienes guardado: lo que sobra sale apagado, pero no se ha borrado nada.")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
            } else if let plan, !plan.esPro {
                Text("Con la versión gratis solo puede quedar una alarma activa.")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoTenue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Espacio.margen)
    }

    /// Como se nombra una alarma cuando hay que decir cual se borra. Es lo que
    /// oye quien usa VoiceOver antes de confirmar el gesto.
    private func descripcion(de alarma: Alarm) -> String {
        let hora = String(format: "%d:%02d", alarma.hour, alarma.minute)
        return alarma.label.isEmpty ? "la alarma de las \(hora)" : "\(alarma.label), \(hora)"
    }

    /// La version guardada de una alarma que se ve recortada por el plan.
    private func guardada(_ alarma: Alarm) -> Alarm {
        modelo.alarmas.first { $0.id == alarma.id } ?? alarma
    }

    /// La segunda linea del titular, cuando hay algo que decir.
    ///
    /// Dice **cuantas hay**, y solo cuando hay mas de una: la hora de cada
    /// alarma la dice ya su diapositiva, debajo de la esfera, y repetirla aqui
    /// arriba con una sola puesta era decir dos veces lo mismo en la misma
    /// pantalla. El numero, en cambio, avisa de que hay mas antes de tocar
    /// nada.
    ///
    /// Tampoco sigue al carrusel, y no es un olvido: la frase larga —"El
    /// domingo a las 9:00"— ocupa dos lineas donde la corta ocupa una, asi que
    /// cambiarla al pasar de alarma empujaba la esfera treinta puntos arriba y
    /// abajo y la pantalla entera daba un tiron en cada pase.
    private var subtituloDeCabecera: String? {
        if modelo.cargando { return "Un momento" }
        if activas.isEmpty { return "Ninguna puesta" }
        return activas.count > 1 ? "\(activas.count) puestas" : nil
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
        // Sin relieve propio: lo pone `DeslizarParaBorrar`, que es quien recorta
        // la fila al arrastrarla. Aqui dentro, la sombra se cortaria con ella.
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

/// Tres alarmas encendidas: el estado que hace girar la esfera. Es el que hay
/// que mirar para ver el pase, porque los datos de mentira de siempre solo
/// tienen dos y con dos el ida y vuelta parece un parpadeo.
#Preview("Varias alarmas activas") {
    PantallaListaDeAlarmas(
        modelo: ModeloDeAlarmas(
            repositorio: RepositorioEnMemoria(DatosDeMentira.alarmasTodasEncendidas),
            programador: PreviewAlarmScheduler(),
            plan: .deMentira,
            alarmasIniciales: DatosDeMentira.alarmasTodasEncendidas
        )
    )
    .preferredColorScheme(.dark)
}

/// La app recien instalada, sin nada guardado. Es el estado que menos se mira
/// y el primero que ve todo el mundo.
#Preview("Sin ninguna alarma") {
    PantallaListaDeAlarmas(
        modelo: ModeloDeAlarmas(
            repositorio: RepositorioEnMemoria(),
            programador: PreviewAlarmScheduler(),
            plan: .deMentira
        )
    )
    .preferredColorScheme(.dark)
}
