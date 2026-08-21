import SwiftUI
import AlarmCore
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
/// **La racha ya no es de mentira.** Sale de SwiftData, pasa por `AlarmCore` y
/// se pinta: lo que se ve en la pantalla de racha es lo que hay en el disco.
/// Las alarmas y el ranking siguen siendo estaticos —el programador de alarmas y
/// la red van en otras ramas— y por eso la lista de alarmas todavia no guarda
/// nada. Ojo con lo que eso implica: hasta que guarde, `AlarmRepository.all()`
/// devuelve vacio y el barrido de dias perdidos no tiene calendario contra el
/// que comparar. El codigo esta puesto y probado; le falta que le lleguen
/// alarmas de verdad.
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
    /// El almacen se monta una sola vez, al arrancar. Si no se puede abrir —el
    /// disco lleno, una migracion que revienta— la app no puede ensenar ninguna
    /// racha, y lo dice en vez de pintar un cero: un cero es indistinguible de
    /// haber perdido una racha de 200 dias.
    @State private var modelo: ModeloDeRacha?
    @State private var falloAlAbrir: String?

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
                guard nueva == .active, let modelo else { return }
                Task { await modelo.arrancar() }
            }
    }

    @ViewBuilder
    private var contenido: some View {
        if let modelo {
            if let fallo = modelo.fallo {
                AvisoDeFallo(texto: fallo)
            } else {
                NavegacionPrincipal(racha: modelo.datos)
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
        guard modelo == nil, falloAlAbrir == nil else { return }
        do {
            let nuevo = ModeloDeRacha(almacen: try Persistence.almacen())
            modelo = nuevo
            await nuevo.arrancar()
        } catch {
            falloAlAbrir = "No se ha podido abrir tu racha."
        }
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
