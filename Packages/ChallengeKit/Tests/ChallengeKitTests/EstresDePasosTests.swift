import Testing
import Foundation
import AlarmCore
@testable import ChallengeKit

/// Banco de estres del contador de pasos.
///
/// Los tests de `AlgoritmoPasosTests` prueban senales limpias: una sinusoide
/// perfecta a cadencia constante. Nadie anda asi, y menos a las seis de la
/// manana. Aqui se generan cientos de caminatas con todo lo que ensucia la senal
/// de verdad —el paso desigual, el ruido del sensor, el movil girando en la
/// mano, muestras que llegan tarde o no llegan— y se mide **la unica cifra que
/// le importa al usuario**: cuantos pasos de verdad tiene que dar para que la
/// pantalla marque 20.
///
/// Esa cifra es la del issue #35. Con `CMPedometer` eran sesenta.
enum Estres {

    /// Una caminata con todos los defectos de una de verdad.
    struct Caminata {
        var pasos = 40
        /// Pico de la pisada, m/s^2. 2 es andar normal con el movil en la mano.
        var amplitud = 2.0
        /// Pasos por segundo.
        var cadencia = 2.0
        /// Cuanto varia el ritmo de un paso al siguiente, en tanto por uno.
        var irregularidadDeRitmo = 0.0
        /// Cuanto varia la fuerza de una pisada a la siguiente.
        var irregularidadDeFuerza = 0.0
        /// Ruido del sensor, m/s^2 de pico.
        var ruido = 0.0
        /// Deriva lenta: el movil girando en la mano mueve la proyeccion de la
        /// gravedad y mete un vaiven que el paso alto tiene que comerse.
        var deriva = 0.0
        var frecuenciaDeDeriva = 0.1
        /// Cuanto se aparta el muestreo del 1/50 nominal, en tanto por uno.
        var jitterDeMuestreo = 0.0
        /// Probabilidad de que una muestra no llegue.
        var muestrasPerdidas = 0.0
        var preambulo = 1.0
    }

    /// Una muestra generada, con la cuenta de pasos que la persona lleva dados
    /// **de verdad** en ese instante.
    struct Muestra {
        let t: Double
        let a: Double
        let realesHastaAqui: Int
    }

    static func genera(_ c: Caminata, semilla: UInt64) -> [Muestra] {
        var azar = RuidoRepetible(semilla: semilla)

        // Cada paso tiene su propio periodo y su propia fuerza.
        var inicios: [Double] = []
        var periodos: [Double] = []
        var amplitudes: [Double] = []
        var t = c.preambulo
        for _ in 0..<c.pasos {
            let periodo = (1 / c.cadencia)
                * (1 + azar.siguiente(amplitud: c.irregularidadDeRitmo))
            inicios.append(t)
            periodos.append(max(periodo, 0.15))
            amplitudes.append(
                max(0, c.amplitud * (1 + azar.siguiente(amplitud: c.irregularidadDeFuerza)))
            )
            t += max(periodo, 0.15)
        }
        let finDeLaCaminata = t
        let total = finDeLaCaminata + 1.0

        var muestras: [Muestra] = []
        let dtNominal = 1 / Senales.frecuenciaHz
        var reloj = 0.0
        while reloj < total {
            if azar.uniforme() >= c.muestrasPerdidas {
                var a = 0.0
                // Que paso esta en curso.
                if let i = inicios.lastIndex(where: { $0 <= reloj }),
                   reloj < inicios[i] + periodos[i] {
                    let dentro = reloj - inicios[i]
                    a = amplitudes[i] * sin(2 * .pi * dentro / periodos[i])
                }
                a += c.deriva * sin(2 * .pi * c.frecuenciaDeDeriva * reloj)
                a += azar.gaussiano(amplitud: c.ruido)

                let dados = inicios.indices.filter { inicios[$0] + periodos[$0] <= reloj }.count
                muestras.append(Muestra(t: reloj, a: a, realesHastaAqui: dados))
            }
            reloj += dtNominal * (1 + azar.siguiente(amplitud: c.jitterDeMuestreo))
        }
        return muestras
    }

