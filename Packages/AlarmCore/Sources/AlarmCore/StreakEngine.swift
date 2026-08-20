import Foundation

/// El motor de rachas. Funciones puras, sin fechas del sistema ni almacenamiento:
/// todo lo que necesita entra por parametro.
///
/// Esta es la pieza donde un error no se puede deshacer — una racha de 200 dias
/// borrada por un fallo de calculo no se recupera y el usuario no vuelve. Por eso
/// es el unico paquete con tests obligatorios y por eso no depende de nada.
public enum StreakEngine {

    /// Repone las vidas si `day` cae en un mes distinto al de la ultima reposicion.
    ///
    /// Se llama antes de resolver cualquier dia, no en un temporizador de fin de
    /// mes: asi funciona igual si el usuario tiene la app cerrada tres semanas.
    public static func refillingLives(_ state: StreakState, on day: Day) -> StreakState {
        guard state.livesRefilledYearMonth != day.yearMonth else { return state }
        var next = state
        next.livesRemaining = StreakState.livesPerMonth
        next.livesRefilledYearMonth = day.yearMonth
        return next
    }

    /// Aplica el resultado de un dia y devuelve el estado nuevo junto al registro
    /// que hay que guardar. El registro puede diferir del resultado que entra:
    /// un `.fallado` se convierte en `.salvadoPorVida` si quedaba alguna.
    public static func apply(
        outcome: DayOutcome,
        on day: Day,
        alarmID: Alarm.ID?,
        challenge: ChallengeType?,
        duration: TimeInterval? = nil,
        to state: StreakState
    ) -> (state: StreakState, record: DayRecord) {
        var next = refillingLives(state, on: day)

        // Idempotencia: si el dia ya se conto, no lo contamos otra vez. Sin esto,
        // un reintento de sincronizacion o un relanzamiento de la app duplicaria
        // la racha o gastaria una vida de mas.
        if let last = next.lastCountedDay, last >= day {
            return (state, DayRecord(day: day, alarmID: alarmID, challenge: challenge, outcome: outcome, duration: duration))
        }

        let resolved: DayOutcome

        switch outcome {
        case .completado:
            next.current += 1
            next.best = max(next.best, next.current)
            // El acumulado de por vida solo sube aqui, y solo una vez por dia
            // gracias al corte de idempotencia de arriba.
            next.diasCompletadosTotales += 1
            resolved = .completado

        case .fallado(let reason), .salvadoPorVida(let reason):
            if next.livesRemaining > 0 {
                // Una vida congela la racha: la mantiene, no la incrementa.
                // El dia no se gana, solo se evita perderlo.
                next.livesRemaining -= 1
                resolved = .salvadoPorVida(reason)
            } else {
                next.current = 0
                resolved = .fallado(reason)
            }
        }

        next.lastCountedDay = day

        return (next, DayRecord(day: day, alarmID: alarmID, challenge: challenge, outcome: resolved, duration: duration))
    }
}
