import Testing
import Foundation
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

    @Test("El catalogo de hoy no tiene problemas")
    func catalogoSano() async {
        let problemas = await ToneCatalog.problemas(en: .main)
        #expect(problemas.isEmpty, "\(problemas.map(\.mensaje))")
    }
}