    struct Veredicto {
        /// Pasos de verdad que hubo que dar para que la pantalla marcara el
        /// objetivo. `nil` si nunca llego: eso es quedarse encerrado.
        let realesParaLlegar: Int?
        let contadosAlFinal: Int
        let realesTotales: Int

        /// El coste del issue #35, en veces. 1.0 es contar perfecto; 3.0 es lo
        /// que hacia el podometro.
        var factor: Double? {
            guard let r = realesParaLlegar else { return nil }
            return Double(r) / 20.0
        }
    }

    static func mide(
        _ c: Caminata,
        semilla: UInt64,
        objetivo: Int = ChallengeType.pasos.goal,
        parametros: ParametrosPaso = .porDefecto
    ) -> Veredicto {
        var algoritmo = AlgoritmoPasos(parametros: parametros)
        var realesParaLlegar: Int?
        let muestras = genera(c, semilla: semilla)
        for m in muestras {
            let salida = algoritmo.procesa(t: m.t, aceleracionVertical: m.a)
            if realesParaLlegar == nil, salida.pasos >= objetivo {
                realesParaLlegar = max(m.realesHastaAqui, 1)
            }
        }
        return Veredicto(
            realesParaLlegar: realesParaLlegar,
            contadosAlFinal: algoritmo.pasos,
            realesTotales: muestras.last?.realesHastaAqui ?? 0
        )
    }
}

extension RuidoRepetible {
    /// Uniforme en [0, 1).
    mutating func uniforme() -> Double { (siguiente(amplitud: 1) + 1) / 2 }

    /// Campana pobre pero suficiente: la suma de tres uniformes ya no tiene las
    /// esquinas de una sola, y el ruido del acelerometro no las tiene.
    mutating func gaussiano(amplitud: Double) -> Double {
        guard amplitud > 0 else { return 0 }
        return (siguiente(amplitud: amplitud)
            + siguiente(amplitud: amplitud)
            + siguiente(amplitud: amplitud)) / 3
    }
}

@Suite("Estres del contador de pasos")
struct EstresDePasosTests {

    /// El caso central, repetido con doscientas semillas distintas: alguien
    /// andando normal por una habitacion con el movil en la mano.
    ///
    /// El liston son **25 pasos reales para marcar 20**. No 20: perder alguno
    /// por el camino es inevitable y aceptable. Lo que no lo es son los 60 del
    /// issue #35.
    @Test func andarNormalDoscientasVeces() {
        var peor = 0
        var encerrados = 0
        var suma = 0
        for semilla in 0..<200 {
            let v = Estres.mide(
                Estres.Caminata(
                    amplitud: 2.0, cadencia: 2.0,
                    irregularidadDeRitmo: 0.2, irregularidadDeFuerza: 0.35,
                    ruido: 0.08, deriva: 0.4,
                    jitterDeMuestreo: 0.1, muestrasPerdidas: 0.01
                ),
                semilla: UInt64(semilla) &* 2_654_435_761 &+ 1
            )
            guard let reales = v.realesParaLlegar else { encerrados += 1; continue }
            peor = max(peor, reales)
            suma += reales
        }
        #expect(encerrados == 0, "\(encerrados) caminatas de 200 nunca llegaron a 20")
        #expect(peor <= 25, "la peor de 200 necesito \(peor) pasos reales para marcar 20")
        print("[estres] andar normal: media \(Double(suma) / 200) reales para 20, peor \(peor)")
    }

