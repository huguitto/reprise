import Testing
import Foundation
@testable import ChallengeKit

/// Lo que estos tests pueden y no pueden demostrar.
///
/// **Pueden**: que la fisica del algoritmo es la correcta —que un movimiento con
/// la forma de una sentadilla se cuenta y uno con la forma de una sacudida no—,
/// que no depende de como se sujete el movil y que reproducir una grabacion da
/// exactamente lo mismo que contar en vivo.
///
/// **No pueden**: dar por buenos los umbrales. Una persona no es una sinusoide.
/// El criterio del encargo (cinco sesiones, diez sentadillas, diez contadas) solo
/// se cierra con el iPhone en la mano y grabaciones de verdad; hasta entonces
/// esto es la red de seguridad, no la prueba.
@Suite("Algoritmo de sentadillas")
struct AlgoritmoSentadillasTests {

    // MARK: - Cuenta lo que tiene que contar

    @Test("Diez sentadillas de libro cuentan diez")
    func diezCuentanDiez() {
        #expect(Senales.cuenta(Senales.sentadillas(repeticiones: 10)) == 10)
    }

    @Test(
        "Cuenta bien a distintas profundidades y ritmos",
        arguments: [
            (0.30, 2.5), // poco fondo y despacio: alguien alto o con mala rodilla
            (0.45, 2.0), // el caso central
            (0.55, 1.6), // fondo y ritmo de quien ya esta despierto
        ]
    )
    func distintosCuerpos(amplitud: Double, periodo: Double) {
        let muestras = Senales.sentadillas(repeticiones: 10, amplitud: amplitud, periodo: periodo)
        #expect(Senales.cuenta(muestras) == 10)
    }

    @Test("Cuenta al terminar de subir, no al bajar")
    func cuentaAlSubir() {
        // Una sola sentadilla de 2 s que empieza en t = 1.
        let muestras = Senales.sentadillas(repeticiones: 1, preambulo: 1.0)
        var algoritmo = AlgoritmoSentadillas()
        var instante: Double?
        for m in muestras {
            let s = algoritmo.procesa(t: m.t, aceleracionVertical: m.a)
            if s.repeticionCompletada { instante = s.t }
        }
        let t = try? #require(instante)
        // El fondo cae en t = 2 (mitad del ciclo). Contar antes de eso seria
        // contar al bajar, que es justo lo que el encargo prohibe.
        #expect((t ?? 0) > 2.0)
    }

    @Test("El resultado no depende de como se sujete el movil")
    func daIgualLaOrientacion() {
        let muestras = Senales.sentadillas(repeticiones: 10)
        // Movil plano, de canto y boca abajo. La gravedad cae sobre un eje
        // distinto en cada caso y el conteo no puede enterarse.
        let orientaciones: [(x: Double, y: Double, z: Double)] = [
            (0, 0, -1), (0, -1, 0), (-1, 0, 0), (0.577, -0.577, -0.577),
        ]
        for o in orientaciones {
            let g = Senales.grabacion(muestras, reales: 10, orientacion: o)
            #expect(Reproductor.reproduce(g).contadas == 10)
        }
    }

    // MARK: - No cuenta lo que no tiene que contar

    @Test("Quieto no cuenta nada")
    func quietoNoCuenta() {
        #expect(Senales.cuenta(Senales.quieto(segundos: 30)) == 0)
    }

    @Test(
        "Agitar el movil sentado en la cama no llega a diez",
        arguments: [
            (0.05, 3.0), // muneca, rapido
            (0.10, 2.0), // brazo entero
            (0.15, 1.5), // sacudida ampulosa, ya casi coreografia
        ]
    )
    func agitarNoCuela(amplitud: Double, frecuencia: Double) {
        // Medio minuto agitando: mas de lo que nadie aguanta a las seis de la
        // manana antes de rendirse y levantarse.
        let muestras = Senales.agite(segundos: 30, amplitud: amplitud, frecuencia: frecuencia)
        let contadas = Senales.cuenta(muestras)
        #expect(contadas < 10, "agitando a \(frecuencia) Hz salieron \(contadas)")
    }

