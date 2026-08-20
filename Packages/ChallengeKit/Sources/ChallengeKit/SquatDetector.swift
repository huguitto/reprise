import Foundation
import AlarmCore

#if canImport(CoreMotion)
import CoreMotion

/// Cuenta las 10 sentadillas con el movil en la mano, via `CMDeviceMotion`.
///
/// TAREA DEL AGENTE C, y la mas dificil del proyecto. Notas de partida:
/// - La senal util es la aceleracion vertical del usuario mas el cambio de
///   altura relativa; una sentadilla es bajar y volver a subir, no un pico.
/// - Cuenta la repeticion al COMPLETAR la subida, no al bajar.
/// - Hace falta un minimo de recorrido y de tiempo por repeticion para que
///   sacudir el brazo no cuente.
/// - Construye la herramienta de calibracion antes que el detector: sin poder
///   grabar sentadillas reales y mirar la senal, esto es adivinar.
public actor SquatDetector: ChallengeDetector {
    public let goal: Int
    public nonisolated let progress: AsyncStream<ChallengeProgress>

    public init(goal: Int) {
        self.goal = goal
        self.progress = AsyncStream { _ in }
        fatalError("Sin implementar — agente C")
    }

    public func start() async throws {}
    public func stop() async {}
}
#endif
