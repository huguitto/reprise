import Foundation

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
    public private(set) var grabaciones: [(url: URL, grabacion: Grabacion)] = []
    /// Cuantas cuenta ahora mismo cada grabacion, precalculado.
    ///
    /// Precalculado y no al vuelo desde la vista porque reproducir es recorrer
    /// miles de muestras: hacerlo por fila y por fotograma mientras se arrastra
    /// un deslizador convierte la pantalla en un pisapapeles justo cuando mas
    /// falta hace que responda.
    public private(set) var contadasPorURL: [URL: Int] = [:]
    public private(set) var candidatos: [CandidatoDeParametros] = []
    public private(set) var ultimoError: String?

    /// Los parametros con los que se reproduce todo en esta pantalla. Se tocan
    /// aqui, no en el codigo, que es justo lo que hace barata cada iteracion.
    public var parametros: ParametrosSentadilla = .porDefecto

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
        for fila in grabaciones {
            nuevas[fila.url] = Reproductor
                .reproduce(fila.grabacion, parametros: parametros, conTraza: false)
                .contadas
        }
        contadasPorURL = nuevas
    }

    // MARK: - Grabar

    public func empieza() async {
        guard estado == .parado else { return }
        ultimoError = nil
        let nuevo = GrabadorDeMovimiento(parametros: parametros)
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
    }

    // MARK: - Reproducir

    public func reproduce(_ grabacion: Grabacion) -> ResultadoDeReproduccion {
        Reproductor.reproduce(grabacion, parametros: parametros)
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
        let resultado = await Task.detached(priority: .userInitiated) {
            Reproductor.barrido(todas, base: base)
        }.value
        candidatos = resultado
        estado = .parado
    }

    public func adopta(_ candidato: CandidatoDeParametros) {
        parametros = candidato.parametros
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
}
#endif
