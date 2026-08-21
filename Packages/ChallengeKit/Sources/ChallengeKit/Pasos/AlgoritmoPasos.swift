import Foundation

/// Cuenta pasos a partir de la aceleracion vertical, muestra a muestra.
///
/// No sabe nada de CoreMotion, igual que `AlgoritmoSentadillas`: come
/// `(t, aceleracionVertical)` y nada mas. Asi el mismo codigo exacto corre en
/// vivo dentro de `StepDetector` y en frio dentro de `ReproductorDePasos` sobre
/// una grabacion, y calibrar sobre grabaciones dice algo del detector de verdad.
///
/// ## Por que no lo hace `CMPedometer`
///
/// El podometro del sistema es una API de fitness diario: su cabecera promete
/// los datos *"on a best effort basis"*, confirma que estas caminando antes de
/// contar, descarta las rachas cortas e irregulares y entrega a tandas de varios
/// segundos. Para un resumen del dia es lo correcto; para una puerta de veinte
/// pasos que hay que cruzar despierto y girando por una habitacion, se queda
/// tan corto que hacian falta sesenta pasos para ver veinte (issue #35). Aqui la
/// senal se lee cruda a 50 Hz y el paso se cuenta cuando ocurre.
///
/// ## Como funciona
///
/// 1. **Quita el sesgo** con un paso alto, que es lo que deja la senal centrada
///    en cero aunque el movil se incline por el camino.
/// 2. **Suaviza** con un paso bajo de ~3,2 Hz. Por debajo cabe cualquier
///    caminata; por encima esta el temblor de la mano.
/// 3. **Estima la amplitud tipica** y de ella sale un umbral que se adapta:
///    caminar decidido y arrastrar los pies se diferencian en un factor de
///    cinco, y un umbral fijo o se come lo flojo o cuenta el ruido de lo fuerte.
/// 4. **Cuenta picos** con histeresis y un tiempo muerto entre pasos. El paso se
///    cuenta **al cerrar el pico**, no al abrirlo: son unas centesimas mas
///    tarde y a cambio no cuenta dos veces la misma cresta.
/// 5. **Descarta lo que es demasiado bruto para ser una pisada.** Contra lo que
///    parecia razonable, una sacudida no es rapida: las dos grabadas van al
///    ritmo de una zancada. Lo que las delata es la fuerza, y por diez veces:
///    andando, el pico filtrado no pasa de 1,8; agitando llega a 18,9. Ver
///    `ParametrosPaso.techoDePico`.
///
/// 6. **Descarta lo que gira como solo gira una mano.** La fuerza sola no
///    bastaba: mover la muneca sentado da picos de 1-3 m/s^2, o sea dentro de
///    lo que anda una persona, y contaba **16 pasos en 12 segundos**. Lo que lo
///    delata es que el movil *pivota*: andando, el cuerpo lo lleva y el vector
///    gravedad gira despacio; en una mano, el telefono da la vuelta. Ver
///    `ParametrosPaso.techoDeGiro`.
///
/// Lo que esto no frena, y esta escrito como test: mecer el movil suave y
/// sostenido al ritmo de una zancada **sin inclinarlo**. En esta senal eso no se
/// parece a andar, **es** andar. Cerrarlo del todo pediria saber si el telefono
/// se desplaza, y eso no lo dice ningun sensor del movil.
public struct AlgoritmoPasos: Sendable {

    /// Lo que el algoritmo sabe tras digerir una muestra. Lleva las senales
    /// derivadas ademas del contador porque la pantalla de calibracion las
    /// pinta: mirar la curva es la mitad del trabajo de afinar esto.
    public struct Salida: Sendable, Hashable {
        public let t: Double
        public let aceleracionFiltrada: Double
        /// El umbral vigente en esta muestra. Se guarda porque es adaptativo:
        /// sin pintarlo, la curva no explica por que un pico conto y otro no.
        public let umbral: Double
        /// Cuanto esta girando el movil, en grados por segundo y ya promediado.
        /// Vale 0 cuando la muestra no trae orientacion.
        public let giro: Double
        /// `true` solo en la muestra exacta en la que se cierra un paso.
        public let pasoCompletado: Bool
        public let pasos: Int
    }

