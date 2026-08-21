import Foundation

// `CMMotionManager` existe en el SDK de macOS pero esta marcado como no
// disponible, asi que no basta con `canImport`: la guarda tiene que ser el sistema.
// En el Mac esta pieza sencillamente no existe, y el `Reproductor` —que si es puro—
// es el que permite calibrar desde el host.
#if os(iOS)
import CoreMotion

/// Graba el flujo crudo de `CMDeviceMotion` mientras alguien hace sentadillas
/// de verdad.
///
/// Es la primera pieza del encargo y no por capricho: sin grabaciones, elegir
/// los umbrales del detector es adivinar, y cada intento cuesta una sesion con
/// una persona haciendo sentadillas delante de ti. Con grabaciones, el mismo
/// minuto de esfuerzo se reproduce cien veces contra cien juegos de parametros.
public actor GrabadorDeMovimiento {

    /// 50 Hz. Una sentadilla ocupa entre 1 y 3 segundos, asi que sobra de largo,
    /// y a 100 Hz los ficheros se doblan sin aportar nada.
    public static let frecuenciaPorDefecto: Double = 50

    public let frecuenciaHz: Double
    public private(set) var grabando = false
    public private(set) var muestras: [MuestraDeMovimiento] = []

    /// Los mismos algoritmos del detector, corriendo sobre el flujo que se graba.
    ///
    /// Sale gratis —las muestras ya estan pasando por aqui— y convierte cada
    /// sesion de grabacion en una prueba del detector: la persona hace diez, ve
    /// en pantalla lo que ha contado la app y, si no coinciden, el fichero con la
    /// senal de ese fallo concreto ya esta guardado. Sin esto harian falta dos
    /// sesiones para las dos cosas, y solo hay un iPhone y una persona.
    ///
    /// Corren **los dos a la vez** sobre la misma senal, cueste lo que cueste
    /// —que son unas pocas multiplicaciones por muestra— porque una grabacion de
    /// trampa vale para los dos retos y asi una sola sacudida contesta a las dos
    /// preguntas.
    private var sentadillasEnVivo: AlgoritmoSentadillas
    private var pasosEnVivoAlgoritmo: AlgoritmoPasos
    public private(set) var repeticionesEnVivo = 0
    public private(set) var pasosEnVivo = 0

    private let gestor = CMMotionManager()
    private var consumo: Task<Void, Never>?
    private var inicio: TimeInterval?

    public init(
        frecuenciaHz: Double = GrabadorDeMovimiento.frecuenciaPorDefecto,
        parametros: ParametrosSentadilla = .porDefecto,
        parametrosDePaso: ParametrosPaso = .porDefecto
    ) {
        self.frecuenciaHz = frecuenciaHz
        self.sentadillasEnVivo = AlgoritmoSentadillas(parametros: parametros)
        self.pasosEnVivoAlgoritmo = AlgoritmoPasos(parametros: parametrosDePaso)
    }

    public var numeroDeMuestras: Int { muestras.count }
    public var duracion: Double { muestras.last?.t ?? 0 }

    public func empieza() throws {
        guard !grabando else { return }
        guard gestor.isDeviceMotionAvailable else {
            throw ChallengeDetectorError.sensorNoDisponible
        }
        muestras.removeAll(keepingCapacity: true)
        inicio = nil
        sentadillasEnVivo.reinicia()
        pasosEnVivoAlgoritmo.reinicia()
        repeticionesEnVivo = 0
        pasosEnVivo = 0
        grabando = true

        // `CMDeviceMotion` no es Sendable, asi que del callback solo salen
        // numeros: se convierten a `MuestraDeMovimiento` alli mismo y viajan por
        // el flujo, que si lo es y ademas conserva el orden.
        let (flujo, continuacion) = AsyncStream.makeStream(of: MuestraDeMovimiento.self)

        let cola = OperationQueue()
        cola.maxConcurrentOperationCount = 1
        cola.qualityOfService = .userInitiated

        gestor.deviceMotionUpdateInterval = 1 / frecuenciaHz
        gestor.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: cola) { movimiento, _ in
            guard let m = movimiento else { return }
            continuacion.yield(
                MuestraDeMovimiento(
                    t: m.timestamp,
                    ax: m.userAcceleration.x, ay: m.userAcceleration.y, az: m.userAcceleration.z,
                    gx: m.gravity.x, gy: m.gravity.y, gz: m.gravity.z
                )
            )
        }

        consumo = Task { [weak self] in
            for await muestra in flujo {
                await self?.anota(muestra)
            }
        }
    }

    /// El `timestamp` de CoreMotion cuenta desde el ultimo arranque del
    /// dispositivo, un numero enorme y sin sentido fuera de este movil. Se pasa
    /// a segundos desde el inicio de la grabacion, que es lo unico que importa.
    private func anota(_ muestra: MuestraDeMovimiento) {
        guard grabando else { return }
        let cero = inicio ?? muestra.t
        if inicio == nil { inicio = cero }
        let relativa = MuestraDeMovimiento(
            t: muestra.t - cero,
            ax: muestra.ax, ay: muestra.ay, az: muestra.az,
            gx: muestra.gx, gy: muestra.gy, gz: muestra.gz
        )
        muestras.append(relativa)
        let vertical = relativa.aceleracionVertical
        repeticionesEnVivo = sentadillasEnVivo
            .procesa(t: relativa.t, aceleracionVertical: vertical)
            .repeticiones
        // Con la gravedad, no sin ella: el veto por giro es parte del contador
        // y sin pasarla el numero en vivo no seria el mismo que sale al
        // reproducir la grabacion despues. Que la pantalla y el banco digan lo
        // mismo es justo para lo que existe esta herramienta.
        pasosEnVivo = pasosEnVivoAlgoritmo
            .procesa(
                t: relativa.t,
                aceleracionVertical: vertical,
                gravedad: (relativa.gx, relativa.gy, relativa.gz)
            )
            .pasos
    }

    /// Para de grabar y devuelve la sesion. `repeticionesReales` es lo que la
    /// persona dice que ha hecho: es la verdad contra la que se calibra todo, asi
    /// que se pide siempre.
    public func para(
        tipo: Grabacion.Tipo,
        repeticionesReales: Int,
        etiqueta: String,
        notas: String = ""
    ) -> Grabacion {
        gestor.stopDeviceMotionUpdates()
        consumo?.cancel()
        consumo = nil
        grabando = false
        return Grabacion(
            tipo: tipo,
            repeticionesReales: repeticionesReales,
            etiqueta: etiqueta,
            notas: notas,
            frecuenciaHz: frecuenciaHz,
            muestras: muestras
        )
    }

    /// Corta sin cosechar nada, para cuando se abandona la pantalla.
    public func cancela() {
        gestor.stopDeviceMotionUpdates()
        consumo?.cancel()
        consumo = nil
        grabando = false
        muestras.removeAll()
        repeticionesEnVivo = 0
    }
}
#endif
