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
/// Ni la racha ni las alarmas son ya estaticas: las dos entran por parametro y
/// las monta la app leyendo del mismo disco. El ranking sigue inventado.
public struct NavegacionPrincipal: View {
    @State private var seccion: Seccion

    /// El estado de racha de verdad. Por defecto, el de mentira, para que los
    /// `#Preview` y la galeria de diseno sigan funcionando sueltos.
    private let racha: DatosDeRacha

    /// El modelo vive aqui y no en la lista para que cambiar de seccion y
    /// volver no relea el disco ni pierda lo que hubiera en pantalla.
    @State private var modeloDeAlarmas: ModeloDeAlarmas
    @State private var plan: ModeloDelPlan

    /// La seccion de arranque es un parametro para poder mirar cada una por
    /// separado en los `#Preview` y en las capturas. La app siempre entra por
    /// alarmas: es lo que se viene a hacer.
    ///
    /// `modeloDeAlarmas` a `nil` = alarmas de mentira en memoria, que es lo que
    /// quieren los `#Preview`. La app pasa el que escribe en disco.
    public init(
        seccion: Seccion = .alarmas,
        racha: DatosDeRacha = .deMentira,
        modeloDeAlarmas: ModeloDeAlarmas? = nil,
        plan: ModeloDelPlan? = nil
    ) {
        self._seccion = State(initialValue: seccion)
        self.racha = racha
        self._modeloDeAlarmas = State(initialValue: modeloDeAlarmas ?? .deMentira())
        self._plan = State(initialValue: plan ?? .deMentira)
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
        case .alarmas:
            PantallaListaDeAlarmas(
                modelo: modeloDeAlarmas,
                plan: plan,
                racha: racha,
                alIrARacha: { seccion = .racha }
            )
        case .racha: PantallaRacha(datos: racha, plan: plan)
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
