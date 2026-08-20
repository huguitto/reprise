import Foundation
import AlarmCore

// Ver la nota de `ChallengeDetectorFactory`: en macOS CoreMotion se importa pero
// `CMPedometer` no esta disponible, asi que la guarda es el sistema.
#if os(iOS)
import CoreMotion

/// Cuenta los 20 pasos con `CMPedometer`.
///
/// El podometro vive en el coprocesador de movimiento y funciona con la pantalla
/// apagada y la app en segundo plano, que es justo lo que hace falta cuando
/// alguien echa a andar hacia el bano con el movil en la mano. HealthKit daria
/// el mismo dato pero con minutos de retraso: inservible para apagar una alarma.
public actor StepDetector: ChallengeDetector {

    /// Pasos por segundo por encima de los cuales dejamos de creernos el dato.
    ///
    /// Correr de verdad son ~3 pasos/s; 5 es un techo generoso a proposito. No
    /// pretende cazar al tramposo listo —eso es un pozo sin fondo y esta
    /// descartado por producto—, solo evitar que una sacudida rapida que el
    /// podometro interprete como zancadas resuelva el reto entero de golpe. Ante
    /// la duda afloja, porque no contarle los pasos a quien esta andando de
    /// verdad es mucho peor.
    public static let cadenciaMaxima: Double = 5

    public let goal: Int
    public nonisolated let progress: AsyncStream<ChallengeProgress>

    private let podometro = CMPedometer()
    private let continuacion: AsyncStream<ChallengeProgress>.Continuation
    private var consumo: Task<Void, Never>?
    private var vigilante: Task<Void, Never>?

    private var contados = 0
    private var brutosAnteriores = 0
    private var instanteAnterior: ContinuousClock.Instant?
    private var ultimoAvance = ContinuousClock.now
    private var parado = false
    private var enMarcha = false

    public init(goal: Int) {
        self.goal = goal
        var cont: AsyncStream<ChallengeProgress>.Continuation!
        self.progress = AsyncStream { cont = $0 }
        self.continuacion = cont
    }

    public func start() async throws {
        guard !enMarcha else { return }
        guard CMPedometer.isStepCountingAvailable() else {
            throw ChallengeDetectorError.sensorNoDisponible
        }
        switch CMPedometer.authorizationStatus() {
        case .denied, .restricted:
            throw ChallengeDetectorError.permisoDenegado
        default:
            break
        }

        enMarcha = true
        contados = 0
        brutosAnteriores = 0
        // El reloj de cadencia arranca aqui, no en la primera entrega del
        // podometro. El coprocesador entrega a rachas y la primera puede tardar
        // varios segundos: si midieramos el intervalo desde ella, esa primera
        // tanda —pasos legitimos, ya dados— se recortaria por haber llegado
        // junta. Recortarle pasos a quien esta andando es el fallo caro.
        instanteAnterior = .now
        ultimoAvance = .now
        parado = false

        // Desde *ahora*: los pasos que diera antes de que sonara la alarma no
        // cuentan. `startUpdates(from:)` acepta fechas pasadas y devolveria el
        // historico del coprocesador, que es exactamente la forma trivial de
        // saltarse el reto sin levantarse.
        let desde = Date()

        // `CMPedometerData` no es Sendable: del callback solo salen enteros.
        let (flujo, continuacionDePasos) = AsyncStream.makeStream(of: Int.self)
        podometro.startUpdates(from: desde) { datos, _ in
            guard let datos else { return }
            continuacionDePasos.yield(datos.numberOfSteps.intValue)
        }

        consumo = Task { [weak self] in
            for await brutos in flujo {
                await self?.registra(brutos: brutos)
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
        podometro.stopUpdates()
        consumo?.cancel(); consumo = nil
        vigilante?.cancel(); vigilante = nil
        continuacion.finish()
    }

    /// `numberOfSteps` es acumulado desde `desde`, no un incremento.
    private func registra(brutos: Int) {
        guard enMarcha, brutos > brutosAnteriores else { return }
        let ahora = ContinuousClock.now
        let transcurrido = (instanteAnterior ?? ahora).duration(to: ahora).ensegundos
        instanteAnterior = ahora

        let nuevos = brutos - brutosAnteriores
        brutosAnteriores = brutos

        // Medio segundo de holgura porque el podometro entrega a rachas: si la
        // primera tanda llega junta, no queremos recortarla por llegar junta.
        let tope = max(1, Int((transcurrido + 0.5) * Self.cadenciaMaxima))
        let creidos = min(nuevos, tope)
        guard creidos > 0 else { return }

        contados = min(goal, contados + creidos)
        ultimoAvance = ahora
        parado = false
        emite()

        if contados >= goal { podometro.stopUpdates() }
    }

    private func revisaInactividad() {
        guard enMarcha, contados < goal else { return }
        let inactivo = ultimoAvance.duration(to: .now) >= Inactividad.umbral
        guard inactivo != parado else { return }
        parado = inactivo
        emite()
    }

    private func emite() {
        continuacion.yield(
            ChallengeProgress(completed: contados, goal: goal, isStalled: parado)
        )
    }
}
#endif
