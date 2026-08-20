import Foundation

/// Los numeros que deciden si un movimiento es una sentadilla.
///
/// Estan todos aqui, juntos y con nombre, por un motivo: **son provisionales**.
/// Salen de la fisica del gesto, no de datos reales, y la unica forma honesta de
/// fijarlos es grabar sentadillas de verdad y hacerlas pasar por
/// `Reproductor.barrido(_:)`. Hasta que eso ocurra, cualquier valor de aqui es
/// una hipotesis.
///
/// Al elegir, la regla de producto es explicita y va en una sola direccion: un
/// falso negativo (no contarle una sentadilla real a alguien a las 6 de la
/// manana) es mucho peor que un falso positivo. Ante la duda, aflojar.
public struct ParametrosSentadilla: Sendable, Hashable, Codable {

    // MARK: - Filtros de la senal

    /// Constante de tiempo del filtro que quita el sesgo del acelerometro (s).
    /// Sin esto la doble integral se va a la deriva en pocos segundos.
    public var tauSesgo: Double

    /// Constante de tiempo del suavizado (s). Es **el filtro anti-trampas**:
    /// 0,09 s corta por encima de ~1,8 Hz, y agitar el movil con la muneca pasa
    /// de los 3 Hz. Una sentadilla real vive entre 0,2 y 0,7 Hz y no se entera.
    public var tauSuavizado: Double

    /// Fuga de la primera integral, aceleracion -> velocidad (s).
    public var tauVelocidad: Double

    /// Fuga de la segunda integral, velocidad -> altura (s).
    ///
    /// La fuga es lo que impide que el error se acumule, pero tambien encoge la
    /// amplitud: la altura estimada **no son metros reales**, es una fraccion de
    /// los metros reales. Por eso `recorridoMinimo` no se puede leer como "20 cm
    /// de bajada" y hay que sacarlo de las grabaciones.
    public var tauAltura: Double

    // MARK: - Forma de la repeticion

    /// Cuanto hay que bajar respecto a la linea base para que empiece a contar
    /// como bajada (m estimados).
    public var umbralInicioBajada: Double

    /// Cuanto hay que remontar desde el punto mas bajo para dar por hecho que se
    /// ha tocado fondo y ha empezado la subida (m estimados). Es histeresis: sin
    /// ella, el ruido en el fondo dispara varias subidas.
    public var histeresisFondo: Double

    /// Profundidad minima de la bajada (m estimados). El "recorrido minimo" que
    /// pide el encargo.
    public var recorridoMinimo: Double

    /// Que fraccion de lo bajado hay que volver a subir para que cuente. A 0,5,
    /// quedarse a medias no cuenta pero tampoco se exige clavar la vertical.
    public var fraccionDeSubida: Double

    // MARK: - Velocidades

    /// Velocidad de bajada minima (m/s estimados). Descarta el hundirse despacio
    /// de quien se sienta.
    public var velocidadBajadaMinima: Double

    /// Velocidad de subida minima (m/s estimados).
    ///
    /// Ademas de exigir intencion, tapa un agujero del propio filtro: como la
    /// altura tiene fuga, quien baje y se quede abajo quieto veria su altura
    /// volver sola a la linea base. Pero eso ocurre sin velocidad, porque la
    /// velocidad tambien tiene fuga y sin aceleracion se queda en cero. Exigir
    /// velocidad de subida distingue "he subido" de "el filtro ha vuelto solo".
    public var velocidadSubidaMinima: Double

    // MARK: - Tiempos

    /// Duracion minima de una repeticion, de inicio de bajada a fin de subida (s).
    /// El "tiempo minimo por repeticion" del encargo.
    public var duracionMinima: Double

    /// Pasado este tiempo la repeticion se abandona y se vuelve a reposo (s).
    public var duracionMaxima: Double

    public init(
        tauSesgo: Double = 1.5,
        tauSuavizado: Double = 0.09,
        tauVelocidad: Double = 1.0,
        tauAltura: Double = 1.2,
        umbralInicioBajada: Double = 0.035,
        histeresisFondo: Double = 0.02,
        recorridoMinimo: Double = 0.09,
        fraccionDeSubida: Double = 0.5,
        velocidadBajadaMinima: Double = 0.09,
        velocidadSubidaMinima: Double = 0.09,
        duracionMinima: Double = 0.65,
        duracionMaxima: Double = 6.0
    ) {
        self.tauSesgo = tauSesgo
        self.tauSuavizado = tauSuavizado
        self.tauVelocidad = tauVelocidad
        self.tauAltura = tauAltura
        self.umbralInicioBajada = umbralInicioBajada
        self.histeresisFondo = histeresisFondo
        self.recorridoMinimo = recorridoMinimo
        self.fraccionDeSubida = fraccionDeSubida
        self.velocidadBajadaMinima = velocidadBajadaMinima
        self.velocidadSubidaMinima = velocidadSubidaMinima
        self.duracionMinima = duracionMinima
        self.duracionMaxima = duracionMaxima
    }

    /// Los valores por defecto: la hipotesis de partida, sin calibrar.
    public static let porDefecto = ParametrosSentadilla()
}