    @Test("Sentarse y quedarse sentado no cuenta")
    func sentarseNoCuenta() {
        // Bajada de 40 cm en 3 s y ahi se queda. Sin subida no hay repeticion,
        // por mucho que el filtro devuelva la altura a la linea base solo.
        var muestras: [(t: Double, a: Double)] = []
        let dt = 1 / Senales.frecuenciaHz
        var t = 0.0
        let periodo = 6.0 // medio ciclo = 3 s de bajada
        while t < 20 {
            let a = t < periodo / 2
                ? Senales.aceleracionDeSentadilla(t: t, amplitud: 0.40, periodo: periodo)
                : 0
            muestras.append((t, a))
            t += dt
        }
        #expect(Senales.cuenta(muestras) == 0)
    }

    @Test("Una flexion de rodillas de mentira no cuenta")
    func recorridoCortoNoCuenta() {
        // 8 cm de recorrido: el gesto de quien mueve el movil arriba y abajo
        // sentado, con el ritmo correcto pero sin bajar el cuerpo.
        let muestras = Senales.sentadillas(repeticiones: 10, amplitud: 0.08, periodo: 2.0)
        #expect(Senales.cuenta(muestras) < 10)
    }

    // MARK: - Contratos internos

    @Test("Reproducir una grabacion da lo mismo que contar en vivo")
    func reproducirEsIgualQueEnVivo() {
        let muestras = Senales.sentadillas(repeticiones: 7)
        let enVivo = Senales.cuenta(muestras)
        let grabada = Reproductor.reproduce(
            Senales.grabacion(muestras, reales: 7)
        ).contadas
        // Si esto se rompiera, calibrar sobre grabaciones no diria nada del
        // detector que corre en la mano.
        #expect(enVivo == grabada)
        #expect(enVivo == 7)
    }

    @Test("Reiniciar borra la cuenta anterior")
    func reiniciarBorra() {
        var algoritmo = AlgoritmoSentadillas()
        for m in Senales.sentadillas(repeticiones: 5) {
            _ = algoritmo.procesa(t: m.t, aceleracionVertical: m.a)
        }
        #expect(algoritmo.repeticiones == 5)
        algoritmo.reinicia()
        #expect(algoritmo.repeticiones == 0)
        #expect(algoritmo.fase == .reposo)
    }

    @Test("Un hueco en las muestras no inventa repeticiones")
    func hueco() {
        // La app se va a segundo plano diez segundos y vuelve. El paso de
        // integracion esta acotado justo para que ese salto no se convierta en
        // una sentadilla fantasma.
        var muestras = Senales.sentadillas(repeticiones: 3)
        let corte = muestras.count / 2
        let desplazadas = muestras[corte...].map { (t: $0.t + 10, a: $0.a) }
        muestras = Array(muestras[..<corte]) + desplazadas
        #expect(Senales.cuenta(muestras) <= 3)
    }
}

@Suite("Barrido de parametros")
struct BarridoTests {

    @Test("El barrido encuentra parametros que aciertan y frenan la trampa")
    func barrido() {
        let grabaciones = [
            Senales.grabacion(Senales.sentadillas(repeticiones: 10), reales: 10, etiqueta: "central"),
            Senales.grabacion(
                Senales.sentadillas(repeticiones: 10, amplitud: 0.30, periodo: 2.5),
                reales: 10, etiqueta: "poco-fondo"
            ),
            Senales.grabacion(
                Senales.agite(segundos: 30, amplitud: 0.10, frecuencia: 2.0),
                tipo: .trampa, reales: 0, etiqueta: "cama"
            ),
        ]
        let candidatos = Reproductor.barrido(grabaciones)
        let mejor = try? #require(candidatos.first)
        #expect(mejor?.faltantes == 0)
        // El filtro duro: ningun candidato propuesto puede dejar que agitar el
        // movil llegue a diez.
        #expect(candidatos.allSatisfy { $0.maximoEnTrampas < 10 })
    }

    @Test("Los faltantes pesan mas que los sobrantes")
    func faltantesPesanMas() {
        // Es la regla de producto convertida en aritmetica, y conviene que este
        // clavada con un test: si alguien la invierte sin querer, el detector
        // empieza a dejar tirada a gente que si esta haciendo el ejercicio.
        let falta = CandidatoDeParametros(
            parametros: .porDefecto, faltantes: 1, sobrantes: 0,
            maximoEnTrampas: 0, resultados: []
        )
        let sobra = CandidatoDeParametros(
            parametros: .porDefecto, faltantes: 0, sobrantes: 1,
            maximoEnTrampas: 0, resultados: []
        )
        #expect(falta.puntuacion > sobra.puntuacion)
    }
}
