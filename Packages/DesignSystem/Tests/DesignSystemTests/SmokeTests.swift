import Testing
@testable import DesignSystem

// Marcador para que el target de tests exista y `swift test` no falle.
// Sustituyelo por tests de verdad donde aporten: los obligatorios viven en AlarmCore.
@Suite("DesignSystem")
struct DesignSystemSmokeTests {
    @Test("El modulo compila y se puede importar")
    func compila() { #expect(true) }
}
