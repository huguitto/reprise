import SwiftUI
import AlarmCore

/// La zona de la esfera cuando hay mas de una alarma encendida.
///
/// Con una sola alarma esto es la esfera de siempre, quieta, con la hora a la
/// que suena debajo. Con dos o mas se pasan con el dedo, una a una, como las
/// fotos del carrete.
///
/// El disco grande del centro es lo unico que se mira a las once de la noche, y
/// ensenaba **una sola** hora dijera lo que dijera el resto de la pantalla:
/// quien tenia puestas las 6:30 y las 7:15 veia 6:30 y se iba a dormir sin
/// enterarse de la otra. Lo que lo cuenta ahora son tres cosas a la vez —el
/// titular dice cuantas hay, los puntos de abajo dicen por cual va, y la esfera
/// se deja arrastrar—, y ninguna se mueve sola.
///
/// **Lo pasa el dedo, no un reloj.** Hubo una version que giraba sola cada tres
/// segundos; se quito a peticion del usuario. Es la diferencia entre una
/// pantalla que se lee y una que hay que perseguir.
///
/// Por dentro es un `ScrollView` horizontal con paginado y no un gesto propio,
/// y eso es lo que importa: la pieza vive dentro del `ScrollView` vertical de
/// la lista, y dos `ScrollView` cruzados se reparten el dedo solos —el de
/// arriba se queda el movimiento vertical, este el horizontal—. Un
/// `DragGesture` a mano ahi dentro le habria robado el scroll de la pantalla.
public struct CarruselDeAlarmas: View {
    /// Lo que tarda en llegar una alarma cuando se salta tocando un punto. El
    /// arrastre no lo usa: ahi manda el dedo.
    static let salto: Animation = .easeInOut(duration: 0.35)

    private let alarmas: [Alarm]
    private let diametro: CGFloat

    /// Cual esta puesta en pantalla, por `id`.
    @State private var enPantalla: Alarm.ID?

    /// - Parameters:
    ///   - alarmas: en el orden en que se pasan. `ModeloDeAlarmas.activas` las
    ///     da por hora del reloj, que es un orden que no se mueve solo.
    ///   - empezandoPor: por cual se abre. Es `proxima`, la que suena antes de
    ///     verdad, que **no** tiene por que ser la primera de la fila: a las
    ///     once de un sabado, con una alarma de diario a las 6:30 y otra del
    ///     domingo a las 9:00, la fila empieza por la de las 6:30 y la que
    ///     suena antes es la de las 9:00. Se abre por la que suena.
    ///
    ///     Solo cuenta al aparecer: despues manda el dedo, y que la esfera se
    ///     recolocara sola al dar la medianoche seria justo lo que no se
    ///     quiere.
    public init(alarmas: [Alarm], empezandoPor primera: Alarm.ID? = nil, diametro: CGFloat = 250) {
        self.alarmas = alarmas
        self.diametro = diametro
        self._enPantalla = State(initialValue: primera ?? alarmas.first?.id)
    }

    /// En que puesto va.
    ///
    /// Se deriva del `id` y no se guarda un numero: la lista cambia debajo —se
    /// borra una alarma, se apaga otra desde su interruptor— y un indice
    /// guardado apuntaria a la de al lado o a ninguna. Si el `id` ya no esta,
    /// se vuelve a la primera, que es la que suena antes.
    private var indice: Int {
        alarmas.firstIndex { $0.id == enPantalla } ?? 0
    }

