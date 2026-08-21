import Testing
@testable import ChallengeKit

@Suite("Fusion de las dos cuentas de pasos")
struct FusionDePasosTests {

    @Test func mandaLaCuentaPropiaCuandoVaPorDelante() {
        var fusion = FusionDePasos(objetivo: 20)

        for _ in 0..<12 { _ = fusion.paso() }
        #expect(fusion.contados == 12)

        // El podometro llega tarde, como siempre, y no resta.
        let tarde = fusion.podometro(acumulados: 4)
        #expect(!tarde.cambiaElTotal)
        #expect(fusion.contados == 12)
    }

    @Test func elPodometroSumaSiSeAdelanta() {
        var fusion = FusionDePasos(objetivo: 20)

        _ = fusion.paso()
        let seAdelanta = fusion.podometro(acumulados: 6)
        #expect(seAdelanta.cambiaElTotal)
        #expect(fusion.contados == 6)

        // Y a partir de ahi la nuestra tiene que alcanzarlo antes de mover nada.
        // Pero cada uno de esos pasos sigue siendo un paso de verdad: quien anda
        // no puede aparecer como parado solo porque el numero este esperando.
        for _ in 0..<5 {
            let avance = fusion.paso()
            #expect(avance.hayPasos)
            #expect(!avance.cambiaElTotal)
        }
        #expect(fusion.contados == 6)
        let alcanza = fusion.paso()
        #expect(alcanza.cambiaElTotal)
        #expect(fusion.contados == 7)
    }

    @Test func lasLecturasDelPodometroSonAcumuladasYNoIncrementos() {
        var fusion = FusionDePasos(objetivo: 20)

        _ = fusion.podometro(acumulados: 4)
        _ = fusion.podometro(acumulados: 9)
        #expect(fusion.contados == 9)
    }

    @Test func ignoraDuplicadosYRetrocesosDelPodometro() {
        var fusion = FusionDePasos(objetivo: 20)

        _ = fusion.podometro(acumulados: 7)
        let duplicado = fusion.podometro(acumulados: 7)
        let retroceso = fusion.podometro(acumulados: 3)
        #expect(!duplicado.hayPasos)
        #expect(!retroceso.hayPasos)
        #expect(fusion.contados == 7)
    }

    @Test func nuncaSuperaElObjetivo() {
        var fusion = FusionDePasos(objetivo: 20)

        let avanza = fusion.podometro(acumulados: 60)
        #expect(avanza.cambiaElTotal)
        #expect(fusion.contados == 20)
        #expect(fusion.terminado)

        // Y una vez llegado, seguir andando no mueve el numero.
        let deMas = fusion.paso()
        #expect(!deMas.cambiaElTotal)
        #expect(fusion.contados == 20)
    }
}
