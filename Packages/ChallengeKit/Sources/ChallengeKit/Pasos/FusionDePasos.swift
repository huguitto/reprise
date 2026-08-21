import Foundation

/// Junta las dos cuentas de pasos que corren a la vez y se queda con la mayor.
///
/// La buena es la nuestra: `AlgoritmoPasos` sobre la senal cruda, que cuenta al
/// instante. `CMPedometer` se queda como red por debajo, porque no cuesta nada
/// tenerlo escuchando y cubre el caso que nuestro algoritmo no vea venir —un
/// modo de andar raro, el movil sujeto de una forma que no habiamos probado—.
///
/// Se queda con el **maximo** y no con la suma, que contaria cada paso dos
/// veces, ni con el minimo, que seria volver a la latencia del podometro. Como
/// las dos fuentes miden lo mismo desde el mismo instante, el maximo nunca
/// inventa un paso que no haya dado nadie: como mucho, hace caso a la que se ha
/// enterado antes.
struct FusionDePasos {

    /// Lo que ha pasado al registrar algo. Son dos cosas distintas y hace falta
    /// separarlas: cuando una fuente va por delante de la otra, la de detras
    /// sigue viendo pasos de verdad aunque el numero de la pantalla no se mueva,
    /// y esos pasos tienen que contar como senal de vida. Si no, alguien podria
    /// estar andando mientras el vigilante de abandono lo da por parado y la
    /// alarma le vuelve a sonar en la cara.
    struct Avance {
        /// Ha habido pasos de verdad, los cuente quien los cuente.
        let hayPasos: Bool
        /// Y ademas mueven el numero que ve el usuario.
        let cambiaElTotal: Bool

        static let ninguno = Avance(hayPasos: false, cambiaElTotal: false)
    }

    let objetivo: Int

    /// Los que ha contado `AlgoritmoPasos`, de uno en uno segun ocurren.
    private(set) var propios = 0

    /// El acumulado que entrega `CMPedometer` desde que arranco el reto.
    private(set) var podometro = 0

    init(objetivo: Int) {
        self.objetivo = objetivo
    }

    var contados: Int { min(objetivo, max(propios, podometro)) }
    var terminado: Bool { contados >= objetivo }

    /// Un paso detectado por nosotros.
    mutating func paso() -> Avance {
        let antes = contados
        propios += 1
        return Avance(hayPasos: true, cambiaElTotal: contados > antes)
    }

    /// Una lectura del podometro. `numberOfSteps` es **acumulado** desde la
    /// fecha con la que se arrancaron las actualizaciones, no un incremento, asi
    /// que se guarda tal cual y las lecturas repetidas o hacia atras se ignoran.
    mutating func podometro(acumulados: Int) -> Avance {
        guard acumulados > podometro else { return .ninguno }
        let antes = contados
        podometro = acumulados
        return Avance(hayPasos: true, cambiaElTotal: contados > antes)
    }
}
