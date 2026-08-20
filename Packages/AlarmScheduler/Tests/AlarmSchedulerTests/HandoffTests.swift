import Testing
import Foundation
import AlarmCore
@testable import AlarmScheduler

/// Un `UserDefaults` de usar y tirar, para no escribir en el del que ejecute
/// los tests.
private func defaultsDePrueba(_ nombre: String = UUID().uuidString) -> UserDefaults {
    UserDefaults(suiteName: nombre)!
}

@Suite("Registro de tonos")
struct ToneRegistryTests {
    @Test("Guarda y devuelve el tono de cada alarma")
    func guardaYDevuelve() {
        let registro = ToneRegistry(defaults: defaultsDePrueba())
        let alarma = UUID()
        #expect(registro.toneID(for: alarma) == nil)
        registro.record(toneID: "amanecer", for: alarma)
        #expect(registro.toneID(for: alarma) == "amanecer")
    }

    @Test("Reprogramar la misma alarma pisa el tono viejo")
    func pisaElViejo() {
        let registro = ToneRegistry(defaults: defaultsDePrueba())
        let alarma = UUID()
        registro.record(toneID: "amanecer", for: alarma)
        registro.record(toneID: Tone.defaultID, for: alarma)
        #expect(registro.toneID(for: alarma) == Tone.defaultID)
    }

    @Test("Cancelar una alarma se lleva su tono por delante")
    func olvida() {
        let registro = ToneRegistry(defaults: defaultsDePrueba())
        let alarma = UUID(), otra = UUID()
        registro.record(toneID: "amanecer", for: alarma)
        registro.record(toneID: "cascada", for: otra)
        registro.forget(alarmID: alarma)
        #expect(registro.toneID(for: alarma) == nil)
        #expect(registro.toneID(for: otra) == "cascada")
    }

    @Test("La limpieza solo conserva las alarmas que siguen programadas")
    func limpieza() {
        let registro = ToneRegistry(defaults: defaultsDePrueba())
        let viva = UUID(), muerta = UUID()
        registro.record(toneID: "amanecer", for: viva)
        registro.record(toneID: "cascada", for: muerta)
        registro.prune(keeping: [viva])
        #expect(registro.toneID(for: viva) == "amanecer")
        #expect(registro.toneID(for: muerta) == nil)
    }
}

@Suite("Buzon del reto")
struct ChallengeInboxTests {
    @Test("Vacio de partida")
    func vacio() {
        #expect(ChallengeInbox.peek(in: defaultsDePrueba()) == nil)
    }

    @Test("El recado del boton secundario llega entero")
    func viajeCompleto() {
        let defaults = defaultsDePrueba()
        let peticion = ChallengeRequest(alarmID: UUID(), challenge: .sentadillas, requestedAt: Date())
        ChallengeInbox.post(peticion, to: defaults)
        #expect(ChallengeInbox.peek(in: defaults) == peticion)
    }

    @Test("Un recado se atiende una sola vez")
    func seConsumeUnaVez() {
        let defaults = defaultsDePrueba()
        let peticion = ChallengeRequest(alarmID: UUID(), challenge: .pasos, requestedAt: Date())
        ChallengeInbox.post(peticion, to: defaults)
        #expect(ChallengeInbox.consume(from: defaults) == peticion)
        #expect(ChallengeInbox.consume(from: defaults) == nil)
    }

    @Test("Una alarma nueva pisa el recado anterior: solo suena una a la vez")
    func soloElUltimo() {
        let defaults = defaultsDePrueba()
        let vieja = ChallengeRequest(alarmID: UUID(), challenge: .pasos, requestedAt: Date())
        let nueva = ChallengeRequest(alarmID: UUID(), challenge: .sentadillas, requestedAt: Date())
        ChallengeInbox.post(vieja, to: defaults)
        ChallengeInbox.post(nueva, to: defaults)
        #expect(ChallengeInbox.peek(in: defaults) == nueva)
    }
}
