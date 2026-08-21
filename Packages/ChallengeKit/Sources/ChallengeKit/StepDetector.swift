import Foundation
import AlarmCore

// Ver la nota de `ChallengeDetectorFactory`: en macOS CoreMotion se importa pero
// ni `CMMotionManager` ni `CMPedometer` estan disponibles, asi que la guarda es
// el sistema.
#if os(iOS)
import CoreMotion

/// Cuenta los 20 pasos leyendo el acelerometro a 50 Hz.
///
/// ## Por que no manda el podometro
///
/// Hasta el 21 de agosto de 2026 esto era `CMPedometer` y nada mas, y contaba
/// alrededor de un tercio de lo que andaba la persona: veinte en pantalla
/// despues de sesenta de verdad (issue #35). No era un fallo de nuestra
/// aritmetica —el dato del podometro es acumulado y se sumaba entero— sino de la
/// herramienta: su propia cabecera entrega los datos *"on a best effort basis"*,
/// confirma que estas caminando antes de contar nada, descarta las rachas cortas
/// e irregulares y entrega a tandas de varios segundos. Dar veinte pasos por una
/// habitacion, con giros y medio dormido, es exactamente el caso que descarta.
/// El primer intento de arreglo (PR #38) quito un tope de cadencia que, con la
/// cuenta hecha, nunca llegaba a morder: el recorte no era nuestro.
///
/// Asi que la cuenta que manda es la de `AlgoritmoPasos` sobre `CMDeviceMotion`,
/// la misma fontaneria que ya usa `SquatDetector`, y el podometro se queda de
/// red por debajo via `FusionDePasos`. Cuesta poco tenerlo escuchando y solo
/// puede sumar.
///
/// ## Lo que se pierde
///
/// El podometro vive en el coprocesador y sigue contando con la pantalla apagada
/// y la app en segundo plano; `CMDeviceMotion` no. Aqui da igual: la pantalla del
/// reto esta delante y encendida mientras dura, y si la app se va al fondo la
/// alarma vuelve a sonar. Y por si acaso, el que sigue contando en el fondo es
/// justo el que se ha quedado de red.
public actor StepDetector: ChallengeDetector {
    public let goal: Int
    public nonisolated let progress: AsyncStream<ChallengeProgress>

    private let gestor = CMMotionManager()
    private let podometro = CMPedometer()
    private let frecuenciaHz: Double
    private let continuacion: AsyncStream<ChallengeProgress>.Continuation

    private var algoritmo: AlgoritmoPasos
    private var fusion: FusionDePasos
    private var consumo: Task<Void, Never>?
    private var consumoDelPodometro: Task<Void, Never>?
    private var vigilante: Task<Void, Never>?

    private var ultimoAvance = ContinuousClock.now
    private var parado = false
    private var enMarcha = false
    private var hanLlegadoMuestras = false
    private var hanLlegadoDatosDelPodometro = false

    /// Cada arranque lleva su numero. `start()` se suspende por el medio y en
    /// ese hueco cabe un `stop()` y otro `start()`; sin esto, el arranque viejo
    /// vuelve del await creyendo que sigue siendo el vigente y desmonta la
    /// sesion buena o deja un vigilante huerfano latiendo para siempre.
    private var generacion = 0

    /// Cuanto se espera a que alguna de las dos fuentes de senal de vida diga
    /// algo antes de dar el movil por incapaz. Lo normal es una muestra a 50 Hz,
    /// centesimas; esto es para el arranque con la app cargando y la alarma
    /// sonando encima. Generoso a proposito: pasarse de corto **regala la
    /// alarma**, porque `sinSensor` suelta el dial.
    private static let esperaDeArranque: Duration = .seconds(5)

    public init(
        goal: Int,
        parametros: ParametrosPaso = .porDefecto,
        frecuenciaHz: Double = GrabadorDeMovimiento.frecuenciaPorDefecto
    ) {
        self.goal = goal
        self.frecuenciaHz = frecuenciaHz
        self.algoritmo = AlgoritmoPasos(parametros: parametros)
        self.fusion = FusionDePasos(objetivo: goal)
        var cont: AsyncStream<ChallengeProgress>.Continuation!
        self.progress = AsyncStream { cont = $0 }
        self.continuacion = cont
    }

    public func start() async throws {
        guard !enMarcha else { return }
        // El acelerometro es el que cuenta, asi que su ausencia si es motivo
        // para decir que este movil no sabe contar. La falta de podometro, no.
        guard gestor.isDeviceMotionAvailable else {
            throw ChallengeDetectorError.sensorNoDisponible
        }

        generacion += 1
        let mia = generacion
        enMarcha = true
        algoritmo.reinicia()
        fusion = FusionDePasos(objetivo: goal)
        ultimoAvance = .now
        parado = false
        hanLlegadoMuestras = false
        hanLlegadoDatosDelPodometro = false
        // El cero se anuncia antes de encender nada, para que ningun paso pueda
        // adelantarsele por la espera de abajo y el contador vaya hacia atras.
        continuacion.yield(ChallengeProgress(completed: 0, goal: goal))

        arrancaElAcelerometro()
        arrancaElPodometro()
        guard try await esperaASenalDeVida(generacion: mia) else { return }

        vigilante = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Inactividad.periodoDeRevision)
                // Si el actor ya no esta, `self?` seria nil eternamente y este
                // bucle seguiria despertando cada medio segundo el resto de la
                // vida del proceso: la Task la retiene el runtime, no el actor.
                guard let self else { return }
                await self.revisaInactividad()
            }
        }
    }

    public func stop() async {
        guard enMarcha else { return }
        generacion += 1
        enMarcha = false
        gestor.stopDeviceMotionUpdates()
        podometro.stopUpdates()
        consumo?.cancel(); consumo = nil
        consumoDelPodometro?.cancel(); consumoDelPodometro = nil
        vigilante?.cancel(); vigilante = nil
        continuacion.finish()
    }

    /// No sigue hasta que **alguna** de las dos fuentes ha dado senales de vida.
    ///
    /// `isDeviceMotionAvailable` dice que el sensor existe, no que este
    /// entregando. Si arrancara mudo, el usuario se quedaria mirando un cero con
    /// la alarma sonando y sin una sola pista de que hacer, que es el peor final
    /// posible en esta app: aqui no se apaga nada sin que algo cuente.
    ///
    /// Vale cualquiera de las dos fuentes y se **observa**, no se supone. La
    /// version anterior preguntaba al arrancar si el podometro estaba
    /// disponible y se fiaba de la respuesta, y esa respuesta miente: la primera
    /// vez `authorizationStatus()` es `.notDetermined`, asi que decia que si
    /// antes de saberlo, y si luego el usuario denegaba el permiso nadie contaba
    /// y nadie se enteraba.
    ///
    /// Y el limite se peca de largo a proposito. Rendirse aqui no es inocuo:
    /// `sensorNoDisponible` acaba en `estado = .sinSensor`, que **suelta el
    /// dial**. Un limite corto convertiria un arranque lento del sensor en una
    /// alarma apagada sin levantarse.
    ///
    /// Devuelve `false` si este arranque ya no es el vigente: entonces no hay
    /// nada que decir ni que desmontar, manda el que vino despues.
    private func esperaASenalDeVida(generacion mia: Int) async throws -> Bool {
        let limite = ContinuousClock.now.advanced(by: Self.esperaDeArranque)
        while !hayAlgunaSenal, generacion == mia, !Task.isCancelled,
              ContinuousClock.now < limite {
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard generacion == mia, !Task.isCancelled else { return false }
        guard !hayAlgunaSenal else { return true }
        await stop()
        throw ChallengeDetectorError.sensorNoDisponible
    }

    private var hayAlgunaSenal: Bool { hanLlegadoMuestras || hanLlegadoDatosDelPodometro }

    // MARK: - Los dos sensores

    private func arrancaElAcelerometro() {
        // `CMDeviceMotion` no es Sendable: del callback solo salen numeros, ya
        // empaquetados en una muestra que si lo es.
        let (flujo, continuacionDeMuestras) = AsyncStream.makeStream(of: MuestraDeMovimiento.self)

        let cola = OperationQueue()
        cola.maxConcurrentOperationCount = 1
        cola.qualityOfService = .userInitiated

        gestor.deviceMotionUpdateInterval = 1 / frecuenciaHz
        // `xArbitraryZVertical` no necesita la brujula, asi que arranca al
        // instante. Da igual hacia donde mire el movil: lo unico que se usa es
        // `gravity`, y eso lo da cualquier marco de referencia.
        gestor.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: cola) { movimiento, _ in
            guard let m = movimiento else { return }
            continuacionDeMuestras.yield(
                MuestraDeMovimiento(
                    t: m.timestamp,
                    ax: m.userAcceleration.x, ay: m.userAcceleration.y, az: m.userAcceleration.z,
                    gx: m.gravity.x, gy: m.gravity.y, gz: m.gravity.z
                )
            )
        }

        consumo = Task { [weak self] in
            for await muestra in flujo {
                await self?.procesa(muestra)
            }
        }
    }

    /// La red por debajo. Que no haya podometro, o que el permiso este denegado,
    /// no para el reto: el que cuenta es el otro.
    private func arrancaElPodometro() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        switch CMPedometer.authorizationStatus() {
        case .denied, .restricted: return
        default: break
        }

        // Desde *ahora*: los pasos que diera antes de que sonara la alarma no
        // cuentan. `startUpdates(from:)` acepta fechas pasadas y devolveria el
        // historico del coprocesador, que es exactamente la forma trivial de
        // saltarse el reto sin levantarse.
        let desde = Date()

        // `CMPedometerData` no es Sendable: del callback solo salen enteros.
        let (flujo, continuacionDePasos) = AsyncStream.makeStream(of: Int.self)
        podometro.startUpdates(from: desde) { datos, _ in
            guard let datos else { return }
            continuacionDePasos.yield(datos.numberOfSteps.intValue)
        }

        consumoDelPodometro = Task { [weak self] in
            for await acumulados in flujo {
                await self?.registraDelPodometro(acumulados)
            }
        }
    }

    // MARK: - Contar

    private func procesa(_ muestra: MuestraDeMovimiento) {
        guard enMarcha else { return }
        hanLlegadoMuestras = true
        let salida = algoritmo.procesa(
            t: muestra.t,
            aceleracionVertical: muestra.aceleracionVertical,
            gravedad: (muestra.gx, muestra.gy, muestra.gz)
        )

        // Solo el paso cerrado cuenta como movimiento valido. Que la senal se
        // mueva no basta: si asi fuera, mecer el movil en la cama aplazaria el
        // abandono para siempre sin haber dado un paso.
        guard salida.pasoCompletado else { return }
        avanza(fusion.paso())
    }

    /// `numberOfSteps` es acumulado desde que arranco el reto, no un incremento.
    private func registraDelPodometro(_ acumulados: Int) {
        guard enMarcha else { return }
        hanLlegadoDatosDelPodometro = true
        avanza(fusion.podometro(acumulados: acumulados))
    }

    private func avanza(_ avance: FusionDePasos.Avance) {
        guard avance.hayPasos else { return }
        // El reloj del abandono se refresca con cualquier paso real, aunque el
        // numero no se mueva porque la otra fuente ya iba por delante.
        ultimoAvance = .now
        let estaba = parado
        parado = false
        if avance.cambiaElTotal || estaba { emite() }

        if fusion.terminado {
            gestor.stopDeviceMotionUpdates()
            podometro.stopUpdates()
        }
    }

    private func revisaInactividad() {
        guard enMarcha, !fusion.terminado else { return }
        let inactivo = ultimoAvance.duration(to: .now) >= Inactividad.umbral
        guard inactivo != parado else { return }
        parado = inactivo
        emite()
    }

    private func emite() {
        continuacion.yield(
            ChallengeProgress(completed: fusion.contados, goal: goal, isStalled: parado)
        )
    }
}
#endif
