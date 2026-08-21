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
    /// Devuelve el detector real en un iPhone de verdad y el simulado en
    /// cualquier otro sitio.
    ///
    /// La guarda es `os(iOS)` y no `canImport(CoreMotion)` porque CoreMotion se
    /// importa tambien en macOS pero con casi todo marcado como no disponible.
    /// Con `canImport`, `swift build` en el Mac —que es como corren los tests sin
    /// simulador— intentaria compilar los detectores reales y no compilaria.
    public static func make(for challenge: ChallengeType) -> any ChallengeDetector {
        #if os(iOS) && !targetEnvironment(simulator)
        switch challenge {
        case .pasos: return StepDetector(goal: challenge.goal)
        case .sentadillas: return SquatDetector(goal: challenge.goal)
        }
        #else
        return SimulatedChallengeDetector(goal: challenge.goal)
        #endif
    }
}
