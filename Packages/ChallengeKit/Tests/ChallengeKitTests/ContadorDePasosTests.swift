import Testing
@testable import ChallengeKit

struct ContadorDePasosTests {
    @Test func cuentaTodaUnaTandaAunqueElPodometroLaEntregueDeGolpe() {
        var contador = ContadorDePasos(objetivo: 20)

        let primera = contador.registrar(acumulados: 12)
        #expect(primera)
        #expect(contador.contados == 12)
        let segunda = contador.registrar(acumulados: 20)
        #expect(segunda)
        #expect(contador.contados == 20)
        #expect(contador.terminado)
    }

    @Test func lasLecturasSonAcumuladasYNoIncrementos() {
        var contador = ContadorDePasos(objetivo: 20)

        _ = contador.registrar(acumulados: 4)
        _ = contador.registrar(acumulados: 9)
        #expect(contador.contados == 9)
    }

    @Test func ignoraDuplicadosYRetrocesos() {
        var contador = ContadorDePasos(objetivo: 20)

        _ = contador.registrar(acumulados: 7)
        let duplicado = contador.registrar(acumulados: 7)
        let retroceso = contador.registrar(acumulados: 3)
        #expect(!duplicado)
        #expect(!retroceso)
        #expect(contador.contados == 7)
    }

    @Test func nuncaSuperaElObjetivo() {
        var contador = ContadorDePasos(objetivo: 20)

        let avance = contador.registrar(acumulados: 60)
        #expect(avance)
        #expect(contador.contados == 20)
        #expect(contador.terminado)
    }
}