    public private(set) var parametros: ParametrosPaso
    public private(set) var pasos = 0

    // Estado de los filtros. El suavizado son **dos** etapas iguales en
    // cascada, no una: la pendiente del corte es el doble de empinada y eso es
    // lo que separa de verdad una caminata de un agite. Con una sola etapa, una
    // sacudida a 6 Hz conserva la mitad de su energia y se cuela; con dos, le
    // queda un quinto.
    private var tAnterior: Double?
    private var sesgo = 0.0
    private var suavePrimeraEtapa = 0.0
    private var suave = 0.0
    private var amplitudSuave = 0.0
    private var amplitudCruda = 0.0

    // Giro del movil. `gravity` es un vector unitario que apunta al suelo, asi
    // que el angulo entre dos gravedades seguidas es lo que ha pivotado el
    // telefono. Se promedia porque un paso da tirones y lo que interesa es la
    // tendencia.
    private var gravedadAnterior: (x: Double, y: Double, z: Double)?
    private var giro = 0.0

    // Estado del pico en curso.
    private var enPico = false
    private var picoMaximo = 0.0
    private var giroEnPico = 0.0
    private var tUltimoPaso: Double?

    public init(parametros: ParametrosPaso = .porDefecto) {
        self.parametros = parametros
    }

    /// El liston que tiene que superar un pico para abrirse, en esta muestra.
    public var umbral: Double {
        max(parametros.umbralMinimo, amplitudSuave * parametros.factorDeUmbral)
    }

    /// Digiere una muestra. `aceleracionVertical` va en m/s^2 y **positiva hacia
    /// arriba**, ya descontada la gravedad (es la componente de
    /// `userAcceleration` sobre la vertical que marca `gravity`).
    /// Version sin orientacion: el veto por giro no se aplica.
    ///
    /// La usa el banco de estres sintetico, que genera aceleracion y no tiene
    /// de donde sacar una gravedad creible. Sin evidencia no se quita un paso.
    public mutating func procesa(t: Double, aceleracionVertical a: Double) -> Salida {
        procesa(t: t, aceleracionVertical: a, gravedad: nil)
    }

