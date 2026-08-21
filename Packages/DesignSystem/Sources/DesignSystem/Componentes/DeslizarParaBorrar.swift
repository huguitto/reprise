import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Deslizar una fila hacia la izquierda para sacar la papelera.
///
/// No es `List` + `.swipeActions` porque aqui no hay `List`: la lista de alarmas
/// es un `VStack` dentro del `ScrollView` de la pantalla, y meterla en una
/// `List` obligaria a renunciar al relieve de las filas —la `List` pinta su
/// propio fondo de fila debajo— y a rehacer la pantalla entera alrededor.
///
/// **Y tampoco es un `DragGesture`.** Se probo, y se comia el scroll de la
/// pantalla: con el gesto puesto, arrastrar hacia abajo empezando encima de una
/// fila no movia nada, ni con `simultaneousGesture`. Empezando dos centimetros
/// mas arriba, sobre el rotulo, la pantalla bajaba sus 240 puntos. Un
/// despertador donde no se puede bajar la lista si el dedo cae encima de una
/// alarma esta roto.
///
/// Lo que hay es un `ScrollView` horizontal por fila, con la papelera de
/// segunda. El reparto entre "esto es vertical, es de la pantalla" y "esto es
/// horizontal, es de la fila" lo hacen dos scrolls anidados, que es justo lo que
/// el sistema sabe hacer bien y no hay que reinventar. De regalo viene la
/// deceleracion de verdad.
///
/// El rebote si se quita, con `SinRebote`. Lo trae puesto el `ScrollView` y
/// aqui sobra: pasado el ancho del cajon la fila seguia corriendose, el rojo se
/// despegaba del canto derecho y asomaba el fondo por detras. El arrastre tiene
/// que topar justo donde acaba de salir la papelera.
///
/// Sobre el relieve: el `ScrollView` recorta lo que lleva dentro, asi que la
/// sombra de la fila **no puede ir dentro**. Va fuera, con `relieve`, que por eso
/// se aplica despues del recorte. Al reves, la fila se quedaria plana justo al
/// empezar a arrastrarla.
public struct DeslizarParaBorrar<Contenido: View>: View {

    /// Cual de las filas de la lista tiene el cajon abierto, si es que hay
    /// alguna. Es de la lista y no de la fila a proposito: abrir una tiene que
    /// cerrar la anterior, y para eso las filas necesitan un sitio comun donde
    /// mirarse.
    @Binding private var abierta: AnyHashable?
    private let id: AnyHashable
    private let radio: CGFloat
    private let queSeBorra: String
    private let alBorrar: () -> Void
    private let contenido: Contenido

    /// El mando para cerrar esta fila desde fuera, cuando se abre otra.
    @State private var posicion = ScrollPosition(x: 0)
    /// Lo que lleva descubierto el cajon ahora mismo. Sirve para saber cuando
    /// ensenar la papelera y cuando no dejarla pulsar.
    @State private var descubierto: CGFloat = 0

    public init(
        id: some Hashable,
        abierta: Binding<AnyHashable?>,
        radio: CGFloat = Radio.medio,
        queSeBorra: String,
        alBorrar: @escaping () -> Void,
        @ViewBuilder contenido: () -> Contenido
    ) {
        self.id = AnyHashable(id)
        self._abierta = abierta
        self.radio = radio
        self.queSeBorra = queSeBorra
        self.alBorrar = alBorrar
        self.contenido = contenido()
    }

    private var estaAbierta: Bool { abierta == id }

    private var forma: RoundedRectangle {
        RoundedRectangle(cornerRadius: radio, style: .continuous)
    }

    public var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                contenido
                    .containerRelativeFrame(.horizontal)
                    // Con el cajon fuera, tocar la fila la cierra en vez de
                    // abrir la edicion. Es lo que espera cualquiera que haya
                    // deslizado sin querer: el siguiente toque deshace.
                    .overlay {
                        if estaAbierta {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { abierta = nil }
                        }
                    }

