import Testing
@testable import AlarmScheduler

// Marcador para que el target de tests exista y `swift test` no falle.
// Sustituyelo por tests de verdad donde aporten: los obligatorios viven en AlarmCore.
@Suite("AlarmScheduler")
struct AlarmSchedulerSmokeTests {
    @Test("El modulo compila y se puede importar")
    func compila() { #expect(true) }
}
