import Foundation
import AlarmCore

#if canImport(CoreMotion)
import CoreMotion

/// Cuenta los 20 pasos con `CMPedometer`.
///
/// TAREA DEL AGENTE C. Notas de partida:
/// - `CMPedometer.startUpdates(from:)` da pasos en vivo; HealthKit no sirve
///   porque llega con retraso de minutos.
/// - El contador arranca en el instante en que empieza el reto, no antes: los
///   pasos que la persona diera antes de abrir la app no cuentan.
/// - `isStalled` a los 8 segundos sin pasos nuevos.
/// - Objetivo de anti-trampas: que agitar el movil sentado en la cama no cuele.
///   No hace falta que sea infalible, decision explicita de producto.
public actor StepDetector: ChallengeDetector {
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
