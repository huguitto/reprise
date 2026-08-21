import Testing
import Foundation
import AlarmCore
@testable import ChallengeKit

/// Lo que se le exige al contador de pasos, en orden de importancia.
///
/// El primero es el que existe por el issue #35: sesenta pasos para ver veinte.
/// Con `CMPedometer` no habia forma de escribir este test, porque el que contaba
/// era el sistema; ahora el que cuenta es codigo nuestro y se le puede pedir
/// cuentas sin salir del Mac.
@Suite("Contador de pasos")
struct AlgoritmoPasosTests {

    @Test func cuentaLosVeinteAndandoNormal() {
        #expect(Senales.cuentaPasos(Senales.pasos(cantidad: 20)) == 20)
    }

    /// El fallo caro: quedarse corto con quien esta andando de verdad.
    ///
    /// Se recorre el abanico entero de como anda una persona a las seis de la
    /// manana —desde arrastrar los pies hasta salir disparada— y en ninguna
    /// combinacion se permite contar de menos.
    @Test(arguments: [0.6, 1.0, 2.0, 4.0], [1.4, 2.0, 2.6])
    func noSeQuedaCortoConNingunaFormaDeAndar(amplitud: Double, cadencia: Double) {
        let contados = Senales.cuentaPasos(
            Senales.pasos(cantidad: 20, amplitud: amplitud, cadencia: cadencia)
        )
        #expect(
            contados == 20,
            "amplitud \(amplitud) m/s^2 a \(cadencia) pasos/s: conto \(contados) de 20"
        )
    }

    /// El sintoma del issue #35, escrito como test: si hicieran falta sesenta
    /// pasos para veinte, esto contaria 20 de 60 y fallaria.
    @Test func sesentaPasosNoSeQuedanEnVeinte() {
        let contados = Senales.cuentaPasos(Senales.pasos(cantidad: 60))
        #expect(contados == 60, "conto \(contados) de 60 pasos dados")
    }

    @Test func elMovilQuietoNoCuentaNada() {
        #expect(Senales.cuentaPasos(Senales.quieto(segundos: 20)) == 0)
    }

    /// El ruido del acelerometro con el movil apoyado en la mesilla se mueve en
    /// centesimas de m/s^2. Ni una decima de eso puede ser un paso.
    @Test func elRuidoDelSensorNoCuentaNada() {
        var generador = RuidoRepetible(semilla: 20_260_821)
        let dt = 1 / Senales.frecuenciaHz
        let muestras = (0..<Int(30 * Senales.frecuenciaHz)).map { i in
            (t: Double(i) * dt, a: generador.siguiente(amplitud: 0.05))
        }
        #expect(Senales.cuentaPasos(muestras) == 0)
    }

    /// Agitar el movil en la cama no resuelve el reto. No es el tramposo listo
    /// —ese esta descartado por producto— sino el reflejo de las seis de la
    /// manana: sacudir el telefono a ver si cuela.
    @Test(arguments: [5.0, 6.0, 8.0])
    func agitarElMovilNoLlegaAlObjetivo(frecuencia: Double) {
        let contados = Senales.cuentaPasos(
            Senales.agite(segundos: 30, amplitud: 0.05, frecuencia: frecuencia)
        )
        #expect(
            contados < ChallengeType.pasos.goal,
            "agitando a \(frecuencia) Hz llego a \(contados)"
        )
    }

    /// El otro lado del techo de pico: pisar fuerte sigue siendo pisar. 6 m/s^2
    /// es un pisoton con el movil bien agarrado, muy por encima de los 2-5 de
    /// andar normal, y no puede perderse ni uno.
    @Test func pisarFuerteSigueContando() {
        #expect(Senales.cuentaPasos(Senales.pasos(cantidad: 20, amplitud: 6.0)) == 20)
    }

    /// El otro lado del anti-agite: correr son 3 pasos/s y tiene que contar.
    /// Si este test y el de arriba se pelean, gana este.
    @Test func correrSigueSiendoAndar() {
        #expect(Senales.cuentaPasos(Senales.pasos(cantidad: 20, cadencia: 3.0)) == 20)
    }

    /// Contar desde el primer paso es la mitad del arreglo: el podometro del
    /// sistema necesitaba confirmar la caminata antes de dar nada por bueno, y
    /// esa espera es la que se veia como "no cuenta".
    @Test func elPrimerPasoCuentaEnMenosDeUnSegundo() {
        var algoritmo = AlgoritmoPasos()
        var instante: Double?
        for m in Senales.pasos(cantidad: 20, preambulo: 0) {
            let salida = algoritmo.procesa(t: m.t, aceleracionVertical: m.a)
            if salida.pasoCompletado, instante == nil { instante = salida.t }
        }
        #expect(instante != nil)
        #expect((instante ?? .infinity) < 1.0, "el primer paso tardo \(instante ?? -1) s")
    }

    @Test func reiniciarDejaElContadorComoNuevo() {
        var algoritmo = AlgoritmoPasos()
        for m in Senales.pasos(cantidad: 5) {
            _ = algoritmo.procesa(t: m.t, aceleracionVertical: m.a)
        }
        #expect(algoritmo.pasos == 5)

        algoritmo.reinicia()
        #expect(algoritmo.pasos == 0)
        for m in Senales.pasos(cantidad: 7) {
            _ = algoritmo.procesa(t: m.t, aceleracionVertical: m.a)
        }
        #expect(algoritmo.pasos == 7)
    }

    /// La senal de un reto real no llega en una sola tanda seguida: se anda, se
    /// para uno a mirar el movil, se gira y se sigue. Eso es exactamente lo que
    /// el podometro del sistema descartaba por "racha corta".
    @Test func andarATirones() {
        var muestras: [(t: Double, a: Double)] = []
        var t = 0.0
        for _ in 0..<5 {
            for m in Senales.pasos(cantidad: 4, preambulo: 0, cola: 0) {
                muestras.append((t + m.t, m.a))
            }
            t = (muestras.last?.t ?? t) + 1 / Senales.frecuenciaHz
            for m in Senales.quieto(segundos: 1.5) {
                muestras.append((t + m.t, m.a))
            }
            t = (muestras.last?.t ?? t) + 1 / Senales.frecuenciaHz
        }
        let contados = Senales.cuentaPasos(muestras)
        #expect(contados == 20, "cinco tandas de cuatro pasos contaron \(contados)")
    }
}

/// Ruido pseudoaleatorio reproducible. `Double.random` cambiaria de un dia para
/// otro y un test que a veces pasa no sirve de nada.
struct RuidoRepetible {
    private var estado: UInt64

    init(semilla: UInt64) {
        estado = semilla
    }

    mutating func siguiente(amplitud: Double) -> Double {
        estado = estado &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let normalizado = Double(estado >> 11) / Double(1 << 53)
        return (normalizado * 2 - 1) * amplitud
    }
}
