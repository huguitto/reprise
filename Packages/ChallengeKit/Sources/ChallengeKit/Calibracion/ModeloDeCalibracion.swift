import Foundation
import AlarmCore

#if os(iOS)

/// El cerebro de la pantalla de calibracion.
///
/// Separado de la vista porque el bucle util —grabar, reproducir, barrer, mirar
/// el numero, repetir— es logica, no interfaz, y conviene poder mirarlo sin
/// tener que abrir la pantalla.
@MainActor
@Observable
public final class ModeloDeCalibracion {

    public enum Estado: Equatable {
        case parado
        case grabando
        case barriendo
    }

    public private(set) var estado: Estado = .parado
    public private(set) var muestrasGrabadas = 0
    public private(set) var duracionGrabada: Double = 0
    public private(set) var repeticionesEnVivo = 0
    public private(set) var pasosEnVivo = 0
    public private(set) var grabaciones: [(url: URL, grabacion: Grabacion)] = []
    /// Cuantas cuenta ahora mismo cada grabacion, precalculado.
    ///
    /// Precalculado y no al vuelo desde la vista porque reproducir es recorrer
    /// miles de muestras: hacerlo por fila y por fotograma mientras se arrastra
    /// un deslizador convierte la pantalla en un pisapapeles justo cuando mas
    /// falta hace que responda.
    public private(set) var contadasPorURL: [URL: Int] = [:]
    /// Si esa grabacion cumple lo que se le pide, precalculado por el mismo
    /// motivo. Vive aqui y no en la fila porque solo aqui se tienen a la vez las
    /// dos cuentas: una trampa esta bien parada cuando se queda corta en **los
    /// dos** retos, y sus objetivos no son el mismo numero.
    public private(set) var aciertaPorURL: [URL: Bool] = [:]
    public private(set) var candidatos: [CandidatoDeParametros] = []
    public private(set) var candidatosDePaso: [CandidatoDePasos] = []
    public private(set) var ultimoError: String?

    /// Los parametros con los que se reproduce todo en esta pantalla. Se tocan
    /// aqui, no en el codigo, que es justo lo que hace barata cada iteracion.
    public var parametros: ParametrosSentadilla = .porDefecto

    /// Y los del otro reto. Los dos juegos viven juntos en la pantalla porque la
    /// grabacion de trampa se califica con los dos a la vez.
    public var parametrosDePaso: ParametrosPaso = .porDefecto

    // Datos de la proxima grabacion, rellenados antes de empezar.
    public var tipo: Grabacion.Tipo = .sentadillas
    public var etiqueta: String = ""
    public var repeticionesReales: Int = 10
    public var notas: String = ""

    private let almacen: AlmacenDeGrabaciones
    private var grabador: GrabadorDeMovimiento?
    private var reloj: Task<Void, Never>?

    public init(almacen: AlmacenDeGrabaciones = AlmacenDeGrabaciones()) {
        self.almacen = almacen
    }

    public func carga() {
        grabaciones = almacen.todas()
        recuenta()
    }

    /// Vuelve a pasar todas las grabaciones por el algoritmo con los parametros
    /// actuales. Se llama al cargar y cada vez que se toca un parametro.
    public func recuenta() {
        var nuevas: [URL: Int] = [:]
        var aciertos: [URL: Bool] = [:]
        for fila in grabaciones {
            let (contadas, acierta) = cuenta(fila.grabacion)
            nuevas[fila.url] = contadas
            aciertos[fila.url] = acierta
        }
        contadasPorURL = nuevas
        aciertaPorURL = aciertos
    }

    /// Cada grabacion se recuenta con el algoritmo de su reto. La de trampa, con
    /// los dos: alli lo interesante es lo lejos que llega el peor de ellos, y
    /// solo esta bien parada si ninguno de los dos llega a su objetivo, que no
    /// es el mismo numero para los dos.
    private func cuenta(_ grabacion: Grabacion) -> (contadas: Int, acierta: Bool) {
        let sentadillas = Reproductor
            .reproduce(grabacion, parametros: parametros, conTraza: false)
            .contadas
        let pasos = ReproductorDePasos
            .reproduce(grabacion, parametros: parametrosDePaso, conTraza: false)
            .contados
        switch grabacion.tipo {
        case .sentadillas:
            return (sentadillas, sentadillas == grabacion.repeticionesReales)
        case .pasos:
            return (pasos, pasos == grabacion.repeticionesReales)
        case .trampa:
            let frenada = sentadillas < ChallengeType.sentadillas.goal
                && pasos < ChallengeType.pasos.goal
            return (max(sentadillas, pasos), frenada)
        }
    }

    // MARK: - Grabar

