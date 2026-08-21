import Testing
import Foundation
import AlarmCore
@testable import ChallengeKit

/// Reproduce las grabaciones reales que haya en `Packages/ChallengeKit/Grabaciones`.
///
/// Mientras la carpeta este vacia estos tests se saltan, y se saltan **a la
/// vista**: aparecer como omitidos es el recordatorio de que los umbrales de
/// `ParametrosSentadilla` siguen sin estar respaldados por una sola sentadilla de
/// verdad. En cuanto caiga el primer fichero, esto pasa a ser el criterio de
/// terminado del encargo, comprobado en cada `swift test`.
enum GrabacionesReales {

    /// La carpeta se localiza desde este mismo fichero: los tests corren sin
    /// bundle de recursos y `Bundle.module` no llega hasta aqui.
    static var carpeta: URL {
        URL(fileURLWithPath: #filePath)      // .../Tests/ChallengeKitTests/este.swift
            .deletingLastPathComponent()     // .../Tests/ChallengeKitTests
            .deletingLastPathComponent()     // .../Tests
            .deletingLastPathComponent()     // .../ChallengeKit
            .appendingPathComponent("Grabaciones", isDirectory: true)
    }

    static var todas: [Grabacion] {
        AlmacenDeGrabaciones(carpeta: carpeta).todas().map(\.grabacion)
    }

    static var hayGrabaciones: Bool { !todas.isEmpty }

    static var sentadillas: [Grabacion] { todas.filter { $0.tipo == .sentadillas } }
    static var trampas: [Grabacion] { todas.filter { $0.tipo == .trampa } }
}

@Suite("Grabaciones reales")
struct GrabacionesRealesTests {

    @Test(
        "Cada sesion real cuenta exactamente lo que hizo la persona",
        .enabled(if: GrabacionesReales.hayGrabaciones)
    )
    func cuentanExacto() {
        for grabacion in GrabacionesReales.sentadillas {
            let r = Reproductor.reproduce(grabacion, parametros: .porDefecto, conTraza: false)
            #expect(
                r.contadas == grabacion.repeticionesReales,
                "\(grabacion.etiqueta): conto \(r.contadas), la persona hizo \(grabacion.repeticionesReales)"
            )
        }
    }

    @Test(
        "Agitar el movil no llega al objetivo",
        .enabled(if: GrabacionesReales.hayGrabaciones)
    )
    func laTrampaNoCuela() {
        for grabacion in GrabacionesReales.trampas {
            let r = Reproductor.reproduce(grabacion, parametros: .porDefecto, conTraza: false)
            #expect(
                r.contadas < ChallengeType.sentadillas.goal,
                "\(grabacion.etiqueta): la trampa llego a \(r.contadas)"
            )
        }
    }

    @Test(
        "Hay material suficiente para dar el detector por bueno",
        .enabled(if: GrabacionesReales.hayGrabaciones)
    )
    func materialSuficiente() {
        // El criterio del encargo, escrito como test para que no se olvide a
        // mitad: cinco sesiones y al menos una trampa. Falla a proposito
        // mientras falte material, porque tener tres grabaciones y creerse
        // calibrado es peor que no tener ninguna.
        #expect(
            GrabacionesReales.sentadillas.count >= 5,
            "hacen falta 5 sesiones distintas, hay \(GrabacionesReales.sentadillas.count)"
        )
        #expect(
            !GrabacionesReales.trampas.isEmpty,
            "falta al menos una grabacion de tipo trampa"
        )
    }
}
