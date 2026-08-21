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

    /// Todas menos las que la persona que grabo marco como descartadas.
    ///
    /// Los ficheros no se borran —no se pueden volver a generar— pero una
    /// grabacion cuyo `repeticionesReales` no es de fiar es **peor que ninguna**:
    /// es un numero falso tirando de los umbrales. El 21/08/2026 Hugo grabo dos
    /// sesiones de pasos y dijo que la buena era la segunda; la primera lleva la
    /// etiqueta y se queda en la carpeta por si algun dia se sabe que le paso.
    static var todas: [Grabacion] {
        AlmacenDeGrabaciones(carpeta: carpeta).todas()
            .map(\.grabacion)
            .filter { !$0.etiqueta.hasPrefix("descartada") }
    }

    /// Incluidas las descartadas. Solo para el test que vigila que no se borren.
    static var todasIncluidasLasDescartadas: [Grabacion] {
        AlmacenDeGrabaciones(carpeta: carpeta).todas().map(\.grabacion)
    }

    static var hayGrabaciones: Bool { !todas.isEmpty }

    static var sentadillas: [Grabacion] { todas.filter { $0.tipo == .sentadillas } }
    static var pasos: [Grabacion] { todas.filter { $0.tipo == .pasos } }
    static var trampas: [Grabacion] { todas.filter { $0.tipo == .trampa } }
    static var hayPasos: Bool { !pasos.isEmpty }
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

    /// Aqui no se pide el numero exacto, y no por comodidad.
    ///
    /// Medido el 21/08/2026: andando despacio cuenta 20 de 20, y andando deprisa
    /// 23 de 20. Ese 15% de mas se puede quitar —bajando `techoDePico` a 4 salen
    /// 20 y 20— pero entonces el algoritmo se vuelve de cristal: la misma
    /// caminata escalada a 1,5 veces la fuerza cae a **11 de 20**. Lo vigila
    /// `laMismaCaminataMasFuerteSigueContando`, que es el test hermano de este y
    /// el que manda si los dos se pelean.
    ///
    /// Asi que el liston es 15% por cada lado: pasarse un poco solo adelanta el
    /// final del reto, y quedarse corto es lo que dejo a alguien dando sesenta
    /// pasos para ver veinte.
    @Test(
        "Cada sesion de andar cuenta los pasos que dio la persona, con un 15% de holgura",
        .enabled(if: GrabacionesReales.hayPasos)
    )
    func losPasosCuentanCasiExacto() {
        for grabacion in GrabacionesReales.pasos {
            let r = ReproductorDePasos.reproduce(grabacion, parametros: .porDefecto, conTraza: false)
            let holgura = max(1, grabacion.repeticionesReales * 15 / 100)
            #expect(
                abs(r.contados - grabacion.repeticionesReales) <= holgura,
                "\(grabacion.etiqueta): conto \(r.contados), la persona dio \(grabacion.repeticionesReales)"
            )
        }
    }

    /// **El test que impide apretar los umbrales hasta clavar el numero.**
    ///
    /// Solo hay dos caminatas grabadas y son de la misma persona, con su fuerza.
    /// Afinar hasta que esas dos den 20 exactos es aprenderselas de memoria, no
    /// calibrar. Aqui se coge esa misma senal real —con la forma de una pisada
    /// de verdad, que ninguna sinusoide imita— y se sube y se baja el volumen,
    /// que es lo que cambia de una persona a otra.
    ///
    /// El liston es 16 de 20: por debajo de eso ya no es "contar de menos", es
    /// dejar a alguien sin poder apagar la alarma.
    @Test(
        "La misma caminata mas fuerte o mas floja sigue contando",
        .enabled(if: GrabacionesReales.hayPasos)
    )
    func laMismaCaminataMasFuerteSigueContando() {
        for grabacion in GrabacionesReales.pasos {
            for escala in [0.75, 1.5, 2.0] {
                let escalada = Grabacion(
                    tipo: grabacion.tipo,
                    repeticionesReales: grabacion.repeticionesReales,
                    etiqueta: grabacion.etiqueta,
                    frecuenciaHz: grabacion.frecuenciaHz,
                    muestras: grabacion.muestras.map {
                        MuestraDeMovimiento(
                            t: $0.t,
                            ax: $0.ax * escala, ay: $0.ay * escala, az: $0.az * escala,
                            gx: $0.gx, gy: $0.gy, gz: $0.gz
                        )
                    }
                )
                let r = ReproductorDePasos.reproduce(escalada, parametros: .porDefecto, conTraza: false)
                #expect(
                    r.contados >= 16,
                    "\(grabacion.etiqueta) al \(escala)x de fuerza: conto \(r.contados) de \(grabacion.repeticionesReales)"
                )
            }
        }
    }

    /// El sintoma del issue #35 vigilado sobre senal de verdad: aunque el numero
    /// exacto se escape por uno, quedarse en un tercio no puede volver a pasar
    /// sin que `swift test` lo diga.
    @Test(
        "Ninguna sesion de andar se queda corta de largo",
        .enabled(if: GrabacionesReales.hayPasos)
    )
    func losPasosNoSeQuedanCortos() {
        for grabacion in GrabacionesReales.pasos {
            let r = ReproductorDePasos.reproduce(grabacion, parametros: .porDefecto, conTraza: false)
            let minimo = Int(Double(grabacion.repeticionesReales) * 0.9)
            #expect(
                r.contados >= minimo,
                "\(grabacion.etiqueta): conto \(r.contados) de \(grabacion.repeticionesReales) pasos dados"
            )
        }
    }

    @Test(
        "Agitar el movil tampoco llega al objetivo de pasos",
        .enabled(if: GrabacionesReales.hayGrabaciones)
    )
    func laTrampaTampocoCuelaComoPasos() {
        for grabacion in GrabacionesReales.trampas {
            let r = ReproductorDePasos.reproduce(grabacion, parametros: .porDefecto, conTraza: false)
            #expect(
                r.contados < ChallengeType.pasos.goal,
                "\(grabacion.etiqueta): la trampa llego a \(r.contados) pasos"
            )
        }
    }

    /// El fallo que Hugo vio en el telefono el 21/08/2026: de pie, sin moverse
    /// del sitio, moviendo solo la mano, el contador subia. Grabado y medido, ese
    /// gesto contaba **16 pasos en 12 segundos** — quince segundos de muneca y la
    /// alarma se apaga sin levantarse.
    ///
    /// El liston esta en un cuarto del objetivo y no en el objetivo entero a
    /// proposito. Con `< goal` este test pasaba con las trampas contando 4, 7 y
    /// 16, que es exactamente el estado roto: se llegaba al final sumando manos.
    /// Aqui lo que se vigila es que no se **acerquen**, y quien lo consigue es el
    /// techo de giro: sin el, estas tres suben a 4, 7 y 16 y esto se cae.
    @Test(
        "Ninguna trampa se acerca al objetivo de pasos",
        .enabled(if: GrabacionesReales.hayGrabaciones)
    )
    func lasTrampasNiSeAcercan() {
        for grabacion in GrabacionesReales.trampas {
            let r = ReproductorDePasos.reproduce(grabacion, parametros: .porDefecto, conTraza: false)
            #expect(
                r.contados <= ChallengeType.pasos.goal / 4,
                "\(grabacion.etiqueta): la trampa llego a \(r.contados) pasos de \(ChallengeType.pasos.goal)"
            )
        }
    }

    /// La otra mitad del techo de giro: que no se lo cobre con quien anda.
    ///
    /// Si el veto empezara a morder a las caminatas reales seria el issue #35
    /// otra vez, y esta vez lo habriamos metido nosotros. Con el techo puesto,
    /// las tres grabaciones cuentan lo mismo, paso por paso, que sin el.
    @Test(
        "El techo de giro no le quita ni un paso a quien anda",
        .enabled(if: GrabacionesReales.hayPasos)
    )
    func elTechoDeGiroNoTocaLasCaminatas() {
        var sinTecho = ParametrosPaso.porDefecto
        sinTecho.techoDeGiro = .infinity
        for grabacion in GrabacionesReales.pasos {
            let con = ReproductorDePasos.reproduce(grabacion, parametros: .porDefecto, conTraza: false)
            let sin = ReproductorDePasos.reproduce(grabacion, parametros: sinTecho, conTraza: false)
            #expect(
                con.contados == sin.contados,
                "\(grabacion.etiqueta): con techo \(con.contados), sin techo \(sin.contados)"
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
        // Las descartadas cuentan aqui: siguen siendo material irrepetible.
        #expect(
            GrabacionesReales.todasIncluidasLasDescartadas.count >= 7,
            "se ha perdido alguna grabacion: hay \(GrabacionesReales.todasIncluidasLasDescartadas.count) de 7"
        )
    }
}