    public func empieza() async {
        guard estado == .parado else { return }
        ultimoError = nil
        let nuevo = GrabadorDeMovimiento(
            parametros: parametros,
            parametrosDePaso: parametrosDePaso
        )
        grabador = nuevo
        do {
            try await nuevo.empieza()
        } catch {
            ultimoError = "No se pudo arrancar el sensor de movimiento."
            grabador = nil
            return
        }
        estado = .grabando
        reloj = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                await self?.refresca()
            }
        }
    }

    private func refresca() async {
        guard let grabador else { return }
        muestrasGrabadas = await grabador.numeroDeMuestras
        duracionGrabada = await grabador.duracion
        repeticionesEnVivo = await grabador.repeticionesEnVivo
        pasosEnVivo = await grabador.pasosEnVivo
    }

    /// Lo que lleva contado el algoritmo del reto que se esta grabando ahora.
    ///
    /// Solo tiene sentido para una grabacion de un reto concreto. Una **trampa**
    /// lo es de los dos a la vez y hay que ver los dos numeros: esto devolvia el
    /// de sentadillas y la pantalla lo enseñaba a secas, asi que grabando una
    /// trampa de mover la muneca ponia "1" mientras el contador de pasos iba por
    /// 16. Una herramienta de calibrar que enseña el numero del otro reto no
    /// solo no ayuda: convence de que no hay fallo. Ahora la pantalla enseña los
    /// dos y esto no se usa para trampas.
    public var contadasEnVivo: Int {
        tipo == .pasos ? pasosEnVivo : repeticionesEnVivo
    }

    public func paraYGuarda() async {
        guard estado == .grabando, let grabador else { return }
        reloj?.cancel(); reloj = nil
        let nombre = etiqueta.trimmingCharacters(in: .whitespacesAndNewlines)
        let grabacion = await grabador.para(
            tipo: tipo,
            repeticionesReales: tipo == .trampa ? 0 : repeticionesReales,
            etiqueta: nombre.isEmpty ? "sin-etiqueta" : nombre,
            notas: notas
        )
        self.grabador = nil
        estado = .parado
        repeticionesEnVivo = 0
        pasosEnVivo = 0
        do {
            try almacen.guarda(grabacion)
            carga()
        } catch {
            ultimoError = "Grabacion hecha pero no se pudo guardar en disco."
        }
    }

    public func descarta() async {
        reloj?.cancel(); reloj = nil
        await grabador?.cancela()
        grabador = nil
        estado = .parado
        muestrasGrabadas = 0
        duracionGrabada = 0
        repeticionesEnVivo = 0
        pasosEnVivo = 0
    }

    // MARK: - Reproducir

    public func reproduce(_ grabacion: Grabacion) -> ResultadoDeReproduccion {
        Reproductor.reproduce(grabacion, parametros: parametros)
    }

    public func reproducePasos(_ grabacion: Grabacion) -> ResultadoDePasos {
        ReproductorDePasos.reproduce(grabacion, parametros: parametrosDePaso)
    }

    public func borra(_ url: URL) {
        try? almacen.borra(url)
        carga()
    }

    // MARK: - Barrido

    /// Prueba cientos de juegos de parametros contra todas las grabaciones.
    ///
    /// Es la razon de ser de la pantalla: sustituye "cambio un numero, subo a la
    /// app, hago diez sentadillas, miro" por "espero dos segundos".
    public func barre() async {
        guard estado == .parado, !grabaciones.isEmpty else { return }
        estado = .barriendo
        let todas = grabaciones.map(\.grabacion)
        let base = parametros
        let baseDePaso = parametrosDePaso
        let resultado = await Task.detached(priority: .userInitiated) {
            (
                sentadillas: Reproductor.barrido(todas, base: base),
                pasos: ReproductorDePasos.barrido(todas, base: baseDePaso)
            )
        }.value
        candidatos = resultado.sentadillas
        candidatosDePaso = resultado.pasos
        estado = .parado
    }

    public func adopta(_ candidato: CandidatoDeParametros) {
        parametros = candidato.parametros
        recuenta()
    }

    public func adopta(_ candidato: CandidatoDePasos) {
        parametrosDePaso = candidato.parametros
        recuenta()
    }

    /// Los parametros actuales escritos como codigo Swift, listos para pegar en
    /// `ParametrosSentadilla`. El viaje de la pantalla al repositorio a mano es
    /// el unico que queda, y asi al menos no se transcribe un decimal mal.
    public var parametrosComoSwift: String {
        let p = parametros
        return """
        ParametrosSentadilla(
            tauSesgo: \(p.tauSesgo),
            tauSuavizado: \(p.tauSuavizado),
            tauVelocidad: \(p.tauVelocidad),
            tauAltura: \(p.tauAltura),
            umbralInicioBajada: \(p.umbralInicioBajada),
            histeresisFondo: \(p.histeresisFondo),
            recorridoMinimo: \(p.recorridoMinimo),
            fraccionDeSubida: \(p.fraccionDeSubida),
            velocidadBajadaMinima: \(p.velocidadBajadaMinima),
            velocidadSubidaMinima: \(p.velocidadSubidaMinima),
            duracionMinima: \(p.duracionMinima),
            duracionMaxima: \(p.duracionMaxima)
        )
        """
    }

    /// Lo mismo para el otro reto.
    public var parametrosDePasoComoSwift: String {
        let p = parametrosDePaso
        return """
        ParametrosPaso(
            tauSesgo: \(p.tauSesgo),
            tauSuavizado: \(p.tauSuavizado),
            tauAmplitud: \(p.tauAmplitud),
            umbralMinimo: \(p.umbralMinimo),
            factorDeUmbral: \(p.factorDeUmbral),
            techoDePico: \(p.techoDePico),
            fraccionDeCierre: \(p.fraccionDeCierre),
            intervaloMinimo: \(p.intervaloMinimo),
            fraccionDeBajaFrecuencia: \(p.fraccionDeBajaFrecuencia)
        )
        """
    }
}
#endif