    /// Digiere una muestra con la orientacion del movil.
    ///
    /// `gravedad` es el vector unitario de `CMDeviceMotion.gravity`, en el marco
    /// del telefono. De el sale cuanto pivota el movil, que es lo unico que
    /// separa andar de mover la mano.
    public mutating func procesa(
        t: Double,
        aceleracionVertical a: Double,
        gravedad: (x: Double, y: Double, z: Double)?
    ) -> Salida {
        let p = parametros

        // Una sola muestra corrupta envenenaria los filtros para siempre: un
        // `NaN` se propaga a la media, al umbral y a la comparacion del pico, y
        // a partir de ahi el contador se queda clavado con la alarma sonando y
        // sin salida. Medido en el banco de estres: tras un NaN, cuarenta pasos
        // de verdad contaban cero. Se tira la muestra y se sigue.
        guard a.isFinite, t.isFinite else { return salida(t: t, pasoCompletado: false) }

        guard let anterior = tAnterior else {
            // Primera muestra: solo sirve para sembrar el sesgo y el reloj.
            tAnterior = t
            sesgo = a
            gravedadAnterior = gravedad
            return salida(t: t, pasoCompletado: false)
        }
        // Un hueco largo (la app en segundo plano, el sensor tosiendo) no debe
        // meter un salto en los filtros: se acota el paso.
        let dt = min(max(t - anterior, 1e-4), 0.2)
        tAnterior = t

        // 0. Cuanto ha pivotado el movil. El coseno se acota antes del arco
        //    porque el producto escalar de dos unitarios se sale de [-1, 1] por
        //    redondeo, y `acos` de 1.0000001 es NaN: eso envenenaria el
        //    promedio para siempre, igual que pasaba con la aceleracion.
        if let g = gravedad {
            if let previa = gravedadAnterior {
                let coseno = min(1, max(-1, previa.x * g.x + previa.y * g.y + previa.z * g.z))
                let grados = acos(coseno) * 180 / .pi / dt
                if grados.isFinite {
                    giro += (grados - giro) * min(1, dt / p.tauGiro)
                }
            }
            gravedadAnterior = g
        }

        // 1. Paso alto: fuera el sesgo.
        sesgo += (a - sesgo) * min(1, dt / p.tauSesgo)
        let sinSesgo = a - sesgo

        // 2. Paso bajo en dos etapas: fuera el temblor rapido.
        let alfa = min(1, dt / p.tauSuavizado)
        suavePrimeraEtapa += (sinSesgo - suavePrimeraEtapa) * alfa
        suave += (suavePrimeraEtapa - suave) * alfa

        // 3. Amplitud tipica de las dos senales. La cruda solo sirve para
        //    comparar: si casi toda la energia se ha quedado en el filtro, lo
        //    que hay en la mano es un agite y no una caminata.
        let k = min(1, dt / p.tauAmplitud)
        amplitudSuave += (abs(suave) - amplitudSuave) * k
        amplitudCruda += (abs(sinSesgo) - amplitudCruda) * k

        // 4. Picos.
        var completado = false
        let liston = umbral
        if enPico {
            picoMaximo = max(picoMaximo, suave)
            giroEnPico = max(giroEnPico, giro)
            if suave < liston * p.fraccionDeCierre {
                enPico = false
                if aceptaElPaso(t: t) {
                    pasos += 1
                    tUltimoPaso = t
                    completado = true
                }
            }
        } else if suave > liston {
            enPico = true
            picoMaximo = suave
            giroEnPico = giro
        }

        return salida(t: t, pasoCompletado: completado)
    }

    /// Las razones para no contar un pico ya formado: que llegue pegado al
    /// anterior —el rebote de un mismo impacto—, que sea demasiado violento para
    /// ser una pisada, que el movil estuviera pivotando como solo pivota en una
    /// mano, o que la senal sea demasiado rapida para ser una caminata.
    private func aceptaElPaso(t: Double) -> Bool {
        if let ultimo = tUltimoPaso, t - ultimo < parametros.intervaloMinimo {
            return false
        }
        if picoMaximo > parametros.techoDePico { return false }
        // Sin orientacion no hay veto: `giroEnPico` se queda en cero.
        if giroEnPico > parametros.techoDeGiro { return false }
        return esCaminata
    }

    /// Cuanta de la energia sobrevive al suavizado. Con el movil quieto las dos
    /// amplitudes son ruido diminuto y el cociente no significa nada, asi que
    /// por debajo del umbral minimo se da por bueno: alli no hay pico que contar
    /// de todas formas.
    private var esCaminata: Bool {
        guard amplitudCruda > parametros.umbralMinimo else { return true }
        return amplitudSuave >= amplitudCruda * parametros.fraccionDeBajaFrecuencia
    }

    private func salida(t: Double, pasoCompletado: Bool) -> Salida {
        Salida(
            t: t,
            aceleracionFiltrada: suave,
            umbral: umbral,
            giro: giro,
            pasoCompletado: pasoCompletado,
            pasos: pasos
        )
    }

    /// Vuelve a cero. Se usa al arrancar un reto: nada de lo anterior cuenta.
    public mutating func reinicia() {
        pasos = 0
        tAnterior = nil
        sesgo = 0
        suavePrimeraEtapa = 0
        suave = 0
        amplitudSuave = 0
        amplitudCruda = 0
        gravedadAnterior = nil
        giro = 0
        enPico = false
        picoMaximo = 0
        giroEnPico = 0
        tUltimoPaso = nil
    }
}
