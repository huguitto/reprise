import Foundation
import AlarmCore

/// Estado de un reto en marcha.
public struct ChallengeProgress: Sendable, Hashable {
    public let completed: Int
    public let goal: Int
    /// `true` cuando llevamos `stallThreshold` segundos sin detectar movimiento
    /// valido. Es la senal que hace volver a sonar la alarma tras un abandono.
    public let isStalled: Bool

    public var isFinished: Bool { completed >= goal }
    public var fraction: Double { goal > 0 ? min(1, Double(completed) / Double(goal)) : 0 }

    public init(completed: Int, goal: Int, isStalled: Bool = false) {
        self.completed = completed
        self.goal = goal
        self.isStalled = isStalled
    }
}

public enum ChallengeDetectorError: Error, Sendable {
    case sensorNoDisponible
    case permisoDenegado
}

/// Contrato comun a los dos retos.
///
/// La app no sabe si detras hay un podometro, un acelerometro o un simulador:
/// arranca, escucha `progress` y espera a `isFinished`. Eso es lo que permite
/// desarrollar toda la interfaz en el simulador, donde no hay sensores.
public protocol ChallengeDetector: Actor {
    var goal: Int { get }
    /// Emite un valor por cada cambio. Termina cuando se llama a `stop()`.
    var progress: AsyncStream<ChallengeProgress> { get }

    func start() async throws
    func stop() async
}

public enum ChallengeDetectorFactory {
    /// Devuelve el detector real en dispositivo y el simulado en simulador.
    public static func make(for challenge: ChallengeType) -> any ChallengeDetector {
        #if targetEnvironment(simulator) || !canImport(CoreMotion)
        return SimulatedChallengeDetector(goal: challenge.goal)
        #else
        switch challenge {
        case .pasos: return StepDetector(goal: challenge.goal)
        case .sentadillas: return SquatDetector(goal: challenge.goal)
        }
        #endif
    }
}
