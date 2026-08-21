import AppIntents
import AlarmScheduler

/// AppIntents no descubre por su cuenta los intents que viven en un paquete:
/// el target de la app tiene que declararlos suyos.
///
/// Sin esto, `OpenChallengeIntent` —el boton "Hacer el reto" de la alerta de la
/// alarma— puede no llegar a ejecutarse, y entonces no hay recado en el buzon y
/// la app abre por la lista de alarmas como si no hubiera sonado nada. Lo pide
/// el README de `AlarmScheduler` en su paso 2 y no estaba puesto.
struct RepRiseAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [AlarmSchedulerAppIntents.self]
    }
}
