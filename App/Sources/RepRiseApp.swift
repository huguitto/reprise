import SwiftUI
import AlarmCore
import ChallengeKit
import AlarmScheduler
import DesignSystem
import Persistence

@main
struct RepRiseApp: App {
    /// El plan contratado. Sale antes que las alarmas porque ellas lo
    /// necesitan: es quien decide cuantas pueden estar encendidas.
    @State private var plan = ModeloDelPlan()
    /// El almacen se monta una sola vez, aqui, y de el cuelga todo lo que se
    /// guarda. `Persistence.contenedor` avisa de que construir dos revienta.
    @State private var modeloDeAlarmas: ModeloDeAlarmas

    init() {
        let plan = ModeloDelPlan()
        self._plan = State(initialValue: plan)
        self._modeloDeAlarmas = State(initialValue: ModeloDeAlarmas(
            repositorio: Self.almacenDeAlarmas(),
            programador: Self.programador(),
            plan: plan
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(modeloDeAlarmas: modeloDeAlarmas, plan: plan)
        }
    }

    /// Quien pone las alarmas en el sistema.
    ///
    /// Es `PreviewAlarmScheduler` y no `SystemAlarmScheduler` **a proposito**:
    /// AlarmKit exige un entitlement que Apple aprueba caso por caso y que
    /// todavia no tenemos. Con el de preview la app entera funciona —se ponen,
    /// se apagan y se borran alarmas, y el modelo lleva la cuenta de cuales
    /// estan puestas— pero **no suena nada a la hora**: no hay alarma de verdad
    /// en el sistema.
    ///
    /// El dia que llegue el entitlement esto es una linea: `SystemAlarmScheduler()`.
    private static func programador() -> any AlarmScheduling {
        PreviewAlarmScheduler()
    }

    /// El almacen de disco, o uno que falla siempre si no se puede abrir.
    ///
    /// Lo que **no** se hace aqui es caer a un almacen de memoria que finja que
    /// todo va bien: el usuario pondria su alarma, la veria en la lista, se iria
    /// a dormir y no sonaria. Con `AlmacenRoto` cada intento devuelve error y la
    /// lista lo dice en pantalla, que es feo pero es verdad.
    private static func almacenDeAlarmas() -> any AlarmRepository {
        do {
            return try Persistence.almacen()
        } catch {
            return AlmacenRoto()
        }
    }
}

/// El sustituto cuando no se puede abrir el fichero de SwiftData. No guarda
/// nada y no lo disimula.
private struct AlmacenRoto: AlarmRepository {
    struct NoHayAlmacen: Error {}

    func all() async throws -> [Alarm] { throw NoHayAlmacen() }
    func save(_ alarm: Alarm) async throws { throw NoHayAlmacen() }
    func delete(id: Alarm.ID) async throws { throw NoHayAlmacen() }
}

/// La raiz de la app.
///
/// En Release es la app y nada mas. En desarrollo lleva colgada ademas la
/// calibracion de sentadillas, que es la unica forma de llegar a esa herramienta
/// desde un iPhone de verdad.
struct RootView: View {
    let modeloDeAlarmas: ModeloDeAlarmas
    let plan: ModeloDelPlan

    var body: some View {
        #if DEBUG
        RaizConHerramientas(modeloDeAlarmas: modeloDeAlarmas, plan: plan)
        #else
        AppSola(modeloDeAlarmas: modeloDeAlarmas, plan: plan)
        #endif
    }
}

/// La navegacion de tres secciones, siempre en oscuro: exactamente lo que se
/// instala en el telefono de un usuario.
///
/// Lo que se ve al abrir ya es la forma final —Alarmas, Racha y Ranking abajo,
/// Ajustes y Pro en hoja—. **Las alarmas ya son de verdad**: se crean, se
/// editan, se borran y sobreviven a cerrar la app, contra `Persistence`. Racha
/// y ranking siguen con datos de mentira.
///
/// Lo que todavia NO pasa: **no suena nada a la hora**. El ciclo entero de
/// programar y cancelar esta puesto y funcionando, pero contra
/// `PreviewAlarmScheduler`, que lleva la cuenta en memoria y no pone ninguna
/// alarma en iOS. Falta el entitlement de AlarmKit; ver `RepRiseApp.programador()`.
///
/// Falta una cosa que no se puede montar desde aqui: **el reto no se alcanza**.
/// No es un olvido, es que no se visita a voluntad — aparece cuando suena la
/// alarma, y quien lo arranca es AlarmScheduler. Hasta entonces se mira desde
/// el muestrario, en Ajustes > Sistema de diseno.
struct AppSola: View {
    let modeloDeAlarmas: ModeloDeAlarmas
    let plan: ModeloDelPlan

    var body: some View {
        NavegacionPrincipal(modeloDeAlarmas: modeloDeAlarmas, plan: plan)
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
    let modeloDeAlarmas: ModeloDeAlarmas
    let plan: ModeloDelPlan

    var body: some View {
        TabView {
            Tab("App", systemImage: "alarm") {
                AppSola(modeloDeAlarmas: modeloDeAlarmas, plan: plan)
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
