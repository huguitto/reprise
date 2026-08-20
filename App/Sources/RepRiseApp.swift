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

/// Raiz provisional: la galeria del sistema de diseno.
///
/// Todavia no hay app que montar. `AlarmScheduler`, `ChallengeKit` y el motor
/// de rachas estan en marcha en otras ramas, y hasta que aterricen no existe el
/// estado real que estas pantallas tendrian que leer.
///
/// Mientras tanto la raiz abre `GaleriaDeDiseno`, que da acceso a las siete
/// pantallas y al muestrario de piezas con datos de mentira. Sirve para lo
/// unico que hace falta ahora: instalar en el iPhone y juzgar el neumorfismo,
/// el contraste del reto y el modo oscuro donde de verdad se ven, que es en la
/// pantalla del telefono y no en un `#Preview`.
///
/// Cuando los otros paquetes esten, esto pasa a ser el arranque de verdad:
/// `PantallaListaDeAlarmas` sobre el repositorio real.
struct RootView: View {
    var body: some View {
        GaleriaDeDiseno()
            .tint(DesignSystem.acento)
    }
}
