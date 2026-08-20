import Foundation
import AlarmCore

/// TAREA DEL AGENTE A (segunda mitad).
///
/// Implementa `AlarmRepository`, `StreakRepository`, `DayRecordRepository` y
/// `PendingChallengeRepository` con SwiftData. Requisitos que no son negociables:
///
/// - Todo funciona sin red. La app tiene que despertar y contar la racha en un
///   avion; el ranking se sincroniza cuando haya internet.
/// - `PendingChallengeRepository.begin` tiene que escribir a disco ANTES de que
///   arranque el reto y sobrevivir a que maten la app. Es lo unico que distingue
///   "reinicio el movil para saltarse la alarma" de "se le fue la bateria".
/// - Las migraciones se declaran explicitamente desde el primer dia.
public enum Persistence {
    public static let schemaVersion = 1
}
