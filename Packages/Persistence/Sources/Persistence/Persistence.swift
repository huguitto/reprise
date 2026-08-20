import Foundation
import SwiftData
import AlarmCore

/// Punto de entrada del almacen. La app monta el contenedor una vez, al
/// arrancar, y a partir de ahi inyecta `AlmacenSwiftData` en los protocolos de
/// `Contracts.swift`.
///
/// Todo lo de aqui funciona sin red, a proposito: la alarma, el reto y la racha
/// tienen que aguantar en un avion. Lo unico que espera a internet es el ranking,
/// y eso vive en otro paquete.
public enum Persistence {

    /// Version del esquema en disco. Se lee del esquema, no de una constante
    /// aparte, para que no puedan desincronizarse.
    public static var version: Schema.Version { EsquemaV1.versionIdentifier }

    /// El contenedor, con el plan de migracion enchufado desde el primer dia.
    ///
    /// - Parameters:
    ///   - enMemoria: para tests. En memoria no hay fichero, asi que tampoco hay
    ///     nada que sobreviva a cerrar la app.
    ///   - url: fichero concreto. Sirve para los tests que necesitan comprobar
    ///     justo eso, que lo guardado sigue ahi al volver a abrir. Si se pasa,
    ///     manda sobre `enMemoria`.
    public static func contenedor(enMemoria: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let esquema = Schema(versionedSchema: EsquemaV1.self)
        let configuracion = if let url {
            ModelConfiguration(schema: esquema, url: url)
        } else {
            ModelConfiguration(schema: esquema, isStoredInMemoryOnly: enMemoria)
        }
        return try ModelContainer(for: esquema, migrationPlan: PlanDeMigracion.self, configurations: configuracion)
    }

    public static func almacen(enMemoria: Bool = false, url: URL? = nil) throws -> AlmacenSwiftData {
        AlmacenSwiftData(modelContainer: try contenedor(enMemoria: enMemoria, url: url))
    }
}
