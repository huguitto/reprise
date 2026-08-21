import Foundation

/// El almacen que necesita `ResolutorDeDia`, con la unica garantia que el motor
/// de rachas no puede darse a si mismo: **la escritura es atomica**.
///
/// Existe aparte de `StreakRepository` y `DayRecordRepository` (los de
/// `Contracts.swift`) porque esos dos guardan por separado, y por separado no
/// vale: si se escribe el registro del dia pero no el estado, el dia queda
/// contado en el historial y no en la racha; si se escribe el estado pero no el
/// registro, la racha avanza sobre un dia que no existe. Las dos mitades tienen
/// que caer juntas o no caer.
///
/// Quien lo implemente (hoy `Persistence`, con SwiftData) debe escribir las tres
/// cosas de `confirmarDia` en una sola transaccion y deshacerla entera si algo
/// falla a mitad.
public protocol AlmacenDeRachas: Sendable {
    func rachaActual() async throws -> StreakState
    func retoPendiente() async throws -> PendingChallenge?

    /// Guarda el estado, guarda el registro del dia y borra el rastro del reto
    /// pendiente. Las tres, o ninguna.
    ///
    /// El borrado del rastro va aqui dentro y no en una llamada aparte por el
    /// mismo motivo: un rastro que sobrevive a su propio dia resuelto haria que
    /// el siguiente arranque penalizara otra vez.
    ///
    /// `registro` es `nil` cuando el dia ya estaba contado. Entonces no hay nada
    /// que escribir en el historial —el dia ya tiene el suyo y pisarlo lo
    /// falsearia— pero el rastro hay que cerrarlo igual, que es justo el caso en
    /// el que llega un `nil`.
    func confirmarDia(estado: StreakState, registro: DayRecord?) async throws
}

