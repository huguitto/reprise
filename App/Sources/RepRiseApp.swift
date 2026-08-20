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

/// Raiz provisional: la galeria del sistema de diseno y la calibracion de los
/// sensores, que son las dos cosas que ahora mismo hay que poder abrir en el
/// iPhone de verdad.
///
/// Todavia no hay app que montar. `AlarmScheduler` y el motor de rachas siguen
/// en sus ramas, y hasta que aterricen no existe el estado real que estas
/// pantallas tendrian que leer.
///
/// La galeria da acceso a las siete pantallas y al muestrario de piezas con
/// datos de mentira: sirve para juzgar el neumorfismo, el contraste del reto y
/// el modo oscuro donde de verdad se ven, que es en la pantalla del telefono y
/// no en un `#Preview`.
///
/// La calibracion es la herramienta del detector de sentadillas. Esta aqui
/// porque **en el simulador no hay CoreMotion**: sin poder abrirla en el iPhone
/// no hay grabaciones, y sin grabaciones los umbrales del detector se quedan en
/// una hipotesis para siempre.
///
/// Cuando los otros paquetes esten, esto pasa a ser el arranque de verdad:
/// `PantallaListaDeAlarmas` sobre el repositorio real, y la calibracion se cae o
/// se esconde detras de un ajuste de desarrollo.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Diseño", systemImage: "paintbrush") {
                GaleriaDeDiseno()
            }
            Tab("Calibración", systemImage: "waveform.path.ecg") {
                CalibracionView()
            }
        }
        .tint(DesignSystem.acento)
    }
}
