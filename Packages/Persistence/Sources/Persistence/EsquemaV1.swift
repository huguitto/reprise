import Foundation
import SwiftData
import AlarmCore

/// El esquema en disco, version 1.
///
/// Va declarado como `VersionedSchema` desde el primer dia aunque hoy solo haya
/// una version. No es ceremonia: SwiftData solo sabe migrar entre esquemas con
/// nombre y version, y el dia que haya un usuario con una racha de 40 dias ya no
/// se puede volver atras a ponerle nombre a esto.
///
/// Dos decisiones que se repiten en todos los modelos:
///
/// - **Los enums se guardan como texto plano** (`ChallengeType.rawValue`,
///   `FailureReason.rawValue`) en vez de dejar que SwiftData persista el enum.
///   Anadir un caso al enum entonces no toca el disco, y lo que hay guardado se
///   puede leer con los ojos si algun dia hay que depurar una racha perdida.
/// - **Los dias se guardan como ordinal `aaaammdd`**, no como `Date`. Ordena
///   igual que `Day`, se puede filtrar por rango en un `#Predicate`, y no
///   arrastra zona horaria: una racha se cuenta en dias vividos, no en instantes.
public enum EsquemaV1: VersionedSchema {

    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [AlarmaGuardada.self, EstadoRachaGuardado.self, RegistroDiaGuardado.self, RetoPendienteGuardado.self]
    }

    /// Clave de las tablas que solo pueden tener una fila. Ver `EstadoRachaGuardado`.
    static let filaUnica = 0
}

// MARK: - Alarmas

extension EsquemaV1 {

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

        init(id: UUID, hora: Int, minuto: Int, diasSemana: [Int], reto: String,
             tonoID: String, etiqueta: String, activa: Bool) {
            self.id = id
            self.hora = hora
            self.minuto = minuto
            self.diasSemana = diasSemana
            self.reto = reto
            self.tonoID = tonoID
            self.etiqueta = etiqueta
            self.activa = activa
        }

        convenience init(_ alarma: Alarm) {
            self.init(id: alarma.id, hora: alarma.hour, minuto: alarma.minute,
                      diasSemana: alarma.weekdays.map(\.rawValue).sorted(),
                      reto: alarma.challenge.rawValue, tonoID: alarma.toneID,
                      etiqueta: alarma.label, activa: alarma.isEnabled)
        }

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
                isEnabled: activa
            )
        }
    }
}

// MARK: - Estado de la racha

extension EsquemaV1 {

    /// Fila unica: `id` es siempre `EsquemaV1.filaUnica`.
    ///
    /// El `@Attribute(.unique)` no es decorativo. Sin el, un fallo de escritura
    /// que insertara un segundo estado dejaria la racha dependiendo de cual de
    /// las dos filas se lea primero, que es un bug imposible de reproducir y que
    /// borra rachas.
    @Model
    final class EstadoRachaGuardado {
        @Attribute(.unique) var id: Int
        var rachaActual: Int
        var mejorRacha: Int
        var diasCompletadosTotales: Int
        var vidasRestantes: Int
        /// OJO: `nil` significa "repon las vidas ya". Correcto en un usuario
        /// nuevo, veneno en uno existente. Ver `PlanDeMigracion`.
        var mesDeReposicionDeVidas: Int?
        var ultimoDiaContado: Int?

        init(id: Int = EsquemaV1.filaUnica, rachaActual: Int, mejorRacha: Int,
             diasCompletadosTotales: Int, vidasRestantes: Int,
             mesDeReposicionDeVidas: Int?, ultimoDiaContado: Int?) {
            self.id = id
            self.rachaActual = rachaActual
            self.mejorRacha = mejorRacha
            self.diasCompletadosTotales = diasCompletadosTotales
            self.vidasRestantes = vidasRestantes
            self.mesDeReposicionDeVidas = mesDeReposicionDeVidas
            self.ultimoDiaContado = ultimoDiaContado
        }

        convenience init(_ estado: StreakState) {
            self.init(rachaActual: estado.current, mejorRacha: estado.best,
                      diasCompletadosTotales: estado.diasCompletadosTotales,
                      vidasRestantes: estado.livesRemaining,
                      mesDeReposicionDeVidas: estado.livesRefilledYearMonth,
                      ultimoDiaContado: estado.lastCountedDay?.ordinal)
        }

        func actualizar(desde estado: StreakState) {
            rachaActual = estado.current
            mejorRacha = estado.best
            diasCompletadosTotales = estado.diasCompletadosTotales
            vidasRestantes = estado.livesRemaining
            ultimoDiaContado = estado.lastCountedDay?.ordinal
            // Nunca se escribe `nil` encima de un mes ya fijado. Ese campo a
            // `nil` es la senal de "repon las vidas", asi que borrarlo por
            // accidente le regala las dos vidas del mes al usuario cada vez que
            // abre la app, y con ellas el castigo por no levantarse.
            if let mes = estado.livesRefilledYearMonth {
                mesDeReposicionDeVidas = mes
            }
        }

