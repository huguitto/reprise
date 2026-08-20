import Foundation

public struct Alarm: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = UUID

    public var id: ID
    public var hour: Int
    public var minute: Int
    /// Vacio = alarma de un solo uso, para el proximo dia que toque.
    public var weekdays: Set<Weekday>
    public var challenge: ChallengeType
    public var toneID: String
    public var label: String
    public var isEnabled: Bool

    public init(
        id: ID = UUID(),
        hour: Int,
        minute: Int,
        weekdays: Set<Weekday> = [],
        challenge: ChallengeType,
        toneID: String = Tone.defaultID,
        label: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.challenge = challenge
        self.toneID = toneID
        self.label = label
        self.isEnabled = isEnabled
    }

    public var repeats: Bool { !weekdays.isEmpty }
}

/// Catalogo de tonos. iOS no da acceso a los tonos del sistema del usuario, asi
/// que solo existen el sonido de alarma por defecto y los ficheros que enviemos
/// dentro del bundle (maximo 30 segundos cada uno, limite de AlarmKit).
public struct Tone: Identifiable, Hashable, Codable, Sendable {
    public static let defaultID = "sistema"

    public let id: String
    public let nombre: String
    /// `nil` = sonido de alarma por defecto del sistema.
    public let fileName: String?
    public let isPro: Bool

    public init(id: String, nombre: String, fileName: String?, isPro: Bool) {
        self.id = id
        self.nombre = nombre
        self.fileName = fileName
        self.isPro = isPro
    }
}
