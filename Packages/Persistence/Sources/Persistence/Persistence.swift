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
/// Construir dos `ModelContainer` a la vez revienta.
///
/// No es teoria: con los tests en paralelo, CoreData peta con SIGSEGV una vez
/// de cada veinte dentro de `_generateTriggerSQL`, creando las tablas del
/// esquema. Con las mismas pruebas en serie, cero de veinticinco.
///
/// La app monta un solo contenedor al arrancar y nunca veria esto, pero una
/// fabrica publica que segfaltea si dos hilos la llaman a la vez es una mina
/// para el que venga detras (una extension, un widget). Sale mas barato
/// serializar aqui, donde no cuesta nada, que documentarlo y confiar.
private let cerrojoDelContenedor = NSLock()

public enum Persistence {

    /// Version del esquema en disco. Se lee del esquema, no de una constante
    /// aparte, para que no puedan desincronizarse.
    public static var version: Schema.Version { EsquemaV2.versionIdentifier }

    /// El contenedor, con el plan de migracion enchufado desde el primer dia.
    ///
    /// - Parameters:
    ///   - enMemoria: para tests. En memoria no hay fichero, asi que tampoco hay
    ///     nada que sobreviva a cerrar la app.
    ///   - url: fichero concreto. Sirve para los tests que necesitan comprobar
    ///     justo eso, que lo guardado sigue ahi al volver a abrir. Si se pasa,
    ///     manda sobre `enMemoria`.
    public static func contenedor(enMemoria: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let esquema = Schema(versionedSchema: EsquemaV2.self)
        let configuracion = if let url {
            ModelConfiguration(schema: esquema, url: url)
        } else {
            ModelConfiguration(schema: esquema, isStoredInMemoryOnly: enMemoria)
        }
        cerrojoDelContenedor.lock()
        defer { cerrojoDelContenedor.unlock() }
        return try ModelContainer(for: esquema, migrationPlan: PlanDeMigracion.self, configurations: configuracion)
    }

    /// Un contenedor pegado a una version **vieja** del esquema, sin plan de
    /// migracion. Solo para pruebas: es la unica forma de fabricar un fichero
    /// como el que tiene instalado quien todavia no ha actualizado, y sin eso
    /// una migracion no se puede probar, solo leer.
    ///
    /// Pasa por el mismo cerrojo que `contenedor(enMemoria:url:)` y por la misma
    /// razon: dos `ModelContainer` construyendose a la vez revientan.
    static func contenedor(deEsquema version: any VersionedSchema.Type, url: URL) throws -> ModelContainer {
        let esquema = Schema(versionedSchema: version)
        cerrojoDelContenedor.lock()
        defer { cerrojoDelContenedor.unlock() }
        return try ModelContainer(for: esquema, configurations: ModelConfiguration(schema: esquema, url: url))
    }

    public static func almacen(enMemoria: Bool = false, url: URL? = nil) throws -> AlmacenSwiftData {
        AlmacenSwiftData(modelContainer: try contenedor(enMemoria: enMemoria, url: url))
    }
}
