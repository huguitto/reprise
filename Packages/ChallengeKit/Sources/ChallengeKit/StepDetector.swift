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
    public let goal: Int
    public nonisolated let progress: AsyncStream<ChallengeProgress>

    private let podometro = CMPedometer()
    private let continuacion: AsyncStream<ChallengeProgress>.Continuation
    private var consumo: Task<Void, Never>?
    private var vigilante: Task<Void, Never>?
    private var animador: Task<Void, Never>?

    private var contador: ContadorDePasos
    private var mostrados = 0
    private var ultimoAvance = ContinuousClock.now
    private var parado = false
    private var enMarcha = false

    public init(goal: Int) {
        self.goal = goal
        self.contador = ContadorDePasos(objetivo: goal)
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
        contador = ContadorDePasos(objetivo: goal)
        mostrados = 0
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
        animador?.cancel(); animador = nil
        continuacion.finish()
    }

    /// `numberOfSteps` es acumulado desde `desde`, no un incremento.
    private func registra(brutos: Int) {
        guard enMarcha, contador.registrar(acumulados: brutos) else { return }
        let ahora = ContinuousClock.now
        ultimoAvance = ahora
        parado = false
        animarPasosPendientes()

        if contador.terminado { podometro.stopUpdates() }
    }

    /// Core Motion agrupa varios pasos en cada callback. El dato se conserva
    /// tal cual, pero se presenta de uno en uno para que la cifra y la vibracion
    /// den feedback continuo en vez de saltar, por ejemplo, de 0 a 8.
    private func animarPasosPendientes() {
        guard animador == nil else { return }
        animador = Task { [weak self] in
            await self?.mostrarPasosPendientes()
        }
    }

    private func mostrarPasosPendientes() async {
        defer { animador = nil }

        while enMarcha, mostrados < contador.contados, !Task.isCancelled {
            mostrados += 1
            emite()

            guard mostrados < goal else { return }
            do {
                // Algo mas rapido que un paso normal para alcanzar al dato real
                // si el podometro entrega una tanda grande, sin parecer un salto.
                try await Task.sleep(for: .milliseconds(120))
            } catch {
                return
            }
        }
    }

    private func revisaInactividad() {
        guard enMarcha, !contador.terminado else { return }
        let inactivo = ultimoAvance.duration(to: .now) >= Inactividad.umbral
        guard inactivo != parado else { return }
        parado = inactivo
        emite()
    }

    private func emite() {
        continuacion.yield(
            ChallengeProgress(completed: mostrados, goal: goal, isStalled: parado)
        )
    }
}
#endif

/// Convierte las lecturas acumuladas de `CMPedometer` en progreso del reto.
///
/// El podometro no entrega una muestra por paso: agrupa varios y puede mandar
/// tandas muy seguidas. Por eso no se puede limitar cada tanda usando el tiempo
/// entre callbacks; hacerlo descartaba pasos reales de manera permanente.
struct ContadorDePasos {
    let objetivo: Int
    private(set) var contados = 0
    private var acumuladosAnteriores = 0

    init(objetivo: Int) {
        self.objetivo = objetivo
    }

    var terminado: Bool { contados >= objetivo }

    mutating func registrar(acumulados: Int) -> Bool {
        guard acumulados > acumuladosAnteriores else { return false }
        let nuevos = acumulados - acumuladosAnteriores
        acumuladosAnteriores = acumulados
        contados = min(objetivo, contados + nuevos)
        return true
    }
}
