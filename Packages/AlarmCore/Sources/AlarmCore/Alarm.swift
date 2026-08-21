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
    /// Cuando se creo. Es lo que ordena la lista de alarmas: lo ultimo que has
    /// puesto sale arriba.
    ///
    /// No se toca al editar. Una alarma se crea una vez, y si cambiarle la hora
    /// la moviera de sitio, la fila que acabas de tocar se te iria de debajo del
    /// dedo justo al guardar.
    public var creadaEn: Date

    public init(
        id: ID = UUID(),
        hour: Int,
        minute: Int,
        weekdays: Set<Weekday> = [],
        challenge: ChallengeType,
        toneID: String = Tone.defaultID,
        label: String = "",
        isEnabled: Bool = true,
        creadaEn: Date = Date()
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.challenge = challenge
        self.toneID = toneID
        self.label = label
        self.isEnabled = isEnabled
        self.creadaEn = creadaEn
    }

    public var repeats: Bool { !weekdays.isEmpty }

    /// El orden en el que se ensenan las alarmas: la ultima creada, la primera.
    ///
    /// Vive aqui y no en la pantalla porque lo tienen que compartir el almacen y
    /// la lista. Si cada uno ordenara por su cuenta, la lista se recolocaria
    /// sola al reabrir la app, que es el bug que este orden viene a evitar.
    ///
    /// El `id` desempata: dos alarmas con la misma fecha —las que vienen de un
    /// esquema viejo, o las de un test— tienen que salir siempre igual, y no
    /// segun como las devuelva el disco esa vez.
    public static func masNuevaPrimero(_ una: Alarm, _ otra: Alarm) -> Bool {
        una.creadaEn == otra.creadaEn
            ? una.id.uuidString < otra.id.uuidString
            : una.creadaEn > otra.creadaEn
    }
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
