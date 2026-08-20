import Foundation

/// El reto que hay que completar para que la alarma se calle.
///
/// La dificultad es fija por decision de producto: no se configura ni escala
/// con la racha. Los objetivos viven aqui y en ningun otro sitio.
public enum ChallengeType: String, CaseIterable, Codable, Sendable {
    case pasos
    case sentadillas

    public var goal: Int {
        switch self {
        case .pasos: 20
        case .sentadillas: 10
        }
    }

    public var nombre: String {
        switch self {
        case .pasos: "20 pasos"
        case .sentadillas: "10 sentadillas"
        }
    }
}
