import Foundation

/// Guarda y lee grabaciones en disco, como ficheros JSON sueltos.
///
/// Ficheros sueltos y no una base de datos a proposito: la grabacion tiene que
/// poder salir del iPhone y acabar en el repositorio para que `swift test` la
/// reproduzca en el Mac. Un JSON se comparte, se mira y se versiona; una fila de
/// SwiftData no.
public struct AlmacenDeGrabaciones: Sendable {

    public let carpeta: URL

    /// Por defecto, `Documentos/Grabaciones`.
    public init(carpeta: URL? = nil) {
        if let carpeta {
            self.carpeta = carpeta
        } else {
            let documentos = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.carpeta = documentos.appendingPathComponent("Grabaciones", isDirectory: true)
        }
    }

    private static var codificador: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        // Legible: estas grabaciones se acaban mirando a mano.
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private static var decodificador: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @discardableResult
    public func guarda(_ grabacion: Grabacion) throws -> URL {
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let destino = carpeta.appendingPathComponent(grabacion.nombreDeFichero)
        try Self.codificador.encode(grabacion).write(to: destino, options: .atomic)
        return destino
    }

    public func lee(_ url: URL) throws -> Grabacion {
        try Self.decodificador.decode(Grabacion.self, from: Data(contentsOf: url))
    }

    /// Todas las grabaciones de la carpeta, de la mas nueva a la mas vieja.
    /// Un fichero corrupto se salta en silencio: perder la sesion entera de
    /// calibracion por un JSON a medias seria absurdo.
    public func todas() -> [(url: URL, grabacion: Grabacion)] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: carpeta,
            includingPropertiesForKeys: nil
        )) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in (try? lee(url)).map { (url, $0) } }
            .sorted { $0.grabacion.fecha > $1.grabacion.fecha }
    }

    public func borra(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
