import Foundation

/// Detector falso para el simulador y los tests: avanza una repeticion cada
/// `interval` segundos. Sin el, ningun agente puede tocar la interfaz del reto
/// sin tener el iPhone en la mano, y solo hay un iPhone.
public actor SimulatedChallengeDetector: ChallengeDetector {
    public let goal: Int
    private let interval: Duration
    private var task: Task<Void, Never>?
    private var continuation: AsyncStream<ChallengeProgress>.Continuation?
    public nonisolated let progress: AsyncStream<ChallengeProgress>

    public init(goal: Int, interval: Duration = .milliseconds(600)) {
        self.goal = goal
        self.interval = interval
        var cont: AsyncStream<ChallengeProgress>.Continuation!
        self.progress = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    public func start() async throws {
        task = Task { [goal, interval, continuation] in
            var done = 0
            while done < goal, !Task.isCancelled {
                try? await Task.sleep(for: interval)
                done += 1
                continuation?.yield(ChallengeProgress(completed: done, goal: goal))
            }
        }
    }

    public func stop() async {
        task?.cancel()
        task = nil
        continuation?.finish()
    }
}
