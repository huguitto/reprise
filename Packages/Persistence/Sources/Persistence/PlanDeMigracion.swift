import Foundation
import SwiftData
import AlarmCore

/// El plan de migracion del almacen.
///
/// Hoy solo hay una version y `stages` esta vacio a proposito: no hay nada que
/// migrar todavia. Lo que importa es que el plan **exista y este enchufado al
/// contenedor desde el primer dia**, porque el dia que haga falta la primera
/// migracion ya habra usuarios con racha en disco y no se puede volver atras a
/// declarar de donde venian.
///
/// ## Como se anade la version 2
///
/// 1. Se copia `EsquemaV1` a un `EsquemaV2` con los modelos cambiados.
/// 2. Se anade a `schemas` **sin quitar** `EsquemaV1`: el plan tiene que seguir
///    sabiendo leer lo que hay instalado en los moviles.
/// 3. Se anade la etapa a `stages`. Si el cambio es solo anadir campos con valor
///    por defecto, vale `MigrationStage.lightweight`. Si toca campos que ya
///    existen, tiene que ser `MigrationStage.custom` y pasar por
///    `reparaMesDeReposicionDeVidas` en su `didMigrate`:
///
/// ```swift
/// static let v1aV2 = MigrationStage.custom(
///     fromVersion: EsquemaV1.self,
///     toVersion: EsquemaV2.self,
///     willMigrate: nil,
///     didMigrate: { contexto in
///         try PlanDeMigracion.reparaMesDeReposicionDeVidas(contexto)
///         try contexto.save()
///     }
/// )
/// ```
public enum PlanDeMigracion: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] { [EsquemaV1.self] }

    public static var stages: [MigrationStage] { [] }

    /// Repara el campo que mas dano hace si se pierde en una migracion.
    ///
    /// `livesRefilledYearMonth` a `nil` significa "repon las vidas". Es lo
    /// correcto para un usuario recien instalado, y un desastre para uno que ya
    /// existia: le devuelve las dos vidas del mes, y con ellas el castigo por no
    /// levantarse, cada vez que una migracion le deje el campo vacio.
    ///
    /// La reparacion no necesita saber que dia es hoy, y por eso se puede hacer
    /// dentro de una migracion: el mes se deduce de lo que ya hay en disco, del
    /// ultimo dia contado o, si eso tambien se perdio, del registro mas reciente.
    /// Si no hay ni una cosa ni otra, el usuario **es** nuevo y el `nil` se queda
    /// donde esta, que es lo correcto.
    @discardableResult
    static func reparaMesDeReposicionDeVidas(_ contexto: ModelContext) throws -> Int {
        let estados = try contexto.fetch(FetchDescriptor<EsquemaV1.EstadoRachaGuardado>())
        var reparados = 0

        for estado in estados where estado.mesDeReposicionDeVidas == nil {
            var referencia = estado.ultimoDiaContado

            if referencia == nil {
                var ultimo = FetchDescriptor<EsquemaV1.RegistroDiaGuardado>(
                    sortBy: [SortDescriptor(\.diaOrdinal, order: .reverse)]
                )
                ultimo.fetchLimit = 1
                referencia = try contexto.fetch(ultimo).first?.diaOrdinal
            }

            guard let ordinal = referencia else { continue }
            estado.mesDeReposicionDeVidas = Day(ordinal: ordinal).yearMonth
            reparados += 1
        }

        return reparados
    }
}