                papelera
            }
            // Dentro del contenido a proposito: `SinRebote` se cuelga del
            // `ScrollView` que tenga mas cerca por encima, y desde fuera ese
            // seria el vertical de la pantalla.
            .background { SinRebote() }
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(AjusteDelCajon())
        .scrollPosition($posicion)
        .onScrollGeometryChange(for: CGFloat.self) { geometria in
            geometria.contentOffset.x
        } action: { _, cuanto in
            descubierto = max(0, cuanto)
            if cuanto > MedidasDelCajon.umbral {
                abierta = id
            } else if estaAbierta {
                abierta = nil
            }
        }
        // Cuando se abre otra fila, esta se cierra sola.
        .onChange(of: abierta) { _, quien in
            guard quien != id, descubierto > 0 else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                posicion.scrollTo(x: 0)
            }
        }
        .clipShape(forma)
        .relieve(.bajo, radio: radio)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Eliminar \(queSeBorra)")) { alBorrar() }
    }

    private var papelera: some View {
        Button(action: borrar) {
            Image(systemName: "trash.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                // Aparece cuando ya hay hueco donde verla. Antes solo seria un
                // trozo de icono cortado asomando por el canto.
                .opacity(min(1, descubierto / MedidasDelCajon.umbral))
                .frame(width: MedidasDelCajon.ancho)
                .frame(maxHeight: .infinity)
                .background(Paleta.peligro)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Con la fila cerrada la papelera esta fuera de la pantalla, pero no
        // fuera del alcance de un toque mal puesto. Apagada mientras no se vea.
        .disabled(descubierto <= 0)
    }

    private func borrar() {
        abierta = nil
        alBorrar()
    }
}

/// Las dos medidas del cajon. Fuera de la vista porque el ajuste del scroll las
/// necesita y ese corre fuera del hilo principal.
enum MedidasDelCajon {
    /// Lo que mide el cajon abierto. Es el ancho de un objetivo tocable comodo
    /// (44) mas aire a los lados: la papelera se pulsa a ciegas, medio dormido.
    static let ancho: CGFloat = 76
    /// Pasado esto, soltar abre. Antes, se vuelve a cerrar.
    static let umbral: CGFloat = 30
}

/// Deja la fila en uno de los dos sitios que existen: cerrada del todo, o con el
/// cajon entero fuera. Sin esto se queda donde la suelte el dedo, con media
/// papelera asomando y sin decidir.
private struct AjusteDelCajon: ScrollTargetBehavior {
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        // Se mira donde ha quedado, no la velocidad: a las seis de la manana el
        // gesto es lento y torpe, y un umbral de velocidad lo dejaria sin abrir
        // la mitad de las veces.
        let pasadoElUmbral = target.rect.origin.x > MedidasDelCajon.umbral
        target.rect.origin.x = pasadoElUmbral ? MedidasDelCajon.ancho : 0
    }
}

/// Le quita el rebote al `ScrollView` de la fila.
///
/// SwiftUI no deja apagarlo por eje: `scrollBounceBehavior` decide segun el
/// tamano, y aqui el contenido siempre es mas ancho que la fila —la papelera
/// esta ahi para eso—, asi que rebota siempre. Hay que bajar al `UIScrollView`.
///
/// Fuera de iOS no hay `UIScrollView` ni hay dedo, y esto se queda en nada.
private struct SinRebote: View {
    var body: some View {
        #if canImport(UIKit)
        EnganchePlano()
        #else
        Color.clear
        #endif
    }
}

#if canImport(UIKit)

/// Una vista vacia que solo sirve para llegar al `UIScrollView` que la contiene.
private struct EnganchePlano: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { Enganche() }
    func updateUIView(_ vista: UIView, context: Context) {}

    private final class Enganche: UIView {
        /// Debil: el scroll es el padre, y guardarlo fuerte seria un ciclo.
        private weak var scroll: UIScrollView?

        override init(frame: CGRect) {
            super.init(frame: frame)
            // No es un objetivo tocable, es un cable. Que no se coma nada.
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("sin storyboards") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            var vista: UIView? = superview
            while let actual = vista, scroll == nil {
                scroll = actual as? UIScrollView
                vista = actual.superview
            }
            apagarElRebote()
        }

        /// Se repite en cada recolocacion porque UIKit puede volver a encenderlo
        /// al reconstruir la fila. Es asignar un booleano.
        override func layoutSubviews() {
            super.layoutSubviews()
            apagarElRebote()
        }

        private func apagarElRebote() {
            scroll?.bounces = false
        }
    }
}
#endif

#Preview("Deslizar para borrar") {
    MuestraDeDeslizar().preferredColorScheme(.dark)
}

struct MuestraDeDeslizar: View {
    @State private var abierta: AnyHashable?
    @State private var filas = ["06:30 · Gimnasio", "07:15 · Trabajo", "09:00 · Findes"]

    var body: some View {
        VStack(spacing: Espacio.medio) {
            ForEach(filas, id: \.self) { fila in
                DeslizarParaBorrar(id: fila, abierta: $abierta, queSeBorra: fila) {
                    filas.removeAll { $0 == fila }
                } contenido: {
                    HStack {
                        Text(fila)
                            .font(Tipografia.cuerpoFuerte)
                            .foregroundStyle(Paleta.texto)
                        Spacer()
                    }
                    .padding(Espacio.normal)
                }
            }
        }
        .padding(Espacio.margen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fondoDePantalla()
    }
}
