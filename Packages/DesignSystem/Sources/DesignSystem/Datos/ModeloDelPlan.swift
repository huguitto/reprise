import Foundation
import AlarmCore

/// El plan del usuario, y lo unico que sabe de el la interfaz.
///
/// Las **reglas** de cada plan no estan aqui: viven en `PlanDeSuscripcion` y
/// `PoliticaDelPlan`, dentro de `AlarmCore`. Esto solo guarda cual de los dos
/// tiene contratado y avisa cuando cambia.
///
/// - Important: **StoreKit todavia no existe.** `contratarPro()` no cobra nada:
///   marca el plan en `UserDefaults` y ya. Es un andamio para poder ejercitar
///   los limites en el telefono, no una compra. El dia que entre StoreKit, lo
///   que cambia es el cuerpo de estos dos metodos y nada mas: quien pregunta lo
///   hace siempre por `plan`.
@MainActor
@Observable
public final class ModeloDelPlan {

    public private(set) var plan: PlanDeSuscripcion

    private let defaults: UserDefaults
    private static let clave = "reprise.plan"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.plan = defaults.string(forKey: Self.clave)
            .flatMap(PlanDeSuscripcion.init(rawValue:)) ?? .gratis
    }

    public var esPro: Bool { plan.esPro }

    /// Andamio hasta StoreKit. Ver el aviso de la clase.
    public func contratarPro() {
        cambiar(a: .pro)
    }

    /// Volver a gratis. Sirve para probar la caida de plan, que es el caso que
    /// mas facil se rompe: al dejar de pagar no se borra nada, solo se apaga lo
    /// que sobra (`PoliticaDelPlan.alarmasEfectivas`).
    public func volverAGratis() {
        cambiar(a: .gratis)
    }

    private func cambiar(a nuevo: PlanDeSuscripcion) {
        guard plan != nuevo else { return }
        plan = nuevo
        defaults.set(nuevo.rawValue, forKey: Self.clave)
    }
}

extension ModeloDelPlan {
    /// El plan con el que se pintan los `#Preview` y la galeria: Pro, para que
    /// se vea todo, y en su propio cajon de `UserDefaults` para no ensuciar el
    /// del usuario. Es **una sola instancia** compartida: si cada pantalla
    /// hiciera la suya, la lista de alarmas y su pie de pagina podrian estar en
    /// planes distintos dentro de la misma previsualizacion.
    @MainActor
    public static let deMentira: ModeloDelPlan = {
        let plan = ModeloDelPlan(defaults: UserDefaults(suiteName: "reprise.previews") ?? .standard)
        plan.contratarPro()
        return plan
    }()
}

/// `RestriccionDelPlan` envuelta para poder abrir el muro con `.sheet(item:)`.
///
/// El envoltorio esta aqui y no en `AlarmCore` porque `Identifiable` lo pide
/// SwiftUI, no el dominio: el motor no tiene por que enterarse de como presenta
/// la interfaz sus hojas. El identificador es el propio motivo, que dos muros
/// abiertos por lo mismo son el mismo muro.
struct MotivoDelMuro: Identifiable, Hashable {
    let restriccion: RestriccionDelPlan
    var id: RestriccionDelPlan { restriccion }

    init(_ restriccion: RestriccionDelPlan) {
        self.restriccion = restriccion
    }
}
