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
        "No se pierde el material con el que se cerro el detector",
        .enabled(if: GrabacionesReales.hayGrabaciones)
    )
    func materialSuficiente() {
        // Este test pedia cinco sesiones, que es lo que pide el encargo en
        // `plan-c.md`. El 21 de agosto de 2026 el dueno del producto decidio
        // cerrar la calibracion con **dos**, despues de ver que las dos contaban
        // 10 de 10 y que la trampa se quedaba en 3. Queda dicho aqui y en
        // `plan-c.md` para que nadie lo lea como que el criterio se cumplio.
        //
        // Lo que queda vigilado ya no es "hay bastante", sino "no se ha perdido
        // lo poco que hay": con la calibracion fuera de la app, estas
        // grabaciones no se pueden volver a hacer sin recolgar `CalibracionView`,
        // asi que borrarlas es irreversible.
        #expect(
            GrabacionesReales.sentadillas.count >= 2,
            "faltan grabaciones de sentadillas, hay \(GrabacionesReales.sentadillas.count)"
        )
        #expect(
            !GrabacionesReales.trampas.isEmpty,
            "falta al menos una grabacion de tipo trampa"
        )
    }
}
