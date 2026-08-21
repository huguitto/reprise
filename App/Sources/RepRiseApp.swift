import SwiftUI
import AlarmCore
import AlarmScheduler
import DesignSystem
import Persistence

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
/// **Ni la racha ni las alarmas son ya de mentira.** Las dos salen de SwiftData,
/// pasan por `AlarmCore` y se pintan. El ranking sigue siendo estatico, que la
/// red va en otra rama.
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
    /// El almacen se monta una sola vez, al arrancar, y de el cuelgan **las dos**
    /// cosas que escriben en disco. No es una preferencia de estilo:
    /// `Persistence.contenedor` construye un `ModelContainer` nuevo en cada
    /// llamada, y dos contenedores sobre el mismo fichero son dos verdades
    /// distintas del mismo dato.
    ///
    /// Si no se puede abrir —el disco lleno, una migracion que revienta— la app
    /// no puede ensenar ninguna racha, y lo dice en vez de pintar un cero: un
    /// cero es indistinguible de haber perdido una racha de 200 dias. Y tampoco
    /// finge guardar alarmas: mas vale una pantalla fea que alguien que se va a
    /// dormir con una alarma que no existe.
    @State private var racha: ModeloDeRacha?
    @State private var alarmas: ModeloDeAlarmas?
    @State private var falloAlAbrir: String?

    /// El plan contratado. No necesita disco —vive en `UserDefaults` mientras no
    /// haya StoreKit— asi que se monta antes que nada y sobrevive al fallo del
    /// almacen.
    @State private var plan = ModeloDelPlan()

    @Environment(\.scenePhase) private var fase

    var body: some View {
        contenido
            .tint(DesignSystem.acento)
            // RepRise es solo oscura. La paleta ya lo es de por si, pero sin
            // esto el cromo del sistema —fondo de las hojas, barra de estado,
            // teclado— seguiria al ajuste del movil y saldria en claro.
            .preferredColorScheme(.dark)
            .task { await abrir() }
            // Al volver del fondo se vuelve a cobrar: la app pudo pasarse la
            // noche abierta y el dia ya no es el mismo.
            .onChange(of: fase) { _, nueva in
                guard nueva == .active, let racha else { return }
                Task { await racha.arrancar() }
            }
            // El plan se puede cambiar sin salir de la app —el muro de pago y
            // la fila de Ajustes— y la racha lo lleva fotografiado desde que
            // arranco. Sin esto, quien contrata Pro sigue viendo "las vidas son
            // de Pro" con los corazones vacios hasta que cierra y vuelve a
            // abrir. Es `recargar` y no `arrancar` a proposito: cambiar de plan
            // repinta lo que se ensena, no vuelve a cobrar los dias pasados.
            .onChange(of: plan.plan) { _, _ in
                guard let racha else { return }
                Task { await racha.recargar() }
            }
    }

    @ViewBuilder
    private var contenido: some View {
        if let racha, let alarmas {
            if let fallo = racha.fallo {
                AvisoDeFallo(texto: fallo)
            } else {
                NavegacionPrincipal(racha: racha.datos, modeloDeAlarmas: alarmas, plan: plan)
            }
        } else if let falloAlAbrir {
            AvisoDeFallo(texto: falloAlAbrir)
        } else {
            // Un parpadeo, no una pantalla: abrir el contenedor es cuestion de
            // milisegundos. Pintar la navegacion con una racha vacia mientras
            // tanto seria ensenar un cero que no es verdad.
            Color.clear.fondoDePantalla()
        }
    }

    private func abrir() async {
        guard racha == nil, falloAlAbrir == nil else { return }
        do {
            let almacen = try Persistence.almacen()
            alarmas = ModeloDeAlarmas(
                repositorio: almacen,
                programador: Self.programador(),
                plan: plan
            )
            let nueva = ModeloDeRacha(almacen: almacen)
            racha = nueva
            await nueva.arrancar()
        } catch {
            falloAlAbrir = "No se ha podido abrir tu racha."
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
}

/// Lo minimo para no mentir. No es una pantalla de error con diseno propio: es
/// el hueco donde iria una el dia que haya mas de un fallo que contar.
private struct AvisoDeFallo: View {
    let texto: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
            Text(texto)
            Text("Cierra la app y vuelve a abrirla. Tu racha sigue guardada.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .opacity(0.7)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoDePantalla()
    }
}
