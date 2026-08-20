import Foundation
import AlarmCore

public struct LeaderboardEntry: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let displayName: String
    public let countryCode: String?
    public let currentStreak: Int
    public let bestStreak: Int
    public let rank: Int

    public init(id: String, displayName: String, countryCode: String?, currentStreak: Int, bestStreak: Int, rank: Int) {
        self.id = id
        self.displayName = displayName
        self.countryCode = countryCode
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.rank = rank
    }
}

public enum LeaderboardScope: Hashable, Sendable {
    case mundial
    case pais(String)
}

/// TAREA DEL AGENTE B O C EN FASE 2.
///
/// Supabase Auth (Apple, Google, email) y sincronizacion de la racha.
///
/// - La cuenta es OPCIONAL: la alarma entera funciona sin registrarse. Registrarse
///   sirve unicamente para aparecer en el ranking.
/// - Sincroniza con cola: si no hay red, se encola y se reintenta. Nunca bloquear
///   la interfaz de la alarma esperando al servidor.
/// - NO construyas antifraude. Decision explicita del usuario: cambiar la hora
///   del movil para inflar la racha se queda sin castigo. La app existe para
///   ayudar a quien quiere levantarse, no para vigilar a quien no.
public protocol RankingSyncing: Sendable {
    func push(current: Int, best: Int) async throws
    func leaderboard(_ scope: LeaderboardScope, page: Int) async throws -> [LeaderboardEntry]
    func myRank(_ scope: LeaderboardScope) async throws -> LeaderboardEntry?
}
