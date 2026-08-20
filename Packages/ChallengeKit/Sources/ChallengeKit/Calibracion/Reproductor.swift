import Foundation

/// Resultado de pasar una grabacion por el algoritmo.
public struct ResultadoDeReproduccion: Sendable {
    public let grabacion: Grabacion
    public let parametros: ParametrosSentadilla
    public let contadas: Int
    /// Instante (s desde el inicio) de cada repeticion contada. Sirve para ver
    /// *donde* se equivoca, que es mas util que saber que se equivoca.
    public let instantes: [Double]
    /// La senal derivada, muestra a muestra, para pintarla.
    public let traza: [AlgoritmoSentadillas.Salida]

    /// Cuanto se aleja del numero real. 0 es acertar.
    public var error: Int { contadas - grabacion.repeticionesReales }
    public var acierta: Bool { error == 0 }
}

/// Un juego de parametros probado contra todas las grabaciones.
public struct CandidatoDeParametros: Sendable {
    public let parametros: ParametrosSentadilla
    /// Repeticiones que faltan sumadas sobre las grabaciones de sentadillas.
    /// Es el pecado grave: no contarle a alguien lo que ha hecho.
    public let faltantes: Int
    /// Repeticiones de mas sobre las grabaciones de sentadillas.
    public let sobrantes: Int
    /// Lo mas lejos que ha llegado una grabacion de trampa. Si llega al objetivo,
    /// la trampa cuela y el candidato no vale.
    public let maximoEnTrampas: Int
    public let resultados: [ResultadoDeReproduccion]

    /// Cuantas grabaciones de sentadillas ha clavado.
    public var aciertosExactos: Int {
        resultados.filter { $0.grabacion.tipo == .sentadillas && $0.acierta }.count
    }

    /// Puntuacion a minimizar.
    ///
    /// Los faltantes pesan el triple que los sobrantes: es la regla de producto
    /// escrita en aritmetica. Un detector que no cuenta una sentadilla real a las
    /// 6 de la manana es mucho peor que uno que cuela un movimiento raro.
    public var puntuacion: Int { faltantes * 3 + sobrantes }
}

/// Pasa grabaciones por el algoritmo, en frio y a toda velocidad.
///
/// Esta es la razon de construir la herramienta de calibracion antes que el
/// detector: cada tanda de sentadillas de verdad cuesta una sesion con una
/// persona sudando delante de ti, y aqui se reproduce cien veces en un segundo
/// sin molestar a nadie.
public enum Reproductor {

    public static func reproduce(
        _ grabacion: Grabacion,
        parametros: ParametrosSentadilla = .porDefecto,
        conTraza: Bool = true
    ) -> ResultadoDeReproduccion {
        var algoritmo = AlgoritmoSentadillas(parametros: parametros)
        var instantes: [Double] = []
        var traza: [AlgoritmoSentadillas.Salida] = []
        if conTraza { traza.reserveCapacity(grabacion.muestras.count) }

        for muestra in grabacion.muestras {
            let salida = algoritmo.procesa(
                t: muestra.t,
                aceleracionVertical: muestra.aceleracionVertical
            )
            if salida.repeticionCompletada { instantes.append(salida.t) }
            if conTraza { traza.append(salida) }
        }

        return ResultadoDeReproduccion(
            grabacion: grabacion,
            parametros: parametros,
            contadas: algoritmo.repeticiones,
            instantes: instantes,
            traza: traza
        )
    }

    public static func evalua(
        _ grabaciones: [Grabacion],
        parametros: ParametrosSentadilla,
        conTraza: Bool = false
    ) -> CandidatoDeParametros {
        let resultados = grabaciones.map {
            reproduce($0, parametros: parametros, conTraza: conTraza)
        }
        var faltantes = 0, sobrantes = 0, maximoEnTrampas = 0
        for r in resultados {
            switch r.grabacion.tipo {
            case .sentadillas:
                if r.error < 0 { faltantes -= r.error } else { sobrantes += r.error }
            case .trampa:
                maximoEnTrampas = max(maximoEnTrampas, r.contadas)
            }
        }
        return CandidatoDeParametros(
            parametros: parametros,
            faltantes: faltantes,
            sobrantes: sobrantes,
            maximoEnTrampas: maximoEnTrampas,
            resultados: resultados
        )
    }

    /// Rejilla que se recorre en el barrido. Son los cuatro numeros que de
    /// verdad mueven el resultado; los filtros se tocan a mano mirando la curva.
    public struct Rejilla: Sendable {
        public var recorridoMinimo: [Double]
        public var duracionMinima: [Double]
        public var velocidadSubidaMinima: [Double]
        public var tauAltura: [Double]

        public init(
            recorridoMinimo: [Double] = [0.04, 0.06, 0.08, 0.10, 0.13, 0.16, 0.20],
            duracionMinima: [Double] = [0.45, 0.55, 0.65, 0.80, 1.00],
            velocidadSubidaMinima: [Double] = [0.04, 0.07, 0.09, 0.12, 0.16],
            tauAltura: [Double] = [0.8, 1.2, 1.8]
        ) {
            self.recorridoMinimo = recorridoMinimo
            self.duracionMinima = duracionMinima
            self.velocidadSubidaMinima = velocidadSubidaMinima
            self.tauAltura = tauAltura
        }

        public var combinaciones: Int {
            recorridoMinimo.count * duracionMinima.count
                * velocidadSubidaMinima.count * tauAltura.count
        }
    }

    /// Prueba toda la rejilla contra todas las grabaciones y devuelve los mejores
    /// candidatos, del mas prometedor al menos.
    ///
    /// Descarta de entrada cualquier candidato con el que la trampa llegue al
    /// objetivo: ese es el unico requisito duro de anti-trampas que hay.
    public static func barrido(
        _ grabaciones: [Grabacion],
        base: ParametrosSentadilla = .porDefecto,
        rejilla: Rejilla = Rejilla(),
        objetivo: Int = 10,
        maximoDeResultados: Int = 10
    ) -> [CandidatoDeParametros] {
        var candidatos: [CandidatoDeParametros] = []
        for recorrido in rejilla.recorridoMinimo {
            for duracion in rejilla.duracionMinima {
                for velocidad in rejilla.velocidadSubidaMinima {
                    for tau in rejilla.tauAltura {
                        var p = base
                        p.recorridoMinimo = recorrido
                        p.duracionMinima = duracion
                        p.velocidadSubidaMinima = velocidad
                        p.tauAltura = tau
                        candidatos.append(evalua(grabaciones, parametros: p))
                    }
                }
            }
        }
        return candidatos
            .filter { $0.maximoEnTrampas < objetivo }
            .sorted { izq, der in
                if izq.puntuacion != der.puntuacion { return izq.puntuacion < der.puntuacion }
                // A igualdad, gana el que deja mas margen frente a la trampa.
                return izq.maximoEnTrampas < der.maximoEnTrampas
            }
            .prefix(maximoDeResultados)
            .map { $0 }
    }
}
