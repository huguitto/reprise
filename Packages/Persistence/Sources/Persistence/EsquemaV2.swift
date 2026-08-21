import Foundation
import SwiftData
import AlarmCore

/// El esquema en disco, version 2.
///
/// Lo unico que cambia respecto a `EsquemaV1` es la tabla de alarmas, que gana
/// `creadaEn`. Las otras tres tablas **son las mismas clases de la V1**, no una
/// copia con otro nombre: copiarlas para no tocarlas solo consigue tener dos
/// definiciones de la racha que hay que mantener a la vez, y el dia que se
/// desincronicen el fallo aparece en disco.
public enum EsquemaV2: VersionedSchema {

    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [AlarmaGuardada.self, EsquemaV1.EstadoRachaGuardado.self,
         EsquemaV1.RegistroDiaGuardado.self, EsquemaV1.RetoPendienteGuardado.self]
    }
}

// MARK: - Alarmas

extension EsquemaV2 {

    @Model
    final class AlarmaGuardada {
        @Attribute(.unique) var id: UUID
        var hora: Int
        var minuto: Int
        /// `Weekday.rawValue`. Vacio = alarma de un solo uso.
        var diasSemana: [Int]
        var reto: String
        var tonoID: String
        var etiqueta: String
        var activa: Bool
        /// Cuando se creo. Es lo que ordena la lista: la ultima puesta, arriba.
        ///
        /// El valor por defecto no es decorativo: es lo que permite que la
        /// migracion desde la V1 sea posible sin inventarse una fecha por fila.
        /// Lo que llega de la V1 sale con `distantPast` y `PlanDeMigracion` lo
        /// sella despues, respetando el orden por hora que el usuario ya veia.
        var creadaEn: Date = Date.distantPast

        init(id: UUID, hora: Int, minuto: Int, diasSemana: [Int], reto: String,
             tonoID: String, etiqueta: String, activa: Bool, creadaEn: Date) {
            self.id = id
            self.hora = hora
            self.minuto = minuto
            self.diasSemana = diasSemana
            self.reto = reto
            self.tonoID = tonoID
            self.etiqueta = etiqueta
            self.activa = activa
            self.creadaEn = creadaEn
        }

        convenience init(_ alarma: Alarm) {
            self.init(id: alarma.id, hora: alarma.hour, minuto: alarma.minute,
                      diasSemana: alarma.weekdays.map(\.rawValue).sorted(),
                      reto: alarma.challenge.rawValue, tonoID: alarma.toneID,
                      etiqueta: alarma.label, activa: alarma.isEnabled,
                      creadaEn: alarma.creadaEn)
        }

        /// Actualiza lo editable. **`creadaEn` no esta**: es el sello de cuando
        /// nacio la fila, y una alarma no nace dos veces. Si se reescribiera con
        /// lo que trae el dominio, cualquier guardado la mandaria arriba del
        /// todo y la lista bailaria cada vez que se toca una alarma vieja.
        func actualizar(desde alarma: Alarm) {
            hora = alarma.hour
            minuto = alarma.minute
            diasSemana = alarma.weekdays.map(\.rawValue).sorted()
            reto = alarma.challenge.rawValue
            tonoID = alarma.toneID
            etiqueta = alarma.label
            activa = alarma.isEnabled
        }

        var aDominio: Alarm {
            Alarm(
                id: id,
                hour: hora,
                minute: minuto,
                weekdays: Set(diasSemana.compactMap(Weekday.init(rawValue:))),
                // Un reto desconocido solo puede venir de haber instalado una
                // version mas nueva y volver atras. Se cae al reto por defecto
                // en vez de descartar la alarma: un despertador que se queda
                // callado es peor fallo que uno que pide los pasos equivocados.
                challenge: ChallengeType(rawValue: reto) ?? .pasos,
                toneID: tonoID,
                label: etiqueta,
                isEnabled: activa,
                creadaEn: creadaEn
            )
        }
    }
}
