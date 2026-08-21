import Foundation
import Observation
import AlarmCore
import AlarmScheduler
import ChallengeKit
import DesignSystem
import Persistence

/// Lo que hay entre los sensores y la pantalla del reto.
///
/// Es el paso 3 del flujo de producto, el que faltaba entero: la alerta del
/// sistema abre la app (paso 2) y deja el recado en `ChallengeInbox`, y aqui es
/// donde ese recado se convierte en una pantalla que cuenta. Hasta ahora nadie
/// leia el buzon, asi que pulsar "Hacer el reto" abria la lista de alarmas y ya.
///
/// El orden de lo que hace al empezar no es intercambiable:
///
/// 1. **El rastro en disco, antes que nada.** `PendingChallenge` es lo unico
///    que impide que matar la app sea la forma trivial de saltarse el
///    despertador: si no esta escrito cuando el usuario mata la app, el dia se
///    pierde sin castigo.
/// 2. **La app toma el relevo del sonido** (`resumeCurrentAlarm`), que apaga la
///    alerta del sistema y arranca el tono en bucle desde aqui. Si no, la
///    alerta sigue viva por debajo y suenan dos cosas a la vez.
/// 3. **Los sensores**, que son lo unico que puede fallar de verdad.
///
/// Y lo que **no** hace: callar la alarma al llegar al objetivo. Eso lo hace el
/// dial, cuando el usuario lo arrastra. Terminar el reto suelta el interruptor;
/// apagar sigue siendo un gesto deliberado y no un reflejo de medio dormido.
/// El dia, en cambio, se escribe en cuanto se termina y no al apagar: lo que ya
/// se ha hecho con las piernas no se pierde porque alguien tire el movil a la
/// cama sin arrastrar nada.
@MainActor
@Observable
final class ModeloDeReto {

    /// El reto en marcha. `nil` —el caso normal— es que no hay ninguno y la app
    /// ensena su navegacion de siempre.
    private(set) var peticion: ChallengeRequest?

    /// Repeticiones contadas. Es todo el feedback que hay durante el reto, por
    /// decision de producto.
    private(set) var hechos = 0

    /// Segundos desde que sono la alarma, no desde que se abrio la pantalla:
    /// es lo que acaba en `DayRecord.duration` y lo que el usuario entiende por
    /// "cuanto he tardado en levantarme".
    private(set) var segundos = 0

    private(set) var estado: EstadoDelReto = .enMarcha

    var hayReto: Bool { peticion != nil }
    var reto: ChallengeType { peticion?.challenge ?? .pasos }

    private let almacen: AlmacenSwiftData
    private let programador: any AlarmScheduling
    private let racha: ModeloDeRacha
    private let calendario: Calendar
    /// De donde sale el detector. Es un cierre para poder meter uno de mentira
    /// en las pruebas; por defecto es la fabrica de `ChallengeKit`, que ya
    /// decide sola entre el sensor de verdad y el simulado.
    private let detectorPara: @MainActor (ChallengeType) -> any ChallengeDetector

    private var detector: (any ChallengeDetector)?
    private var escucha: Task<Void, Never>?
    private var cronometro: Task<Void, Never>?

    init(
        almacen: AlmacenSwiftData,
        programador: any AlarmScheduling,
        racha: ModeloDeRacha,
        calendario: Calendar = .current,
        detectorPara: @escaping @MainActor (ChallengeType) -> any ChallengeDetector = {
            ChallengeDetectorFactory.make(for: $0)
        }
    ) {
        self.almacen = almacen
        self.programador = programador
        self.racha = racha
        self.calendario = calendario
        self.detectorPara = detectorPara
    }

    // MARK: - Entrar y salir

    /// Mira si el boton de la alerta dejo un recado y, si lo hay, arranca.
    ///
    /// Se llama al abrir la app, al volver del fondo y cuando el buzon cambia.
    /// Consumir el recado lo borra, asi que llamar de mas no arranca dos retos.
    func recogerElRecado() async {
        guard peticion == nil else { return }
        guard let peticion = ChallengeInbox.consume() else { return }
        await empezar(peticion)
    }

