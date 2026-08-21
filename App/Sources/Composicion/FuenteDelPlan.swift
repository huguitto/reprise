import Foundation
import AlarmCore

/// De donde sale el plan del usuario.
///
/// **Esto es una costura, no una implementacion.** StoreKit todavia no existe en
/// el proyecto, y la racha no puede esperarlo: el plan decide si hay vidas, y
/// sin plan no se puede ni pintar la pantalla ni resolver un dia. Asi que hasta
/// que llegue StoreKit el plan se lee de `UserDefaults`, con `gratis` por
/// defecto, que es la verdad de cualquiera que instale la app hoy.
///
/// El dia que entre StoreKit se cambia el cuerpo de `actual()` por la consulta
/// de verdad y no se toca nada mas: `ResolutorDeDia` ya recibe el plan como
/// cierre —se lee en el momento de resolver, no al arrancar— justo para que una
/// compra o una caducidad a media manana no reparta vidas que ya no existen.
struct FuenteDelPlan: Sendable {
    /// Clave con nombre feo a proposito: que se vea que es provisional al
    /// mirar el fichero de preferencias.
    ///
    /// - Important: `DesignSystem.ModeloDelPlan` **escribe en esta misma clave**.
    ///   Es quien la cambia cuando el usuario contrata Pro desde el muro de
    ///   pago; esto solo lee. Si alguien toca el nombre aqui, hay que tocarlo
    ///   alli: no hay compilador que lo cace, porque `DesignSystem` no ve esta
    ///   capa.
    static let clave = "plan-provisional-sin-storekit"

    /// Se guarda el nombre del contenedor y no el `UserDefaults`, que no es
    /// `Sendable`. Resolverlo en cada llamada no cuesta nada —`UserDefaults`
    /// cachea— y deja que esto viaje al cierre que lee el plan al resolver un
    /// dia, que es desde donde hace falta.
    private let suite: String?

    init(suite: String? = nil) {
        self.suite = suite
    }

    private var defaults: UserDefaults {
        suite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func actual() -> PlanDeSuscripcion {
        guard let bruto = defaults.string(forKey: Self.clave),
              let plan = PlanDeSuscripcion(rawValue: bruto)
        else { return .gratis }
        return plan
    }

    /// Para poder mirar la pantalla con los dos planes desde un test o desde la
    /// linea de comandos. En la app quien cambia el plan es `ModeloDelPlan`
    /// —el muro de pago y la fila de Ajustes—, contra esta misma clave.
    func fijar(_ plan: PlanDeSuscripcion) {
        defaults.set(plan.rawValue, forKey: Self.clave)
    }
}
