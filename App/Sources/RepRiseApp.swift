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
/// **El reto ya se alcanza.** Sigue sin visitarse a voluntad —no esta en la
/// barra y no hay forma de llegar a el a mano, que ponerlo a un toque seria dar
/// la forma de saltarselo— pero cuando la alerta de la alarma deja un recado en
/// `ChallengeInbox`, esta pantalla se aparta y sale `PantallaReto` contando de
/// verdad. Ese buzon llevaba escrito desde el principio y no lo leia nadie:
/// pulsar "Hacer el reto" abria la app por la lista de alarmas y ahi se
/// acababa todo.
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

    /// El reto en curso, si lo hay. Manda sobre todo lo demas mientras dure.
    @State private var reto: ModeloDeReto?

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
                guard nueva == .active else { return }
                Task { await alVolverAlFrente() }
            }
            // El recado del boton "Hacer el reto" y el arranque de la app son
            // dos carreras distintas y no hay orden garantizado entre ellas: si
            // la app estaba muerta, `perform()` del intent puede escribir en el
            // buzon despues de que `.task` de aqui ya haya mirado. Sin esto, esa
            // manana el reto no sale y solo se arregla saliendo y volviendo a
            // entrar. `ChallengeInbox` vive en `UserDefaults`, asi que la propia
            // escritura avisa.
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                Task { await reto?.recogerElRecado() }
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
            // El reto va por delante de todo, incluso de un fallo de racha: la
            // alarma esta sonando y lo unico que la calla es terminarlo. Y va
            // *en lugar de* la navegacion, no en una hoja encima: de una hoja
            // se sale deslizando, y de aqui no se sale sin hacer el reto.
            if let reto, reto.hayReto {
                PantallaReto(
                    reto: reto.reto,
                    hechos: reto.hechos,
                    segundos: reto.segundos,
                    estado: reto.estado,
                    alApagar: { Task { await reto.apagar() } }
                )
            } else if let fallo = racha.fallo {
                AvisoDeFallo(texto: fallo)
            } else {
                // `FlujoDeEntrada` y no `NavegacionPrincipal` a pelo: la
                // presentacion estaba escrita, probada y con su bandera en
                // `UserDefaults`, y no la veia nadie porque la raiz se saltaba
                // el flujo y entraba directa a la navegacion. Quien instalaba
                // la app aterrizaba en una lista de alarmas vacia sin que nadie
                // le hubiera dicho que el boton de apagar pide veinte pasos.
                FlujoDeEntrada(racha: racha.datos, modeloDeAlarmas: alarmas, plan: plan)
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
            // Un solo programador para los dos modelos, y no uno cada uno.
            // `SystemAlarmScheduler` lleva dentro la sesion de audio que sostiene
            // el tono durante el reto: contra una instancia distinta de la que
            // lo arranco, `silenceCurrentAlarm()` no calla nada.
            let programador = Self.programador()
            alarmas = ModeloDeAlarmas(
                repositorio: almacen,
                programador: programador,
                plan: plan
            )
            let nueva = ModeloDeRacha(almacen: almacen)
            racha = nueva
            // Antes de mirar el buzon: `arrancar()` resuelve el reto huerfano de
            // la sesion anterior, y si el de hoy ya estuviera abierto lo cobraria
            // como abandonado.
            await nueva.arrancar()

            let elReto = ModeloDeReto(almacen: almacen, programador: programador, racha: nueva)
            reto = elReto
            await elReto.recogerElRecado()
        } catch {
            falloAlAbrir = "No se ha podido abrir tu racha."
        }
    }

    /// Volver del fondo con un reto a medias **no vuelve a cobrar el dia**.
    ///
    /// `arrancar()` empieza por `resolverRetoHuerfano()`, y el rastro del reto
    /// que se esta haciendo ahora mismo es, visto desde el disco, exactamente
    /// igual que el de una app que murio anoche a mitad. Sin esta guarda, mirar
    /// la hora en otra app durante el reto rompia la racha.
    private func alVolverAlFrente() async {
        if let reto, reto.hayReto { return }
        if let racha { await racha.arrancar() }
        await reto?.recogerElRecado()
    }

    /// Quien pone las alarmas en el sistema.
    ///
    /// Hasta el 21/08/2026 esto era `PreviewAlarmScheduler`, y llevaba escrito
    /// que era a proposito porque AlarmKit exigia un entitlement que Apple
    /// aprueba caso por caso. **No existe tal entitlement**, y nadie lo habia
    /// comprobado nunca: la app se monto entera sobre un programador que no
    /// suena por un bloqueante que no era. Probado contra el iPhone con la
    /// cuenta gratuita, con tres entitlements firmados y ninguno de AlarmKit:
    /// suena.
    ///
    /// En el simulador no hay alarma que dar, asi que ahi sigue entrando el de
    /// preview. Es la unica diferencia entre los dos sitios.
    private static func programador() -> any AlarmScheduling {
        #if targetEnvironment(simulator)
        PreviewAlarmScheduler()
        #else
        SystemAlarmScheduler()
        #endif
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