    func empezar(_ peticion: ChallengeRequest) async {
        guard self.peticion == nil else { return }

        self.peticion = peticion
        hechos = 0
        segundos = Int(max(0, Date().timeIntervalSince(peticion.requestedAt)))
        estado = .enMarcha

        // 1. El rastro. Si el disco falla no se puede parar el reto por eso —el
        //    usuario tiene una alarma sonando— pero si se queda sin la red que
        //    castiga matar la app. Se sigue adelante a sabiendas.
        try? await almacen.begin(
            PendingChallenge(
                alarmID: peticion.alarmID,
                challenge: peticion.challenge,
                day: Day(peticion.requestedAt, calendar: calendario),
                startedAt: peticion.requestedAt
            )
        )

        // 2. El sonido pasa a ser nuestro.
        await programador.resumeCurrentAlarm()

        arrancarCronometro()

        // 3. Los sensores.
        let detector = detectorPara(peticion.challenge)
        self.detector = detector
        escucharA(detector)
        do {
            try await detector.start()
        } catch {
            await noSePuedeContar(error)
        }
    }

    /// El usuario arrastro el dial. Aqui —y solo aqui— se calla la alarma.
    func apagar() async {
        await parar()
        await programador.silenceCurrentAlarm()
        peticion = nil
        hechos = 0
        segundos = 0
        estado = .enMarcha
    }

    // MARK: - Contar

    private func escucharA(_ detector: any ChallengeDetector) {
        escucha?.cancel()
        escucha = Task { [weak self] in
            for await avance in await detector.progress {
                guard let self, !Task.isCancelled else { return }
                await self.recibir(avance)
            }
        }
    }

    private func recibir(_ avance: ChallengeProgress) async {
        guard peticion != nil else { return }
        hechos = avance.completed

        if avance.isFinished {
            await terminar()
            return
        }

        // Abandonado a mitad: la alarma vuelve a sonar. No se resuelve el dia
        // como fallado —el usuario sigue en la pantalla y puede continuar; el
        // castigo llega si mata la app, y de eso ya se encarga el rastro.
        if avance.isStalled {
            await programador.resumeCurrentAlarm()
        }
    }

    private func terminar() async {
        guard let peticion, case .enMarcha = estado else { return }

        await parar()
        hechos = max(hechos, peticion.challenge.goal)
        estado = .completado

        await racha.completarReto(
            alarmID: peticion.alarmID,
            reto: peticion.challenge,
            duracion: Date().timeIntervalSince(peticion.requestedAt)
        )
    }

    /// Ni sensor ni permiso de movimiento: el reto no se puede medir.
    ///
    /// No se resuelve el dia de ninguna manera. No es `completado` —no se ha
    /// hecho— y tampoco es un fallo del usuario: el movil no sabe contar. Lo
    /// que si se hace es borrar el rastro, porque si no el proximo arranque lo
    /// encontraria abierto y castigaria por algo que no hizo nadie.
    private func noSePuedeContar(_ error: any Error) async {
        await parar()
        try? await almacen.clear()
        estado = .sinSensor(Self.motivo(de: error))
    }

    private static func motivo(de error: any Error) -> String {
        switch error {
        case ChallengeDetectorError.permisoDenegado:
            "RepRise no tiene permiso para leer tu movimiento"
        case ChallengeDetectorError.sensorNoDisponible:
            "Este móvil no puede contarlo"
        default:
            "Ha fallado el sensor"
        }
    }

    // MARK: - El cronometro

    private func arrancarCronometro() {
        cronometro?.cancel()
        cronometro = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let peticion = self.peticion else { return }
                self.segundos = Int(max(0, Date().timeIntervalSince(peticion.requestedAt)))
            }
        }
    }

    /// Para los sensores y el cronometro. No toca ni el sonido ni el dia: eso
    /// lo decide quien llame.
    private func parar() async {
        escucha?.cancel()
        escucha = nil
        cronometro?.cancel()
        cronometro = nil
        await detector?.stop()
        detector = nil
    }
}
