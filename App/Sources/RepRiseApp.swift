import SwiftUI
import AlarmCore
import DesignSystem

@main
struct RepRiseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// La raiz de la app: la navegacion de tres secciones.
///
/// Lo que se ve al abrir ya es la forma final —Alarmas, Racha y Ranking abajo,
/// Ajustes y Pro en hoja— pero por dentro todo son **datos de mentira**. El
/// motor de rachas, el programador de alarmas y los sensores estan en marcha en
/// otras ramas; cuando aterricen, estas mismas pantallas pasan a leer el estado
/// de verdad y esta raiz no tiene que cambiar de forma.
///
/// Falta una cosa que no se puede montar desde aqui: **el reto no se alcanza**.
/// No es un olvido, es que no se visita a voluntad — aparece cuando suena la
/// alarma, y quien lo arranca es AlarmScheduler. Hasta entonces se mira desde
/// el muestrario, en Ajustes > Sistema de diseno.
struct RootView: View {
    var body: some View {
        NavegacionPrincipal()
            .tint(DesignSystem.acento)
    }
}
