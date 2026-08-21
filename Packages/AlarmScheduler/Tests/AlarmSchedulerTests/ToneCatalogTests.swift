import Testing
import Foundation
import AVFoundation
import AlarmCore
@testable import AlarmScheduler

@Suite("Catalogo de tonos")
struct ToneCatalogTests {
    @Test("El tono del sistema existe, es gratis y no tiene fichero")
    func tonoDelSistema() {
        let sistema = ToneCatalog.sistema
        #expect(sistema.id == Tone.defaultID)
        #expect(sistema.fileName == nil)
        #expect(sistema.isPro == false)
        #expect(ToneCatalog.todos.contains(sistema))
    }

    @Test("No hay dos tonos con el mismo id")
    func idsUnicos() {
        let ids = ToneCatalog.todos.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Gratis y Pro reparten el catalogo entero sin solaparse")
    func repartoGratisYPro() {
        #expect(ToneCatalog.gratis.count + ToneCatalog.pro.count == ToneCatalog.todos.count)
        #expect(ToneCatalog.gratis.allSatisfy { !$0.isPro })
        #expect(ToneCatalog.pro.allSatisfy { $0.isPro })
    }

    @Test("Un id que no existe se cae al sonido del sistema, no deja sin alarma")
    func idDesconocido() {
        #expect(ToneCatalog.tono(id: "no-existe") == nil)
        #expect(ToneCatalog.tonoEfectivo(id: "no-existe") == ToneCatalog.sistema)
    }

    @Test("Un tono cuyo fichero no esta en el bundle se cae al del sistema")
    func ficheroQueFalta() {
        // El bundle de los tests no lleva audio: es exactamente el caso que se
        // quiere probar, el de un tono declarado cuyo fichero nunca llego.
        let fantasma = Tone(id: "fantasma", nombre: "Fantasma", fileName: "no-esta.caf", isPro: true)
        #expect(ToneCatalog.url(deFichero: fantasma.fileName!, en: .main) == nil)
        #expect(ToneCatalog.tonoEfectivo(id: fantasma.id, en: .main) == ToneCatalog.sistema)
    }

    @Test("El limite de AlarmKit son 30 segundos")
    func limiteDeDuracion() {
        #expect(ToneCatalog.duracionMaxima == 30)
    }

    @Test("Cada tono del bundle declara su fichero, y no hay dos que apunten al mismo")
    func cadaTonoTieneSuFichero() {
        for tono in ToneCatalog.delBundle {
            #expect(tono.fileName != nil, "el tono '\(tono.id)' no dice de que fichero sale")
        }
        let ficheros = ToneCatalog.delBundle.compactMap(\.fileName)
        #expect(Set(ficheros).count == ficheros.count, "hay dos tonos apuntando al mismo fichero")
    }

    /// Los ficheros del catalogo existen de verdad y caben en el limite.
    ///
    /// Antes esto se preguntaba a `Bundle.main`, y en `swift test` el bundle es
    /// el de los tests: sin audio dentro, el resultado era el mismo tanto si el
    /// catalogo estaba bien como si estaba vacio. Se mira `App/Resources`, que
    /// es de donde los coge la app, localizado desde este mismo fichero para no
    /// depender de desde donde se lance el test.
    ///
    /// Lo que caza: declarar un tono y olvidarse del fichero, y meter uno que
    /// pase de los 30 segundos que corta AlarmKit. Las dos cosas se descubrirían
    /// si no a las siete de la manana, en casa de alguien.
    @Test("Los ficheros del catalogo estan en App/Resources y no pasan de 30 s")
    func ficherosDelCatalogo() async throws {
        let raiz = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // AlarmSchedulerTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // AlarmScheduler
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // raiz del repo
            .appending(path: "App/Resources")

        for tono in ToneCatalog.delBundle {
            let fichero = try #require(tono.fileName)
            let url = raiz.appending(path: fichero)
            #expect(FileManager.default.fileExists(atPath: url.path),
                    "el tono '\(tono.id)' apunta a '\(fichero)' y ese fichero no esta en App/Resources")

            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let duracion = try await duracionDe(url)
            #expect(duracion <= ToneCatalog.duracionMaxima,
                    "el tono '\(tono.id)' dura \(duracion) s y AlarmKit corta a los \(ToneCatalog.duracionMaxima)")
        }
    }

    private func duracionDe(_ url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(try await asset.load(.duration))
    }
}
