import SwiftUI

/// Las tres secciones que se alcanzan desde la barra de abajo.
///
/// Solo estas tres. Ajustes y el muro de pago se abren encima, en hoja, y por
/// eso llevan una equis en vez de estar aqui. El reto no es una seccion: es lo
/// que se come la pantalla cuando suena la alarma, y no se visita a voluntad.
public enum Seccion: String, CaseIterable, Identifiable, Sendable {
    case alarmas
    case racha
    case ranking

    public var id: String { rawValue }

    public var titulo: String {
        switch self {
        case .alarmas: "Alarmas"
        case .racha: "Racha"
        case .ranking: "Ranking"
        }
    }

    public var icono: String {
        switch self {
        case .alarmas: "alarm.fill"
        case .racha: "flame.fill"
        case .ranking: "list.number"
        }
    }
}

/// Barra de secciones: una capsula en relieve flotando sobre el fondo, con la
/// seccion activa hundida dentro.
///
/// No se usa la barra del `TabView` del sistema, y no es capricho: en iOS 26 es
/// de vidrio, y aqui todo es un objeto de plastico mate con la luz clavada
/// arriba a la izquierda. Una pieza de vidrio en la parte de abajo rompe la
/// ilusion, que es lo unico que sostiene este diseno.
public struct BarraDeSecciones: View {
    @Binding private var seleccion: Seccion
    @Namespace private var pozo

    public init(seleccion: Binding<Seccion>) {
        self._seleccion = seleccion
    }

    public var body: some View {
        HStack(spacing: Espacio.mini) {
            ForEach(Seccion.allCases) { seccion in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { seleccion = seccion }
                } label: {
                    boton(seccion)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(seccion.titulo))
                .accessibilityAddTraits(seccion == seleccion ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(Espacio.corto)
        .relieve(.medio, forma: Capsule(), color: Paleta.superficieAlta)
        .padding(.horizontal, Espacio.margen)
        .padding(.bottom, Espacio.corto)
        .background {
            // La capsula flota, asi que por sus lados y por debajo se ve la
            // lista pasando. Un velo del color del fondo lo tapa, y va
            // desvanecido hacia arriba para que la barra no traiga un canto
            // duro cruzando la pantalla.
            // El velo tiene que estar opaco del todo antes de llegar al canto
            // de la capsula: si no, lo que se cuela por el costado es justo lo
            // que mas canta, un interruptor encendido en modo oscuro.
            LinearGradient(
                stops: [
                    .init(color: Paleta.fondo.opacity(0), location: 0),
                    .init(color: Paleta.fondo, location: 0.35),
                    .init(color: Paleta.fondo, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.top, -Espacio.enorme)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }

    private func boton(_ seccion: Seccion) -> some View {
        let activa = seccion == seleccion
        return VStack(spacing: Espacio.mini) {
            Image(systemName: seccion.icono)
                .font(.system(size: 17, weight: .semibold))
            Text(seccion.titulo)
                .font(Tipografia.pieFuerte)
        }
        .foregroundStyle(activa ? Paleta.acento : Paleta.textoSuave)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Espacio.medio)
        .background {
            // El pozo viaja de una seccion a otra en vez de aparecer y
            // desaparecer: la barra parece una pieza con una corredera, no tres
            // botones independientes.
            if activa {
                Capsule()
                    .fill(
                        Paleta.hueco
                            .shadow(.inner(color: Paleta.sombra, radius: Hundido.sutil.difuminado,
                                           x: Hundido.sutil.desplazamiento, y: Hundido.sutil.desplazamiento))
                            .shadow(.inner(color: Paleta.luz, radius: Hundido.sutil.difuminado,
                                           x: -Hundido.sutil.desplazamiento, y: -Hundido.sutil.desplazamiento))
                    )
                    .matchedGeometryEffect(id: "pozo", in: pozo)
            }
        }
        .contentShape(Capsule())
    }
}

struct MuestraDeBarra: View {
    @State private var seccion: Seccion = .alarmas

    var body: some View {
        VStack {
            Spacer()
            BarraDeSecciones(seleccion: $seccion)
        }
        .fondoDePantalla()
    }
}

#Preview("Barra de secciones · claro") {
    MuestraDeBarra()
}

#Preview("Barra de secciones · oscuro") {
    MuestraDeBarra().preferredColorScheme(.dark)
}
