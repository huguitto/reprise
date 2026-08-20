import Foundation
import AlarmCore

#if canImport(AVFoundation)
import AVFoundation
#endif

/// El catalogo de tonos de la app.
///
/// Solo puede haber dos cosas: el sonido de alarma por defecto del sistema y
/// ficheros que enviemos dentro del bundle. iOS no da acceso a los tonos del
/// usuario, ni a los de fabrica ni a los suyos, y AlarmKit corta cualquier
/// fichero que pase de 30 segundos.
public enum ToneCatalog {
    /// Limite duro de AlarmKit. No es un consejo: un fichero mas largo se corta.
    public static let duracionMaxima: TimeInterval = 30

    /// El sonido de alarma del sistema. Siempre disponible y siempre gratis: es
    /// la red de seguridad cuando cualquier otra cosa falla.
    public static let sistema = Tone(
        id: Tone.defaultID,
        nombre: "Alarma del sistema",
        fileName: nil,
        isPro: false
    )

    /// Tonos propios que viajan en el bundle.
    ///
    /// Vacio a proposito: todavia no hay ni un fichero de audio en el repo.
    /// Anadir uno son dos pasos y ninguno toca codigo de nadie mas: dejar el
    /// fichero en `App/Resources` (maximo 30 s, `.caf` o `.wav`) y anadir aqui
    /// su `Tone`. Todo lo demas —busqueda, validacion, reserva Pro y respaldo—
    /// ya funciona.
    public static let delBundle: [Tone] = []

    public static var todos: [Tone] { [sistema] + delBundle }
    public static var gratis: [Tone] { todos.filter { !$0.isPro } }
    public static var pro: [Tone] { todos.filter(\.isPro) }

    /// Busca un tono por id. Devuelve `nil` si no existe.
    public static func tono(id: String) -> Tone? {
        todos.first { $0.id == id }
    }

    /// El tono con el que se va a sonar de verdad.
    ///
    /// Nunca falla: si el id no existe, o el fichero no ha llegado al bundle,
    /// se cae al sonido del sistema. Un problema de catalogo puede dejarte sin
    /// tu tono favorito; jamas sin despertador.
    public static func tonoEfectivo(id: String, en bundle: Bundle = .main) -> Tone {
        guard let tono = tono(id: id) else { return sistema }
        guard let fileName = tono.fileName else { return tono }
        return url(deFichero: fileName, en: bundle) == nil ? sistema : tono
    }

    /// URL del fichero de un tono dentro del bundle, si esta.
    public static func url(deFichero fileName: String, en bundle: Bundle = .main) -> URL? {
        let nombre = (fileName as NSString).deletingPathExtension
        let extensionDeFichero = (fileName as NSString).pathExtension
        return bundle.url(
            forResource: nombre,
            withExtension: extensionDeFichero.isEmpty ? nil : extensionDeFichero
        )
    }

    /// Lo que le pasa al catalogo dentro de un bundle concreto.
    public enum Problema: Sendable, Hashable {
        case ficheroQueFalta(toneID: String, fileName: String)
        case demasiadoLargo(toneID: String, segundos: TimeInterval)
        case idRepetido(String)

        public var mensaje: String {
            switch self {
            case let .ficheroQueFalta(toneID, fileName):
                "El tono '\(toneID)' apunta a '\(fileName)' y ese fichero no está en el bundle."
            case let .demasiadoLargo(toneID, segundos):
                "El tono '\(toneID)' dura \(String(format: "%.1f", segundos)) s y AlarmKit corta a los 30."
            case let .idRepetido(id):
                "Hay dos tonos con el id '\(id)'."
            }
        }
    }

    /// Revisa el catalogo contra un bundle. Pensado para un test en
    /// dispositivo: es la unica forma de enterarse de que un tono pasa de 30
    /// segundos antes de que se lo encuentre un usuario a las siete de la
    /// manana.
    public static func problemas(en bundle: Bundle = .main) async -> [Problema] {
        var problemas: [Problema] = []
        var vistos: Set<String> = []

        for tono in todos {
            if !vistos.insert(tono.id).inserted {
                problemas.append(.idRepetido(tono.id))
            }
            guard let fileName = tono.fileName else { continue }
            guard let url = url(deFichero: fileName, en: bundle) else {
                problemas.append(.ficheroQueFalta(toneID: tono.id, fileName: fileName))
                continue
            }
            if let segundos = await duracion(de: url), segundos > duracionMaxima {
                problemas.append(.demasiadoLargo(toneID: tono.id, segundos: segundos))
            }
        }
        return problemas
    }

    private static func duracion(de url: URL) async -> TimeInterval? {
        #if canImport(AVFoundation)
        let asset = AVURLAsset(url: url)
        guard let duracion = try? await asset.load(.duration) else { return nil }
        return CMTimeGetSeconds(duracion)
        #else
        return nil
        #endif
    }
}
