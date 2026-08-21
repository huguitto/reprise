import Foundation

/// Resultado de pasar una grabacion por el contador de pasos.
public struct ResultadoDePasos: Sendable {
    public let grabacion: Grabacion
    public let parametros: ParametrosPaso
    public let contados: Int
    /// Instante (s desde el inicio) de cada paso contado. Sirve para ver *donde*
    /// se equivoca, que es mas util que saber que se equivoca.
    public let instantes: [Double]
    /// La senal derivada, muestra a muestra, para pintarla.
    public let traza: [AlgoritmoPasos.Salida]

    /// Cuanto se aleja del numero real. 0 es acertar.
    public var error: Int { contados - grabacion.repeticionesReales }
    public var acierta: Bool { error == 0 }
}

/// Un juego de parametros de paso probado contra todas las grabaciones.
public struct CandidatoDePasos: Sendable {
    public let parametros: ParametrosPaso
    /// Pasos que faltan sumados sobre las grabaciones de andar. Es el pecado
    /// grave, y el que dio origen al issue #35.
    public let faltantes: Int
    /// Pasos de mas sobre las grabaciones de andar.
    public let sobrantes: Int
    /// Lo mas lejos que ha llegado una grabacion de trampa.
    public let maximoEnTrampas: Int
    public let resultados: [ResultadoDePasos]

    public var aciertosExactos: Int {
        resultados.filter { $0.grabacion.tipo == .pasos && $0.acierta }.count
    }

    /// Puntuacion a minimizar. Los faltantes pesan el triple que los sobrantes:
    /// es la regla de producto escrita en aritmetica.
    public var puntuacion: Int { faltantes * 3 + sobrantes }
}

/// Pasa grabaciones de andar por `AlgoritmoPasos`, en frio y a toda velocidad.
///
/// El gemelo de `Reproductor` para el otro reto. Existe por la misma razon:
/// mientras el que contaba era `CMPedometer`, afinar el contador de pasos era
/// imposible —el algoritmo estaba dentro del sistema— y cada intento costaba
/// levantarse a andar por el pasillo. Ahora el contador es nuestro y una sesion
/// grabada se reproduce mil veces sin moverse de la silla.
public enum ReproductorDePasos {

    public static func reproduce(
        _ grabacion: Grabacion,
        parametros: ParametrosPaso = .porDefecto,
        conTraza: Bool = true
    ) -> ResultadoDePasos {
        var algoritmo = AlgoritmoPasos(parametros: parametros)
        var instantes: [Double] = []
        var traza: [AlgoritmoPasos.Salida] = []
        if conTraza { traza.reserveCapacity(grabacion.muestras.count) }

        for muestra in grabacion.muestras {
            let salida = algoritmo.procesa(
                t: muestra.t,
                aceleracionVertical: muestra.aceleracionVertical,
                gravedad: (muestra.gx, muestra.gy, muestra.gz)
            )
            if salida.pasoCompletado { instantes.append(salida.t) }
            if conTraza { traza.append(salida) }
        }

        return ResultadoDePasos(
            grabacion: grabacion,
            parametros: parametros,
            contados: algoritmo.pasos,
            instantes: instantes,
            traza: traza
        )
    }

    public static func evalua(
        _ grabaciones: [Grabacion],
        parametros: ParametrosPaso,
        conTraza: Bool = false
    ) -> CandidatoDePasos {
        // Las de sentadillas no pintan nada aqui: se calibra con lo que se anda
        // y con lo que se agita.
        let propias = grabaciones.filter { $0.tipo == .pasos || $0.tipo == .trampa }
        let resultados = propias.map {
            reproduce($0, parametros: parametros, conTraza: conTraza)
        }
        var faltantes = 0, sobrantes = 0, maximoEnTrampas = 0
        for r in resultados {
            switch r.grabacion.tipo {
            case .pasos:
                if r.error < 0 { faltantes -= r.error } else { sobrantes += r.error }
            case .trampa:
                maximoEnTrampas = max(maximoEnTrampas, r.contados)
            case .sentadillas:
                break
            }
        }
        return CandidatoDePasos(
            parametros: parametros,
            faltantes: faltantes,
            sobrantes: sobrantes,
            maximoEnTrampas: maximoEnTrampas,
            resultados: resultados
        )
    }

    /// Rejilla del barrido. Son los cuatro numeros que de verdad mueven el
    /// resultado; el resto se toca a mano mirando la curva.
    public struct Rejilla: Sendable {
        public var umbralMinimo: [Double]
        public var factorDeUmbral: [Double]
        public var intervaloMinimo: [Double]
        public var techoDePico: [Double]

        public init(
            umbralMinimo: [Double] = [0.15, 0.2, 0.3, 0.45, 0.6],
            factorDeUmbral: [Double] = [0.5, 0.6, 0.7, 0.85, 1.0],
            intervaloMinimo: [Double] = [0.18, 0.22, 0.25, 0.3],
            techoDePico: [Double] = [5, 6, 8, 10, 12]
        ) {
            self.umbralMinimo = umbralMinimo
            self.factorDeUmbral = factorDeUmbral
            self.intervaloMinimo = intervaloMinimo
            self.techoDePico = techoDePico
        }

        public var combinaciones: Int {
            umbralMinimo.count * factorDeUmbral.count
                * intervaloMinimo.count * techoDePico.count
        }
    }

    /// Prueba toda la rejilla contra todas las grabaciones y devuelve los
    /// mejores candidatos, del mas prometedor al menos.
    public static func barrido(
        _ grabaciones: [Grabacion],
        base: ParametrosPaso = .porDefecto,
        rejilla: Rejilla = Rejilla(),
        objetivo: Int = 20,
        maximoDeResultados: Int = 10
    ) -> [CandidatoDePasos] {
        // Sin una sola grabacion de andar, `faltantes` y `sobrantes` valen cero
        // para toda la rejilla: todo empata a puntuacion 0 y manda el desempate,
        // que ordena por margen contra la trampa. O sea que la herramienta que
        // existe para **aflojar** recomendaria el techo mas apretado de la
        // rejilla, que es exactamente al reves de la regla de producto. Mejor no
        // decir nada que decir eso.
        guard grabaciones.contains(where: { $0.tipo == .pasos }) else { return [] }

        var candidatos: [CandidatoDePasos] = []
        for umbral in rejilla.umbralMinimo {
            for factor in rejilla.factorDeUmbral {
                for intervalo in rejilla.intervaloMinimo {
                    for techo in rejilla.techoDePico {
                        var p = base
                        p.umbralMinimo = umbral
                        p.factorDeUmbral = factor
                        p.intervaloMinimo = intervalo
                        p.techoDePico = techo
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
