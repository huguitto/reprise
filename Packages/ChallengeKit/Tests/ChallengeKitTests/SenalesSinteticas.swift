import Foundation
@testable import ChallengeKit

/// Generador de senales de mentira para los tests.
///
/// No sustituye a grabar sentadillas de verdad —una persona real no es una
/// sinusoide— pero si contesta gratis a la pregunta previa: *dado un movimiento
/// con la fisica correcta, ¿el algoritmo lo ve?* Si falla aqui, fallara en la
/// mano, y descubrirlo cuesta un segundo en vez de una sesion.
enum Senales {

    static let frecuenciaHz: Double = 50

    /// Una bajada-y-subida completa como un coseno: sale de la linea base, baja
    /// `amplitud` metros y vuelve, en `periodo` segundos.
    ///
    /// La aceleracion es la segunda derivada de esa altura, asi que la senal que
    /// sale de aqui es exactamente la que mediria un acelerometro perfecto.
    static func aceleracionDeSentadilla(t: Double, amplitud: Double, periodo: Double) -> Double {
        let w = 2 * Double.pi / periodo
        return -(amplitud / 2) * w * w * cos(w * t)
    }

    /// Vibracion pura: agitar el movil. Amplitud pequena, frecuencia alta.
    ///
    /// Va con seno y no con coseno para que arranque parado, como arranca una
    /// mano de verdad. Con coseno la senal empieza en su pico y mete un
    /// transitorio de arranque que no existe en el movil y que solo sirve para
    /// que el test se mienta a si mismo.
    static func aceleracionDeAgite(t: Double, amplitud: Double, frecuencia: Double) -> Double {
        let w = 2 * Double.pi * frecuencia
        return -amplitud * w * w * sin(w * t)
    }

    /// `repeticiones` sentadillas seguidas con `descanso` segundos entre ellas.
    static func sentadillas(
        repeticiones: Int,
        amplitud: Double = 0.45,
        periodo: Double = 2.0,
        descanso: Double = 0.6,
        preambulo: Double = 1.0
    ) -> [(t: Double, a: Double)] {
        var muestras: [(Double, Double)] = []
        let dt = 1 / frecuenciaHz
        let ciclo = periodo + descanso
        let total = preambulo + Double(repeticiones) * ciclo + 1.0
        var t = 0.0
        while t < total {
            let desdeElInicio = t - preambulo
            var a = 0.0
            if desdeElInicio >= 0 {
                let indice = Int(desdeElInicio / ciclo)
                let dentro = desdeElInicio - Double(indice) * ciclo
                if indice < repeticiones && dentro < periodo {
                    a = aceleracionDeSentadilla(t: dentro, amplitud: amplitud, periodo: periodo)
                }
            }
            muestras.append((t, a))
            t += dt
        }
        return muestras.map { (t: $0.0, a: $0.1) }
    }

    static func agite(
        segundos: Double,
        amplitud: Double = 0.05,
        frecuencia: Double = 3.0
    ) -> [(t: Double, a: Double)] {
        var muestras: [(t: Double, a: Double)] = []
        let dt = 1 / frecuenciaHz
        var t = 0.0
        while t < segundos {
            muestras.append((t, aceleracionDeAgite(t: t, amplitud: amplitud, frecuencia: frecuencia)))
            t += dt
        }
        return muestras
    }

    static func quieto(segundos: Double) -> [(t: Double, a: Double)] {
        var muestras: [(t: Double, a: Double)] = []
        let dt = 1 / frecuenciaHz
        var t = 0.0
        while t < segundos {
            muestras.append((t, 0))
            t += dt
        }
        return muestras
    }

    static func cuenta(
        _ muestras: [(t: Double, a: Double)],
        parametros: ParametrosSentadilla = .porDefecto
    ) -> Int {
        var algoritmo = AlgoritmoSentadillas(parametros: parametros)
        for m in muestras {
            _ = algoritmo.procesa(t: m.t, aceleracionVertical: m.a)
        }
        return algoritmo.repeticiones
    }

    /// Empaqueta la senal como una `Grabacion` de verdad, con los vectores
    /// crudos, para probar tambien el camino de reproduccion.
    ///
    /// `orientacion` decide sobre que eje del movil cae la gravedad. Sirve para
    /// comprobar que el resultado no depende de como se sujete el telefono, que
    /// es la mitad del requisito de "mano derecha y mano izquierda".
    static func grabacion(
        _ muestras: [(t: Double, a: Double)],
        tipo: Grabacion.Tipo = .sentadillas,
        reales: Int,
        etiqueta: String = "sintetica",
        orientacion: (x: Double, y: Double, z: Double) = (0, 0, -1)
    ) -> Grabacion {
        let g = orientacion
        let norma = (g.x * g.x + g.y * g.y + g.z * g.z).squareRoot()
        let u = (x: g.x / norma, y: g.y / norma, z: g.z / norma)
        return Grabacion(
            tipo: tipo,
            repeticionesReales: reales,
            etiqueta: etiqueta,
            frecuenciaHz: frecuenciaHz,
            muestras: muestras.map { m in
                // La aceleracion vertical se reparte sobre los ejes segun la
                // orientacion, y va en g porque es lo que da CoreMotion.
                let enG = -m.a / 9.80665
                return MuestraDeMovimiento(
                    t: m.t,
                    ax: enG * u.x, ay: enG * u.y, az: enG * u.z,
                    gx: u.x, gy: u.y, gz: u.z
                )
            }
        )
    }
}