        var aDominio: StreakState {
            StreakState(
                current: rachaActual,
                best: mejorRacha,
                livesRemaining: vidasRestantes,
                livesRefilledYearMonth: mesDeReposicionDeVidas,
                lastCountedDay: ultimoDiaContado.map(Day.init(ordinal:)),
                diasCompletadosTotales: diasCompletadosTotales
            )
        }
    }
}

// MARK: - Registro diario

extension EsquemaV1 {

    @Model
    final class RegistroDiaGuardado {
        /// Un dia, un registro. La unicidad la exige el dominio: dos registros
        /// del mismo dia significarian dos veces contado el mismo despertar.
        @Attribute(.unique) var diaOrdinal: Int
        var alarmID: UUID?
        var reto: String?
        /// "completado" | "fallado" | "salvadoPorVida"
        var resultado: String
        var motivoFallo: String?
        var duracion: Double?

        init(diaOrdinal: Int, alarmID: UUID?, reto: String?, resultado: String,
             motivoFallo: String?, duracion: Double?) {
            self.diaOrdinal = diaOrdinal
            self.alarmID = alarmID
            self.reto = reto
            self.resultado = resultado
            self.motivoFallo = motivoFallo
            self.duracion = duracion
        }

        convenience init(_ registro: DayRecord) {
            let (resultado, motivo) = Self.desmontar(registro.outcome)
            self.init(diaOrdinal: registro.day.ordinal, alarmID: registro.alarmID,
                      reto: registro.challenge?.rawValue, resultado: resultado,
                      motivoFallo: motivo, duracion: registro.duration)
        }

        func actualizar(desde registro: DayRecord) {
            let (nuevoResultado, motivo) = Self.desmontar(registro.outcome)
            alarmID = registro.alarmID
            reto = registro.challenge?.rawValue
            resultado = nuevoResultado
            motivoFallo = motivo
            duracion = registro.duration
        }

        static func desmontar(_ outcome: DayOutcome) -> (String, String?) {
            switch outcome {
            case .completado: ("completado", nil)
            case .fallado(let motivo): ("fallado", motivo.rawValue)
            case .salvadoPorVida(let motivo): ("salvadoPorVida", motivo.rawValue)
            }
        }

        /// `nil` si la fila esta corrupta o viene de una version futura.
        ///
        /// Aqui si se descarta, al reves que en las alarmas: el historial es
        /// para mirarlo, y una fila ilegible es una linea que falta en una lista.
        /// La racha no depende de esto, vive en `EstadoRachaGuardado`.
        var aDominio: DayRecord? {
            let outcome: DayOutcome
            switch resultado {
            case "completado":
                outcome = .completado
            case "fallado":
                guard let motivo = motivoFallo.flatMap(FailureReason.init(rawValue:)) else { return nil }
                outcome = .fallado(motivo)
            case "salvadoPorVida":
                guard let motivo = motivoFallo.flatMap(FailureReason.init(rawValue:)) else { return nil }
                outcome = .salvadoPorVida(motivo)
            default:
                return nil
            }
            return DayRecord(day: Day(ordinal: diaOrdinal), alarmID: alarmID,
                             challenge: reto.flatMap(ChallengeType.init(rawValue:)),
                             outcome: outcome, duration: duracion)
        }
    }
}

// MARK: - Rastro del reto empezado

extension EsquemaV1 {

    /// Fila unica, como el estado: solo puede haber un reto en marcha.
    @Model
    final class RetoPendienteGuardado {
        @Attribute(.unique) var id: Int
        var alarmID: UUID
        var reto: String
        var diaOrdinal: Int
        var inicioEn: Date

        init(id: Int = EsquemaV1.filaUnica, alarmID: UUID, reto: String,
             diaOrdinal: Int, inicioEn: Date) {
            self.id = id
            self.alarmID = alarmID
            self.reto = reto
            self.diaOrdinal = diaOrdinal
            self.inicioEn = inicioEn
        }

        convenience init(_ pendiente: PendingChallenge) {
            self.init(alarmID: pendiente.alarmID, reto: pendiente.challenge.rawValue,
                      diaOrdinal: pendiente.day.ordinal, inicioEn: pendiente.startedAt)
        }

        func actualizar(desde pendiente: PendingChallenge) {
            alarmID = pendiente.alarmID
            reto = pendiente.challenge.rawValue
            diaOrdinal = pendiente.day.ordinal
            inicioEn = pendiente.startedAt
        }

        var aDominio: PendingChallenge {
            PendingChallenge(
                alarmID: alarmID,
                // Un reto ilegible no puede hacer desaparecer el rastro: el
                // rastro existe justamente para penalizar, y perderlo seria
                // regalar la forma de saltarse el despertador.
                challenge: ChallengeType(rawValue: reto) ?? .pasos,
                day: Day(ordinal: diaOrdinal),
                startedAt: inicioEn
            )
        }
    }
}

// MARK: - Dias como ordinal

extension Day {
    /// `aaaammdd`. Ordena igual que `Day`, asi que un rango de dias es un rango
    /// de enteros y se puede filtrar en un `#Predicate`.
    var ordinal: Int { year * 10_000 + month * 100 + day }

    init(ordinal: Int) {
        self.init(year: ordinal / 10_000,
                  month: (ordinal / 100) % 100,
                  day: ordinal % 100)
    }
}