    /// El abanico entero de como se anda, cruzado con lo que ensucia la senal.
    /// Aqui no se busca la media: se busca la combinacion que deja a alguien
    /// encerrado.
    @Test func ningunaFormaDeAndarDejaEncerrado() {
        var fallos: [String] = []
        var peorGlobal = (0, "")
        var semilla: UInt64 = 1
        for amplitud in [0.6, 1.0, 2.0, 4.0, 6.0] {
            for cadencia in [1.3, 1.8, 2.3, 3.0] {
                for suciedad in [0.0, 0.5, 1.0] {
                    semilla = semilla &* 6_364_136_223_846_793_005 &+ 1
                    let c = Estres.Caminata(
                        amplitud: amplitud, cadencia: cadencia,
                        irregularidadDeRitmo: 0.25 * suciedad,
                        irregularidadDeFuerza: 0.5 * suciedad,
                        ruido: 0.05 + 0.15 * suciedad,
                        deriva: 1.0 * suciedad,
                        jitterDeMuestreo: 0.15 * suciedad,
                        muestrasPerdidas: 0.03 * suciedad
                    )
                    let v = Estres.mide(c, semilla: semilla)
                    let caso = "amp \(amplitud), cad \(cadencia), suciedad \(suciedad)"
                    guard let reales = v.realesParaLlegar else {
                        fallos.append("ENCERRADO en \(caso): conto \(v.contadosAlFinal) de \(v.realesTotales)")
                        continue
                    }
                    if reales > peorGlobal.0 { peorGlobal = (reales, caso) }
                    if reales > 33 { fallos.append("\(reales) reales para 20 en \(caso)") }
                }
            }
        }
        print("[estres] peor del abanico: \(peorGlobal.0) reales para 20 — \(peorGlobal.1)")
        #expect(fallos.isEmpty, "\(fallos.joined(separator: "; "))")
    }

