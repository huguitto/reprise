import Testing
import Foundation
@testable import ChallengeKit

@Suite("Almacen de grabaciones")
struct AlmacenDeGrabacionesTests {

    private func carpetaTemporal() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("grabaciones-test-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("Una grabacion sobrevive al viaje de ida y vuelta al disco")
    func idaYVuelta() throws {
        // Importa mas de lo que parece: la grabacion tiene que poder salir del
        // iPhone, cruzar hasta el repositorio y reproducirse en el Mac dando el
        // mismo numero. Si el JSON pierde precision por el camino, calibrar
        // sobre ficheros deja de significar nada.
        let carpeta = carpetaTemporal()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let almacen = AlmacenDeGrabaciones(carpeta: carpeta)

        let original = Senales.grabacion(
            Senales.sentadillas(repeticiones: 4),
            reales: 4,
            etiqueta: "mano derecha"
        )
        try almacen.guarda(original)

        let leidas = almacen.todas()
        #expect(leidas.count == 1)
        let recuperada = try #require(leidas.first?.grabacion)
        #expect(recuperada.muestras.count == original.muestras.count)
        #expect(recuperada.repeticionesReales == 4)
        #expect(
            Reproductor.reproduce(recuperada, conTraza: false).contadas
                == Reproductor.reproduce(original, conTraza: false).contadas
        )
    }

    @Test("El nombre del fichero se puede leer de un vistazo")
    func nombreLegible() {
        let g = Senales.grabacion(
            Senales.quieto(segundos: 1),
            tipo: .trampa,
            reales: 0,
            etiqueta: "agitando en la cama"
        )
        #expect(g.nombreDeFichero.hasPrefix("grabacion-"))
        #expect(g.nombreDeFichero.contains("trampa"))
        #expect(g.nombreDeFichero.contains("agitando-en-la-cama"))
        #expect(g.nombreDeFichero.hasSuffix(".json"))
    }

    @Test("Un fichero corrupto no se lleva por delante la sesion entera")
    func ficheroCorrupto() throws {
        let carpeta = carpetaTemporal()
        defer { try? FileManager.default.removeItem(at: carpeta) }
        let almacen = AlmacenDeGrabaciones(carpeta: carpeta)
        try almacen.guarda(Senales.grabacion(Senales.sentadillas(repeticiones: 2), reales: 2))
        try Data("{ esto no es".utf8)
            .write(to: carpeta.appendingPathComponent("roto.json"))

        // Perder toda una manana de grabaciones por un JSON a medias seria una
        // forma absurda de fallar.
        #expect(almacen.todas().count == 1)
    }
}
