import SwiftUI
import DesignSystem

@main
struct RepRiseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// La raiz de la app: la navegacion de tres secciones, siempre en oscuro.
/// Exactamente lo que se instala en el telefono de un usuario.
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
///
/// Hasta el 21 de agosto de 2026 colgaba aqui una segunda barra, visible solo en
/// DEBUG, con la calibracion de sentadillas al lado de la app. Se quito al dar
/// por cerrada la calibracion. La herramienta no se ha borrado: `CalibracionView`
/// sigue en `ChallengeKit` y se puede volver a colgar el dia que haya que medir
/// otra vez —hara falta, porque el detector se cerro con dos sesiones de las
/// cinco que pedia el encargo.
struct RootView: View {
    var body: some View {
        NavegacionPrincipal()
            .tint(DesignSystem.acento)
            // RepRise es solo oscura. La paleta ya lo es de por si, pero sin
            // esto el cromo del sistema —fondo de las hojas, barra de estado,
            // teclado— seguiria al ajuste del movil y saldria en claro.
            .preferredColorScheme(.dark)
    }
}