    /// El agite que **si** se puede frenar, que no es todo.
    ///
    /// Frenar hay dos formas y las dos estan aqui: por rapido —el temblor de
    /// muneca, que el suavizado mata— y por bruto y despareja —la sacudida de
    /// verdad, la unica grabada—. Lo que no hay forma de frenar esta abajo.
    @Test(arguments: [5.0, 6.0, 8.0, 10.0])
    func elTemblorRapidoNoAbreLaPuerta(frecuencia: Double) {
        for amplitud in [0.005, 0.02, 0.05, 0.2] {
            let contados = Senales.cuentaPasos(
                Senales.agite(segundos: 40, amplitud: amplitud, frecuencia: frecuencia)
            )
            #expect(
                contados < ChallengeType.pasos.goal,
                "a \(frecuencia) Hz con recorrido \(amplitud) m llego a \(contados)"
            )
        }
    }

    /// La sacudida de verdad: la unica grabada, que es a tirones.
    ///
    /// Aqui no vale una sinusoide sintetica. Una sacudida perfectamente regular
    /// sube la amplitud tipica en la misma proporcion que sus picos, asi que por
    /// fuerza no se distingue de alguien que anda pisando muy fuerte — y no se
    /// distingue porque **no son distintas** en esta senal. Lo que delata a la
    /// persona real sacudiendo el movil es que va a tirones: picos de 15,3 con
    /// una mediana de 2,4. Eso si se puede pedir, y se pide contra el fichero.
    @Test(
        "La grabacion de trampa real no llega al objetivo",
        .enabled(if: GrabacionesReales.hayGrabaciones)
    )
    func laTrampaGrabadaNoAbreLaPuerta() {
        for grabacion in GrabacionesReales.trampas {
            let r = ReproductorDePasos.reproduce(grabacion, parametros: .porDefecto, conTraza: false)
            #expect(
                r.contados < ChallengeType.pasos.goal,
                "\(grabacion.etiqueta): la trampa llego a \(r.contados) de \(ChallengeType.pasos.goal)"
            )
        }
    }

    /// El otro lado del techo: hasta donde llega una pisada de verdad, no se
    /// pierde ni una.
    ///
    /// El 21/08/2026 se midio por fin, con el iPhone en la mano: el pico crudo
    /// mas fuerte de dos caminatas de veinte pasos es **3,9 m/s^2**, y ya
    /// filtrado, 1,8. Este test cubre hasta 5, que es margen de sobra sobre lo
    /// unico que se ha visto.
    ///
    /// Y aqui hubo una leccion que conviene no repetir: antes de tener estas
    /// grabaciones, este mismo test pedia contar bien hasta 20 m/s^2 —una
    /// "pisada fuerte" que parecia razonable— y para satisfacerlo se llego a
    /// añadir un parametro entero al algoritmo. Los ficheros dijeron que esa
    /// pisada no existe con el movil en la mano, y que la trampa si vive justo
    /// ahi arriba. El parametro se fue el mismo dia.
    @Test(arguments: [1.0, 2.0, 3.0, 4.0, 5.0])
    func laPisadaMasFuerteQueSeHaMedidoCuentaEntera(amplitud: Double) {
        let contados = Senales.cuentaPasos(Senales.pasos(cantidad: 20, amplitud: amplitud))
        #expect(
            contados >= 19,
            "pisando a \(amplitud) m/s^2 solo conto \(contados) de 20"
        )
    }

    /// **Lo que no se puede frenar, escrito para que nadie se lleve la sorpresa.**
    ///
    /// Mecer el movil de forma suave y sostenida al ritmo de una zancada
    /// produce, en la aceleracion vertical, la misma senal que andar — y da
    /// igual con cuanta fuerza se meza, porque lo que se compara es cada pico
    /// contra la fuerza tipica de quien lo hace. No se parece: **es** la
    /// misma. Ningun umbral sobre esta senal separa las dos cosas, y por eso este
    /// test afirma que cuela en vez de fingir que no.
    ///
    /// No se arregla apretando: apretar hasta que esto no cuele deja fuera a
    /// quien anda de verdad, que cuesta el triple. Se arreglaria mirando otra
    /// senal —la rotacion del movil, que al andar acompana y meciendo no—, y eso
    /// es alcance nuevo: `docs/decisiones-producto.md` descarta el antifraude.
    ///
    /// Si algun dia se cierra, este test cambia de signo y se entera todo el
    /// mundo, que es justo para lo que esta.
    @Test func mecerElMovilAlRitmoDeUnaZancadaSiCuela() {
        let recorrido = 3.0 / pow(2 * Double.pi * 2.0, 2)   // 3 m/s^2 a 2 Hz
        let contados = Senales.cuentaPasos(
            Senales.agite(segundos: 40, amplitud: recorrido, frecuencia: 2.0)
        )
        #expect(
            contados >= ChallengeType.pasos.goal,
            "esto colaba y ahora no: si es a proposito, cambia el test y el LEEME"
        )
    }

    /// Basura que el sensor puede entregar y que no puede tumbar el contador.
    /// Un `NaN` que envenene los filtros deja al usuario con la alarma sonando y
    /// el numero congelado para siempre, que es el peor final posible.
    @Test func laBasuraDelSensorNoRompeElContador() {
        let casos: [(String, [(t: Double, a: Double)])] = [
            ("un NaN suelto", [(0.0, 0.0), (0.02, Double.nan)]),
            ("un infinito suelto", [(0.0, 0.0), (0.02, Double.infinity)]),
            ("dos muestras con el mismo instante", [(0.0, 0.0), (0.0, 1.0), (0.0, 2.0)]),
            ("el reloj hacia atras", [(5.0, 0.0), (1.0, 2.0), (0.5, -2.0)]),
            ("un hueco de treinta segundos", [(0.0, 0.0), (30.0, 3.0), (30.02, -3.0)])
        ]
        for (nombre, prefijo) in casos {
            var algoritmo = AlgoritmoPasos()
            for m in prefijo { _ = algoritmo.procesa(t: m.t, aceleracionVertical: m.a) }

            // Y despues de la basura, la persona anda de verdad.
            let arranque = (prefijo.last?.t ?? 0) + 0.02
            var conto = 0
            for m in Senales.pasos(cantidad: 40) {
                let salida = algoritmo.procesa(t: arranque + m.t, aceleracionVertical: m.a)
                conto = salida.pasos
            }
            #expect(
                conto >= ChallengeType.pasos.goal,
                "tras \(nombre) el contador se quedo en \(conto) con 40 pasos dados"
            )
        }
    }
}
