import Foundation
import SwiftData
import AlarmCore

/// El plan de migracion del almacen.
///
/// El plan **existe y esta enchufado al contenedor desde el primer dia**, que es
/// lo que hace posible la primera migracion sin perder a quien ya tenia el
/// esquema anterior instalado.
///
/// ## Como se anade la version siguiente
///
/// 1. Se copia el esquema anterior a uno nuevo con los modelos cambiados. Las
///    tablas que no cambian se reutilizan tal cual, como hace `EsquemaV2` con
///    las tres de la racha.
/// 2. Se anade a `schemas` **sin quitar** las viejas: el plan tiene que seguir
///    sabiendo leer lo que hay instalado en los moviles.
/// 3. Se anade la etapa a `stages`. Si el cambio es solo anadir campos con valor
///    por defecto, vale `MigrationStage.lightweight`. Si toca campos que ya
///    existen, tiene que ser `MigrationStage.custom` y pasar por
///    `reparaMesDeReposicionDeVidas` en su `didMigrate`.
public enum PlanDeMigracion: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] { [EsquemaV1.self, EsquemaV2.self] }

    public static var stages: [MigrationStage] { [v1aV2] }

    /// V1 -> V2: las alarmas ganan `creadaEn`.
    ///
    /// Es `custom` y no `lightweight` porque anadir el campo no basta. La V1 no
    /// guardaba cuando se creo ninguna alarma, asi que todo lo que hay instalado
    /// llegaria aqui con la misma fecha y la lista saldria en un orden que no
    /// elige nadie. `sellarAlarmasExistentes` les pone fechas que reproducen el
    /// orden por hora que el usuario ya estaba viendo: al actualizar, la lista
    /// se queda exactamente como la dejo.
    static let v1aV2 = MigrationStage.custom(
        fromVersion: EsquemaV1.self,
        toVersion: EsquemaV2.self,
        willMigrate: nil,
        didMigrate: { contexto in
            try PlanDeMigracion.sellarAlarmasExistentes(contexto)
            try contexto.save()
        }
    )

    /// Le pone fecha de creacion a las alarmas que vienen de la V1.
    ///
    /// La lista ordena por `creadaEn` de mas nueva a mas vieja, asi que para que
    /// el orden visible no cambie hay que repartir las fechas al reves que las
    /// horas: la alarma mas temprana se lleva la fecha mas reciente.
    ///
    /// Todas quedan estrictamente antes de `referencia`, que es el momento de la
    /// migracion. Cualquier alarma que se cree despues es mas nueva que estas y
    /// sale arriba, que es justo lo que se espera.
    @discardableResult
    static func sellarAlarmasExistentes(_ contexto: ModelContext) throws -> Int {
        let sinSellar = try contexto.fetch(FetchDescriptor<EsquemaV2.AlarmaGuardada>())
            .filter { $0.creadaEn == .distantPast }
            .sorted { ($0.hora, $0.minuto, $0.id.uuidString) < ($1.hora, $1.minuto, $1.id.uuidString) }

        let referencia = Date()
        for (indice, fila) in sinSellar.enumerated() {
            fila.creadaEn = referencia.addingTimeInterval(-Double(indice + 1))
        }
        return sinSellar.count
    }

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
