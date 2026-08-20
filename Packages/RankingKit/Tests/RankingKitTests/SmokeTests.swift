import Testing
@testable import RankingKit

// Marcador para que el target de tests exista y `swift test` no falle.
// Sustituyelo por tests de verdad donde aporten: los obligatorios viven en AlarmCore.
@Suite("RankingKit")
struct RankingKitSmokeTests {
    @Test("El modulo compila y se puede importar")
    func compila() { #expect(true) }
}
