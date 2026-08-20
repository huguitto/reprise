import Foundation

/// El motor de rachas. Funciones puras, sin fechas del sistema ni almacenamiento:
/// todo lo que necesita entra por parametro.
///
/// Esta es la pieza donde un error no se puede deshacer — una racha de 200 dias
/// borrada por un fallo de calculo no se recupera y el usuario no vuelve. Por eso
/// es el unico paquete con tests obligatorios y por eso no depende de nada.
public enum StreakEngine {

    /// Repone las vidas si `day` cae en un mes distinto al de la ultima
    /// reposicion, y las recorta al tope del plan aunque no toque reponer.
    ///
    /// Se llama antes de resolver cualquier dia, no en un temporizador de fin de
    /// mes: asi funciona igual si el usuario tiene la app cerrada tres semanas.
    ///
    /// El recorte de fuera del mes existe por la suscripcion caducada. Si solo
    /// se mirase el plan al reponer, quien deja de pagar un dia 3 se quedaria
    /// las vidas de ese mes hasta el dia 1 siguiente, y las vidas son de Pro.
    public static func refillingLives(
        _ state: StreakState,
        on day: Day,
        plan: PlanDeSuscripcion
    ) -> StreakState {
        var next = state
        if next.livesRefilledYearMonth != day.yearMonth {
            next.livesRemaining = plan.limites.vidasAlMes
            next.livesRefilledYearMonth = day.yearMonth
        }
        next.livesRemaining = min(next.livesRemaining, plan.limites.vidasAlMes)
        return next
    }

    /// Ajusta las vidas cuando el plan cambia a mitad de mes. Se llama desde el
    /// borde, cuando StoreKit avisa de una compra o de una caducidad.
    ///
    /// Al comprar Pro las vidas del mes se conceden en el acto: quien acaba de
    /// pagar por ellas no espera al dia 1. Al caducar se recortan, por lo mismo
    /// que explica `refillingLives`.
    ///
    /// Nota: subir y bajar de plan dentro del mismo mes vuelve a conceder las
    /// vidas. Es un agujero conocido y se deja abierto — el antifraude esta
    /// descartado por decision de producto, y aqui el fraude cuesta una
    /// suscripcion de verdad.
    public static func changingPlan(
        _ state: StreakState,
        from anterior: PlanDeSuscripcion,
        to nuevo: PlanDeSuscripcion,
        on day: Day
    ) -> StreakState {
        guard anterior != nuevo else { return state }
        var next = state
        let tope = nuevo.limites.vidasAlMes

        if tope > anterior.limites.vidasAlMes {
            next.livesRemaining = tope
            next.livesRefilledYearMonth = day.yearMonth
        } else {
            next.livesRemaining = min(next.livesRemaining, tope)
        }
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
        to state: StreakState,
        plan: PlanDeSuscripcion
    ) -> (state: StreakState, record: DayRecord) {
        var next = refillingLives(state, on: day, plan: plan)

        // Idempotencia: si el dia ya se conto, no lo contamos otra vez. Sin esto,
        // un reintento de sincronizacion o un relanzamiento de la app duplicaria
        // la racha o gastaria una vida de mas.
        if let last = next.lastCountedDay, last >= day {
            // Se devuelve `state`, el de entrada, y no `next`: si el dia que
            // llega es de un mes anterior, `next` trae una reposicion de vidas
            // con el sello del mes viejo, y quedarsela devolveria vidas ya
            // gastadas. El recorte por plan caducado no se pierde: entra en la
            // primera resolucion de verdad, y en el acto si es StoreKit quien
            // avisa, via `changingPlan`.
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