    public var body: some View {
        VStack(spacing: Espacio.medio) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(alarmas) { alarma in
                        Diapositiva(alarma: alarma, diametro: diametro)
                            // Cada una ocupa el ancho entero de la pieza: es lo
                            // que hace que el paginado caiga en una alarma y no
                            // a medio camino entre dos.
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $enPantalla)
            // **El recorte del carrusel es solo de lado a lado.**
            //
            // Un `ScrollView` recorta por sus cuatro lados, y su marco aqui es
            // exactamente lo que ocupa una diapositiva. La esfera va con
            // relieve `.alto` y su sombra sale bastante mas alla del disco, asi
            // que arriba se cortaba en seco: no se leia como "le falta sombra"
            // sino como una raya recta cruzando el fondo, y la esfera se
            // quedaba plana justo en el centro de la pantalla.
            //
            // Se apaga el recorte del scroll y se pone uno propio que solo
            // corta a los lados —que es el que hace falta, para que la
            // diapositiva de al lado no asome— y deja el alcance de la sombra
            // libre por arriba y por abajo.
            //
            // Dejar aire dentro del scroll tambien lo tapaba, pero a costa de
            // separar la esfera de todo lo demas: el hueco es de mentira, y en
            // una pantalla donde el disco es lo unico que se mira, se nota.
            .scrollClipDisabled()
            .mask {
                Rectangle().padding(.vertical, -Relieve.alto.alcance)
            }
            // Con una sola no hay nada que pasar, y dejarlo suelto solo da
            // rebote al tocarlo.
            .scrollDisabled(alarmas.count < 2)

            if alarmas.count > 1 {
                Puntos(cuantos: alarmas.count, actual: indice, nombre: nombre(de:)) { destino in
                    guard alarmas.indices.contains(destino) else { return }
                    withAnimation(Self.salto) { enPantalla = alarmas[destino].id }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Como se llama una alarma cuando hay que decir a cual lleva un punto.
    private func nombre(de puesto: Int) -> String {
        guard alarmas.indices.contains(puesto) else { return "Alarma \(puesto + 1)" }
        let alarma = alarmas[puesto]
        let hora = String(format: "%d:%02d", alarma.hour, alarma.minute)
        return alarma.label.isEmpty ? "La alarma de las \(hora)" : "\(alarma.label), \(hora)"
    }
}

/// Una alarma en la zona de la esfera: el disco y, debajo, cuando suena.
///
/// Debajo del disco estaban tambien la etiqueta y las pastillas de la
/// frecuencia y el reto. Se fueron para que la pantalla quepa entera sin
/// desplazarse, y no se pierde nada: los tres datos estan en la fila de esa
/// misma alarma, ahi abajo, y enteros en la hoja de edicion. Lo que no se podia
/// ir es la hora a la que suena, que es justo lo que se viene a mirar.
private struct Diapositiva: View {
    let alarma: Alarm
    let diametro: CGFloat

    var body: some View {
        VStack(spacing: Espacio.medio) {
            EsferaDeReloj(hora: alarma.hour, minuto: alarma.minute, diametro: diametro)
            Text(alarma.cuandoSuenaEnPalabras())
                .font(Tipografia.cuerpoFuerte)
                .foregroundStyle(Paleta.texto)
                // A una linea a proposito: todas las diapositivas tienen que
                // medir lo mismo, o la pantalla pega un tiron al pasar por una
                // frase larga.
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(nombreHablado))
    }

    /// Lo que oye VoiceOver: la esfera sola dice la hora, pero no de que alarma
    /// es. La etiqueta ya no esta en pantalla y aqui si hace falta.
    private var nombreHablado: String {
        let cuando = alarma.cuandoSuenaEnPalabras()
        return alarma.label.isEmpty ? cuando : "\(alarma.label). \(cuando)"
    }
}

/// Los puntos del pie. Ademas de contar cuantas hay y por cual va, cada uno
/// salta a la suya: es la unica forma de llegar a la tercera sin arrastrar, y
/// con VoiceOver es **la** forma.
private struct Puntos: View {
    let cuantos: Int
    let actual: Int
    let nombre: (Int) -> String
    let alTocar: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<cuantos, id: \.self) { puesto in
                Button { alTocar(puesto) } label: {
                    Capsule()
                        .fill(puesto == actual ? Paleta.acento : Paleta.textoTenue)
                        .frame(width: puesto == actual ? 20 : 7, height: 7)
                        // El punto se ve de 7 puntos y se toca de 30 por 34: a
                        // tamano real no lo acierta nadie.
                        .frame(width: 30, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(nombre(puesto)))
                .accessibilityAddTraits(puesto == actual ? [.isSelected] : [])
            }
        }
        .animation(CarruselDeAlarmas.salto, value: actual)
    }
}

#Preview("Carrusel de alarmas") {
    MuestraDeCarrusel().preferredColorScheme(.dark)
}

struct MuestraDeCarrusel: View {
    private let alarmas = [
        Alarm(hour: 6, minute: 30,
              weekdays: [.lunes, .martes, .miercoles, .jueves, .viernes],
              challenge: .pasos, label: "Gimnasio", isEnabled: true),
        Alarm(hour: 7, minute: 15, weekdays: [.sabado],
              challenge: .sentadillas, label: "Correr", isEnabled: true),
        Alarm(hour: 9, minute: 0, weekdays: [.domingo],
              challenge: .pasos, label: "", isEnabled: true)
    ]

    var body: some View {
        VStack(spacing: Espacio.ancho) {
            CarruselDeAlarmas(alarmas: alarmas)
            Text("Con una sola no se arrastra")
                .font(Tipografia.pie)
                .foregroundStyle(Paleta.textoTenue)
            CarruselDeAlarmas(alarmas: [alarmas[0]], diametro: 140)
        }
        .padding(.vertical, Espacio.ancho)
        .fondoDePantalla()
    }
}
