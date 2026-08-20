import Foundation
import AlarmCore

// Ver la nota de `ChallengeDetectorFactory`: en macOS CoreMotion se importa pero
// `CMMotionManager` no esta disponible, asi que la guarda es el sistema.
#if os(iOS)
import CoreMotion

/// Cuenta las 10 sentadillas con el movil en la mano, via `CMDeviceMotion`.
///
/// Aqui no hay logica de conteo: toda vive en `AlgoritmoSentadillas`, que es
/// puro y no sabe de CoreMotion. Este actor solo hace de fontaneria —arrancar el
/// sensor, proyectar la vertical, vigilar el abandono— y le pasa las muestras.
///
/// Esa separacion es la que da valor a la herramienta de calibracion: lo que se
/// afina reproduciendo grabaciones es **este mismo algoritmo**, byte por byte, y
/// no una copia parecida que luego se comporte distinto en la mano.
public actor SquatDetector: ChallengeDetector {

    public let goal: Int
    public nonisolated let progress: AsyncStream<ChallengeProgress>

    private let gestor = CMMotionManager()
    private let frecuenciaHz: Double
    private var algoritmo: AlgoritmoSentadillas
    private let continuacion: AsyncStream<ChallengeProgress>.Continuation
    private var consumo: Task<Void, Never>?
    private var vigilante: Task<Void, Never>?

    private var ultimoAvance = ContinuousClock.now
    private var parado = false
    private var enMarcha = false

    public init(
        goal: Int,
        parametros: ParametrosSentadilla = .porDefecto,
        frecuenciaHz: Double = GrabadorDeMovimiento.frecuenciaPorDefecto
    ) {
        self.goal = goal
        self.frecuenciaHz = frecuenciaHz
        self.algoritmo = AlgoritmoSentadillas(parametros: parametros)
        var cont: AsyncStream<ChallengeProgress>.Continuation!
        self.progress = AsyncStream { cont = $0 }
        self.continuacion = cont
    }

    public func start() async throws {
        guard !enMarcha else { return }
        guard gestor.isDeviceMotionAvailable else {
            throw ChallengeDetectorError.sensorNoDisponible
        }

        enMarcha = true
        algoritmo.reinicia()
        ultimoAvance = .now
        parado = false

        // `CMDeviceMotion` no es Sendable: del callback solo salen numeros, ya
        // empaquetados en una muestra que si lo es.
        let (flujo, continuacionDeMuestras) = AsyncStream.makeStream(of: MuestraDeMovimiento.self)

        let cola = OperationQueue()
        cola.maxConcurrentOperationCount = 1
        cola.qualityOfService = .userInitiated

        gestor.deviceMotionUpdateInterval = 1 / frecuenciaHz
        // `xArbitraryZVertical` no necesita la brujula, asi que arranca al
        // instante. Da igual hacia donde mire el movil: lo unico que se usa es
        // `gravity`, y eso lo da cualquier marco de referencia.
        gestor.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: cola) { movimiento, _ in
            guard let m = movimiento else { return }
            continuacionDeMuestras.yield(
                MuestraDeMovimiento(
                    t: m.timestamp,
                    ax: m.userAcceleration.x, ay: m.userAcceleration.y, az: m.userAcceleration.z,
                    gx: m.gravity.x, gy: m.gravity.y, gz: m.gravity.z
                )
            )
        }

        consumo = Task { [weak self] in
            for await muestra in flujo {
                await self?.procesa(muestra)
            }
        }
        vigilante = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Inactividad.periodoDeRevision)
                await self?.revisaInactividad()
            }
        }

        continuacion.yield(ChallengeProgress(completed: 0, goal: goal))
    }

    public func stop() async {
        guard enMarcha else { return }
        enMarcha = false
        gestor.stopDeviceMotionUpdates()
        consumo?.cancel(); consumo = nil
        vigilante?.cancel(); vigilante = nil
        continuacion.finish()
    }

    private func procesa(_ muestra: MuestraDeMovimiento) {
        guard enMarcha else { return }
        let salida = algoritmo.procesa(
            t: muestra.t,
            aceleracionVertical: muestra.aceleracionVertical
        )

        // Solo la repeticion cerrada cuenta como movimiento valido. Que la senal
        // se mueva no basta: si asi fuera, agitar el movil aplazaria el abandono
        // para siempre sin haber hecho una sola sentadilla.
        guard salida.repeticionCompletada else { return }
        ultimoAvance = .now
        parado = false
        emite()

        if algoritmo.repeticiones >= goal { gestor.stopDeviceMotionUpdates() }
    }

    private func revisaInactividad() {
        guard enMarcha, algoritmo.repeticiones < goal else { return }
        let inactivo = ultimoAvance.duration(to: .now) >= Inactividad.umbral
        guard inactivo != parado else { return }
        parado = inactivo
        emite()
    }

    private func emite() {
        continuacion.yield(
            ChallengeProgress(
                completed: min(goal, algoritmo.repeticiones),
                goal: goal,
                isStalled: parado
            )
        )
    }
}
#endif
