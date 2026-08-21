import Foundation

/// Cuenta sentadillas a partir de la aceleracion vertical, muestra a muestra.
///
/// No sabe nada de CoreMotion a proposito: come `(t, aceleracionVertical)` y
/// nada mas. Asi el mismo codigo exacto corre en vivo dentro de `SquatDetector`
/// y en frio dentro del `Reproductor` sobre una grabacion. Si fueran dos
/// implementaciones, calibrar sobre las grabaciones no demostraria nada del
/// detector de verdad.
///
/// ## Como funciona
///
/// 1. **Quita el sesgo** del acelerometro con un filtro paso alto. Sin esto la
///    doble integral se dispara en segundos.
/// 2. **Suaviza** con un paso bajo de ~1,8 Hz. Aqui muere el movil agitado: una
///    sacudida de muneca va a 3-8 Hz y sale del filtro reducida a migajas,
///    mientras que una sentadilla (0,2-0,7 Hz) pasa entera.
/// 3. **Integra dos veces con fuga** hasta una altura estimada. La fuga impide
///    que el error se acumule; el precio es que la altura no esta en metros
///    reales sino encogida, y por eso los umbrales hay que calibrarlos.
/// 4. **Maquina de estados** sobre esa altura: reposo -> bajando -> subiendo.
///    La repeticion se cuenta **al completar la subida**, nunca al bajar, y solo
///    si cumple recorrido, velocidad y duracion.
public struct AlgoritmoSentadillas: Sendable {

    /// En que punto del gesto estamos.
    public enum Fase: String, Sendable, Hashable, Codable {
        case reposo
        case bajando
        case subiendo
    }

    /// Lo que el algoritmo sabe tras digerir una muestra. Lleva las senales
    /// derivadas ademas del contador porque la pantalla de calibracion las
    /// pinta: mirar la curva es la mitad del trabajo de afinar esto.
    public struct Salida: Sendable, Hashable {
        public let t: Double
        public let aceleracionFiltrada: Double
        public let velocidad: Double
        public let altura: Double
        public let fase: Fase
        /// `true` solo en la muestra exacta en la que se cierra una repeticion.
        public let repeticionCompletada: Bool
        public let repeticiones: Int
    }

    public private(set) var parametros: ParametrosSentadilla
    public private(set) var repeticiones = 0
    public private(set) var fase: Fase = .reposo

    // Estado de los filtros.
    private var tAnterior: Double?
    private var sesgo = 0.0
    private var suave = 0.0
    private var velocidad = 0.0
    private var altura = 0.0

    // Estado de la repeticion en curso.
    private var tInicio = 0.0
    private var alturaMinima = 0.0
    private var velocidadMinimaBajada = 0.0
    private var velocidadMaximaSubida = 0.0

    public init(parametros: ParametrosSentadilla = .porDefecto) {
        self.parametros = parametros
    }

    /// Digiere una muestra. `aceleracionVertical` va en m/s^2 y **positiva hacia
    /// arriba**, ya descontada la gravedad (es la componente de
    /// `userAcceleration` sobre la vertical que marca `gravity`).
    public mutating func procesa(t: Double, aceleracionVertical a: Double) -> Salida {
        let p = parametros

        // Lo mismo que en `AlgoritmoPasos`: una sola muestra corrupta envenena
        // los filtros y la integral para siempre, y a partir de ahi el contador
        // se queda clavado con la alarma sonando. Se tira y se sigue.
        guard a.isFinite, t.isFinite else { return salida(t: t, repeticionCompletada: false) }

        guard let anterior = tAnterior else {
            // Primera muestra: solo sirve para sembrar el sesgo y el reloj.
            tAnterior = t
            sesgo = a
            return salida(t: t, repeticionCompletada: false)
        }
        // Un hueco largo (la app en segundo plano, el sensor tosiendo) no debe
        // meter un salto gigante en la integral: se acota el paso.
        let dt = min(max(t - anterior, 1e-4), 0.2)
        tAnterior = t

        // 1. Paso alto: fuera el sesgo.
        sesgo += (a - sesgo) * min(1, dt / p.tauSesgo)
        let sinSesgo = a - sesgo

        // 2. Paso bajo: fuera el temblor rapido.
        suave += (sinSesgo - suave) * min(1, dt / p.tauSuavizado)

        // 3. Doble integral con fuga.
        velocidad = (velocidad + suave * dt) * exp(-dt / p.tauVelocidad)
        altura = (altura + velocidad * dt) * exp(-dt / p.tauAltura)

        // 4. Maquina de estados.
        var completada = false
        switch fase {
        case .reposo:
            if altura < -p.umbralInicioBajada && velocidad < 0 {
                fase = .bajando
                tInicio = t
                alturaMinima = altura
                velocidadMinimaBajada = velocidad
                velocidadMaximaSubida = 0
            }

        case .bajando:
            alturaMinima = min(alturaMinima, altura)
            velocidadMinimaBajada = min(velocidadMinimaBajada, velocidad)
            if t - tInicio > p.duracionMaxima {
                fase = .reposo
            } else if altura > alturaMinima + p.histeresisFondo {
                // Ha tocado fondo y remonta.
                fase = .subiendo
                velocidadMaximaSubida = velocidad
            }

        case .subiendo:
            velocidadMaximaSubida = max(velocidadMaximaSubida, velocidad)
            if altura < alturaMinima {
                // Se ha hundido mas: no era el fondo todavia.
                alturaMinima = altura
                fase = .bajando
            } else if t - tInicio > p.duracionMaxima {
                fase = .reposo
            } else if subidaCompletada() {
                let duracion = t - tInicio
                let profundidad = -alturaMinima
                let remontado = altura - alturaMinima
                let valida =
                    profundidad >= p.recorridoMinimo
                    && remontado >= profundidad * p.fraccionDeSubida
                    && velocidadMinimaBajada <= -p.velocidadBajadaMinima
                    && velocidadMaximaSubida >= p.velocidadSubidaMinima
                    && duracion >= p.duracionMinima
                    && duracion <= p.duracionMaxima
                fase = .reposo
                if valida {
                    repeticiones += 1
                    completada = true
                }
            }
        }

        return salida(t: t, repeticionCompletada: completada)
    }

    /// La subida esta hecha cuando la velocidad hacia arriba, despues de haber
    /// sido de verdad, vuelve a cero (el frenazo de ponerse de pie), o cuando la
    /// altura ya ha vuelto cerca de la linea base.
    private func subidaCompletada() -> Bool {
        let frenoArriba = velocidadMaximaSubida >= parametros.velocidadSubidaMinima && velocidad <= 0
        let deVueltaEnLaBase = altura > -parametros.umbralInicioBajada * 0.5
        return frenoArriba || deVueltaEnLaBase
    }

    private func salida(t: Double, repeticionCompletada: Bool) -> Salida {
        Salida(
            t: t,
            aceleracionFiltrada: suave,
            velocidad: velocidad,
            altura: altura,
            fase: fase,
            repeticionCompletada: repeticionCompletada,
            repeticiones: repeticiones
        )
    }

    /// Vuelve a cero. Se usa al arrancar un reto: nada de lo anterior cuenta.
    public mutating func reinicia() {
        repeticiones = 0
        fase = .reposo
        tAnterior = nil
        sesgo = 0
        suave = 0
        velocidad = 0
        altura = 0
        tInicio = 0
        alturaMinima = 0
        velocidadMinimaBajada = 0
        velocidadMaximaSubida = 0
    }
}
