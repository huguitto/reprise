import SwiftUI

/// La app por dentro: tres secciones y una barra abajo.
///
/// Lo que NO esta aqui, y es a proposito:
///
///   - **Ajustes y el muro de pago** se abren en hoja desde donde se piden, no
///     son secciones. Por eso llevan una equis y no un boton de volver.
///   - **El reto** no se visita: aparece cuando suena la alarma, y eso lo monta
///     AlarmScheduler. Hasta que exista, se mira desde la galeria.
///
/// Todo lo de dentro sigue siendo estatico y con datos inventados: aqui se
/// conecta la navegacion, no la logica.
public struct NavegacionPrincipal: View {
    @State private var seccion: Seccion

    /// La seccion de arranque es un parametro para poder mirar cada una por
    /// separado en los `#Preview` y en las capturas. La app siempre entra por
    /// alarmas: es lo que se viene a hacer.
    public init(seccion: Seccion = .alarmas) {
        self._seccion = State(initialValue: seccion)
    }

    public var body: some View {
        contenido
            // safeAreaInset y no un ZStack: asi la barra ademas *reserva* su
            // sitio, y la ultima fila de cada lista se puede leer entera en vez
            // de quedarse debajo.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BarraDeSecciones(seleccion: $seccion)
            }
            .fondoDePantalla()
            .tint(Paleta.acento)
    }

    @ViewBuilder
    private var contenido: some View {
        switch seccion {
        case .alarmas: PantallaListaDeAlarmas { seccion = .racha }
        case .racha: PantallaRacha()
        case .ranking: PantallaRanking()
        }
    }
}

#Preview("Navegación") {
    NavegacionPrincipal().preferredColorScheme(.dark)
}

#Preview("Navegación · racha") {
    NavegacionPrincipal(seccion: .racha).preferredColorScheme(.dark)
}

#Preview("Navegación · ranking") {
    NavegacionPrincipal(seccion: .ranking).preferredColorScheme(.dark)
}
