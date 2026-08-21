import SwiftUI
import AlarmCore
import ChallengeKit
import DesignSystem

@main
struct RepRiseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// La raiz de la app.
///
/// En Release es la app y nada mas. En desarrollo lleva colgada ademas la
/// calibracion de sentadillas, que es la unica forma de llegar a esa herramienta
/// desde un iPhone de verdad.
struct RootView: View {
    var body: some View {
        #if DEBUG
        RaizConHerramientas()
        #else
        AppSola()
        #endif
    }
}

/// La navegacion de tres secciones, siempre en oscuro: exactamente lo que se
/// instala en el telefono de un usuario.
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
struct AppSola: View {
    var body: some View {
        NavegacionPrincipal()
            .tint(DesignSystem.acento)
            // RepRise es solo oscura. La paleta ya lo es de por si, pero sin
            // esto el cromo del sistema —fondo de las hojas, barra de estado,
            // teclado— seguiria al ajuste del movil y saldria en claro.
            .preferredColorScheme(.dark)
    }
}

#if DEBUG
/// La app mas la calibracion de sentadillas, solo en compilaciones de desarrollo.
///
/// La calibracion tiene que poder abrirse **en el iPhone de verdad**: en el
/// simulador no hay CoreMotion, asi que sin llegar a ella desde el telefono no
/// hay grabaciones, y sin grabaciones los umbrales del detector se quedan en una
/// hipotesis para siempre.
///
/// Va detras de `#if DEBUG` y no en la barra de la app porque la navegacion son
/// **tres secciones y ninguna mas** (Alarmas · Racha · Ranking, decidido en
/// `docs/decisiones-producto.md`). Esta pestana del sistema es andamio de
/// desarrollo, no una cuarta seccion: en Release no se compila.
///
/// Contrapartida asumida mientras dure: en desarrollo se ven **dos barras
/// apiladas**, la de vidrio del `TabView` del sistema debajo de la nuestra de
/// plastico. Es feo y es a proposito, para que no se confunda con la barra buena.
///
/// El sitio limpio para esto es un grupo "Herramientas" dentro de
/// `GaleriaDeDiseno`, que main ya movio a Ajustes > Sistema de diseno. No se hace
/// aqui porque esa pantalla vive en `DesignSystem`, que es paquete del agente D:
/// moverla es suyo. `CalibracionView()` se presenta desde cualquier sitio.
struct RaizConHerramientas: View {
    var body: some View {
        TabView {
            Tab("App", systemImage: "alarm") {
                AppSola()
            }
            Tab("Calibración", systemImage: "waveform.path.ecg") {
                CalibracionView()
            }
        }
        .tint(DesignSystem.acento)
        .preferredColorScheme(.dark)
    }
}
#endif
