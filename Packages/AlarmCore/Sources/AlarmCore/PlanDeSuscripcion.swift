import Foundation

// El plan del usuario y lo que cada plan deja hacer.
//
// Las reglas viven aqui y en ningun otro sitio. La interfaz pregunta, no
// decide: si el limite se escribiera tambien en la pantalla de alarmas, el dia
// que cambie el precio habria dos verdades y una se quedaria vieja.
//
// Este fichero NO tiene textos de usuario a proposito. El motor decide que se
// puede y que no; como se cuenta eso en pantalla es cosa del diseno, igual que
// pasa con los niveles y las insignias.

/// El plan contratado. Lo resuelve StoreKit en el borde de la app; aqui dentro
/// solo entra como dato.
public enum PlanDeSuscripcion: String, Codable, Sendable, CaseIterable {
    case gratis
    case pro

    public var esPro: Bool { self == .pro }

    public var limites: LimitesDelPlan {
        switch self {
        case .gratis:
            LimitesDelPlan(
                maximoDeAlarmasActivas: 1,
                permiteRepeticionPorDias: false,
                vidasAlMes: 0
            )
        case .pro:
            LimitesDelPlan(
                maximoDeAlarmasActivas: nil,
                permiteRepeticionPorDias: true,
                vidasAlMes: StreakState.livesPerMonth
            )
        }
    }
}

/// Lo que un plan permite. Se lee siempre desde `PlanDeSuscripcion.limites`.
public struct LimitesDelPlan: Hashable, Sendable {
    /// Alarmas que pueden estar encendidas a la vez. `nil` = sin limite.
    ///
    /// El limite es de alarmas **activas**, no de alarmas guardadas: al usuario
    /// gratis no se le borra nada, solo se le apaga lo que sobra. Asi, si un dia
    /// paga, se lo encuentra todo donde lo dejo.
    public let maximoDeAlarmasActivas: Int?
    /// Si se pueden fijar dias de la semana. Sin esto la alarma es de un solo
    /// uso: suena el proximo dia que toque y se apaga sola.
    public let permiteRepeticionPorDias: Bool
    /// Vidas que se conceden al empezar cada mes.
    public let vidasAlMes: Int

    public init(maximoDeAlarmasActivas: Int?, permiteRepeticionPorDias: Bool, vidasAlMes: Int) {
        self.maximoDeAlarmasActivas = maximoDeAlarmasActivas
        self.permiteRepeticionPorDias = permiteRepeticionPorDias
        self.vidasAlMes = vidasAlMes
    }
}

/// El motivo por el que el plan de turno no deja hacer algo. Lo devuelve
/// `PoliticaDelPlan` para que la interfaz sepa **que** muro de pago ensenar:
/// no es lo mismo topar con el limite de alarmas que con la repeticion.
public enum RestriccionDelPlan: Hashable, Sendable, Error {
    case limiteDeAlarmasActivas(maximo: Int)
    case repeticionPorDias
}

/// Las reglas del plan sobre las alarmas. Funciones puras: entra todo por
/// parametro y no se guarda nada.
///
/// Hay dos formas de aplicar un limite y las dos hacen falta, porque cubren
/// momentos distintos:
///
///   - `alGuardar` **corta antes**, cuando el usuario intenta algo que su plan
///     no cubre. Es la que ensena el muro de pago.
///   - `alarmasEfectivas` **filtra despues**, sobre lo que ya hay guardado. Es
///     la que resuelve el caso feo: el usuario tenia Pro, tenia cinco alarmas
///     de lunes a viernes, y la suscripcion ha caducado esta noche.
///
/// Sin la segunda, dejar de pagar no quitaria nada de lo comprado. Con la
/// segunda pero sin la primera, el usuario configuraria cosas que luego no
/// suenan, que es peor que no dejarle configurarlas.
public enum PoliticaDelPlan {

    /// Que impide guardar esta alarma, si es que algo lo impide. `nil` = adelante.
    ///
    /// `alarmas` son todas las que hay guardadas hoy, la propia incluida o no:
    /// se compara por `id`, asi que editar una alarma que ya estaba encendida no
    /// cuenta como encender una segunda.
    ///
    /// Encender una alarma apagada es guardarla con `isEnabled` a `true`, asi
    /// que pasa por aqui igual y no hace falta una funcion aparte.
    public static func alGuardar(
        _ alarma: Alarm,
        entre alarmas: [Alarm],
        plan: PlanDeSuscripcion
    ) -> RestriccionDelPlan? {
        let limites = plan.limites

        if alarma.repeats && !limites.permiteRepeticionPorDias {
            return .repeticionPorDias
        }

        if alarma.isEnabled, let maximo = limites.maximoDeAlarmasActivas {
            let otrasEncendidas = alarmas.filter { $0.id != alarma.id && $0.isEnabled }.count
            if otrasEncendidas + 1 > maximo {
                return .limiteDeAlarmasActivas(maximo: maximo)
            }
        }

        return nil
    }

    /// Las alarmas tal y como suenan de verdad con este plan.
    ///
    /// Nunca borra: apaga lo que pasa del limite y vacia los dias de la semana
    /// de lo que queda encendido. Lo guardado sigue intacto en disco, de modo
    /// que volver a Pro lo devuelve todo sin que el usuario tenga que
    /// reconfigurar nada.
    ///
    /// El orden importa: se conservan encendidas las primeras de la lista, asi
    /// que hay que pasarlas en el mismo orden en que las ve el usuario. Con eso
    /// la que sobrevive es la de arriba, y no una cualquiera distinta en cada
    /// arranque.
    public static func alarmasEfectivas(
        _ alarmas: [Alarm],
        plan: PlanDeSuscripcion
    ) -> [Alarm] {
        let maximo = plan.limites.maximoDeAlarmasActivas
        var encendidas = 0

        return alarmas.map { alarma in
            var ajustada = alarma
            if ajustada.isEnabled {
                if let maximo, encendidas >= maximo {
                    ajustada.isEnabled = false
                } else {
                    encendidas += 1
                }
            }
            return efectiva(ajustada, plan: plan)
        }
    }

    /// Una alarma tal y como suena con este plan, sin mirar a las demas.
    ///
    /// Hoy solo quita la repeticion por dias: sin ella la alarma es de un solo
    /// uso, que es justamente lo que le queda al plan gratis.
    public static func efectiva(_ alarma: Alarm, plan: PlanDeSuscripcion) -> Alarm {
        guard !plan.limites.permiteRepeticionPorDias, alarma.repeats else { return alarma }
        var ajustada = alarma
        ajustada.weekdays = []
        return ajustada
    }
}