/// Resuelve un dia entero: coge el estado guardado, se lo pasa al motor y
/// persiste lo que sale, de una pieza.
///
/// Es un actor para que dos resoluciones simultaneas no se pisen. El caso real
/// no es teorico: al abrir la app se resuelve el reto huerfano de la sesion
/// anterior mientras el usuario ya puede estar completando el de hoy. Sin
/// serializar, las dos leerian el mismo estado de partida y una de las dos
/// escrituras se perderia.
public actor ResolutorDeDia {

    public struct Resultado: Sendable, Hashable {
        /// Lo que se guardo. Ojo: puede no coincidir con lo que entro. Un
        /// `.fallado` sale como `.salvadoPorVida` si quedaba alguna vida.
        ///
        /// `nil` si el dia ya estaba contado: entonces no se guardo registro
        /// ninguno, porque el dia ya tenia el suyo.
        public let registro: DayRecord?
        public let estadoAnterior: StreakState
        public let estado: StreakState

        public var nivel: Nivel { Niveles.nivel(de: estado) }
        public var ascenso: Nivel? { Niveles.ascenso(de: estadoAnterior, a: estado) }
        public var insigniasNuevas: Set<Insignia> { Insignias.nuevas(de: estadoAnterior, a: estado) }

        /// `true` si el dia no cambio nada porque ya estaba contado.
        public var yaEstabaContado: Bool { registro == nil }
    }

    private let almacen: any AlmacenDeRachas
    private let plan: @Sendable () async -> PlanDeSuscripcion

    /// `plan` es un cierre y no un valor por un motivo concreto: la suscripcion
    /// cambia con la app abierta — se compra, se restaura, caduca de madrugada —
    /// y un dia resuelto con un plan viejo reparte vidas que ya no existen o
    /// niega las que se acaban de pagar. Se lee en el momento de resolver.
    ///
    /// Lo cablea la app contra StoreKit. No hay valor por defecto a proposito:
    /// equivocarse aqui cuesta la racha de alguien, asi que quien llame tiene
    /// que decir de que plan habla.
    public init(
        almacen: any AlmacenDeRachas,
        plan: @escaping @Sendable () async -> PlanDeSuscripcion
    ) {
        self.almacen = almacen
        self.plan = plan
    }

    /// Aplica el resultado de un dia y lo persiste.
    ///
    /// `dia` llega ya convertido: la conversion desde `Date` ocurre una sola vez,
    /// en el borde, con el calendario del dispositivo. Aqui dentro no hay fechas.
    @discardableResult
    public func resolver(
        _ outcome: DayOutcome,
        dia: Day,
        alarmID: Alarm.ID?,
        challenge: ChallengeType?,
        duration: TimeInterval? = nil
    ) async throws -> Resultado {
        let anterior = try await almacen.rachaActual()
        let salida = StreakEngine.apply(
            outcome: outcome,
            on: dia,
            alarmID: alarmID,
            challenge: challenge,
            duration: duration,
            to: anterior,
            plan: await plan()
        )
        try await almacen.confirmarDia(estado: salida.state, registro: salida.record)
        return Resultado(registro: salida.record, estadoAnterior: anterior, estado: salida.state)
    }

    /// El reto huerfano: un rastro sin cerrar de la sesion anterior.
    ///
    /// Si esta ahi, la app murio a mitad del reto — la mataron, se reinicio el
    /// movil o se fue la bateria — y el dia se resuelve como
    /// `.fallado(.appTerminada)`. Es lo unico que impide que matar la app sea la
    /// forma trivial de saltarse el despertador, asi que se llama **al arrancar**,
    /// antes de dejar tocar nada.
    ///
    /// No distingue "lo mate para saltarme la alarma" de "se me apago el movil":
    /// es imposible desde dentro y la decision de producto es penalizar igual.
    /// Para eso estan las dos vidas del mes de Pro; en gratis no hay red.
    ///
    /// Devuelve `nil` si no habia nada pendiente, que es el caso normal.
    @discardableResult
    public func resolverRetoHuerfano() async throws -> Resultado? {
        guard let pendiente = try await almacen.retoPendiente() else { return nil }
        return try await resolver(
            .fallado(.appTerminada),
            dia: pendiente.day,
            alarmID: pendiente.alarmID,
            challenge: pendiente.challenge
        )
    }

    /// Los dias que sonaron y nadie conto, resueltos como `.fallado(.ignorada)`.
    ///
    /// Cubre el agujero que el motor no puede ver desde dentro: pulsar "Stop" en
    /// la interfaz del sistema, o no enterarse de que ha sonado, no ejecuta
    /// codigo nuestro y por tanto no le llega ningun dia al motor. Sin esto,
    /// ignorar la alarma tres mananas seguidas sale gratis y la racha sigue
    /// subiendo como si nada.
    ///
    /// Se llama **al arrancar y despues de `resolverRetoHuerfano()`**: el
    /// huerfano puede ser de un dia anterior, y resolverlo primero mueve la
    /// frontera desde la que se barre.
    ///
    /// Los dias salen en orden y se resuelven de uno en uno, cada uno con su
    /// transaccion, porque cada uno puede gastar una vida o romper la racha y el
    /// orden decide cual. Hoy no entra: todavia se puede completar.
    ///
    /// - Parameter alarmas: las **efectivas** para el plan del usuario, ya
    ///   pasadas por `PoliticaDelPlan.alarmasEfectivas`.
    @discardableResult
    public func resolverDiasPerdidos(
        hasta hoy: Day,
        alarmas: [Alarm],
        calendario: Calendar = .current
    ) async throws -> [Resultado] {
        let estado = try await almacen.rachaActual()
        let perdidos = DiasPerdidos.entre(
            ultimoContado: estado.lastCountedDay,
            y: hoy,
            alarmas: alarmas,
            calendario: calendario
        )

        var salida: [Resultado] = []
        for perdido in perdidos {
            salida.append(try await resolver(
                .fallado(.ignorada),
                dia: perdido.dia,
                alarmID: perdido.alarmID,
                challenge: perdido.challenge
            ))
        }
        return salida
    }
}
