import SwiftUI

/// Lo que se ve al abrir la app: la presentacion y, al pulsar "Empezar" o
/// "Saltar", la app entera — `NavegacionPrincipal`, con su barra de secciones.
/// No la lista a secas: aterrizar en una pantalla sin barra deja al recien
/// llegado sin ver que hay racha y ranking, que es justo lo que le acaba de
/// prometer la tercera pagina.
///
/// Las dos salidas de la presentacion llevan al mismo sitio a proposito. La
/// diferencia entre pasarse las tres paginas y saltarselas es lo que sabe el
/// usuario, no donde acaba: si "Saltar" mandase a otro lado seria una trampa.
///
/// **La presentacion vuelve a salir en cada arranque.** Aqui no se guarda que
/// ya se ha visto porque eso es estado de verdad y vive en `Persistence`, no en
/// una vista con datos de mentira. Cuando exista, esta vista lee esa bandera y
/// se salta el paso.
public struct FlujoDeEntrada: View {
    @State private var presentacionHecha = false

    public init() {}

    public var body: some View {
        ZStack {
            if presentacionHecha {
                NavegacionPrincipal()
                    .transition(.opacity)
            } else {
                PantallaPresentacion {
                    withAnimation(.easeInOut(duration: 0.35)) { presentacionHecha = true }
                }
                .transition(.opacity)
            }
        }
    }
}

#Preview("Entrada") {
    FlujoDeEntrada().preferredColorScheme(.dark)
}
