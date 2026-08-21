import Foundation

/// Los numeros que deciden si un bache de la senal es un paso.
///
/// Como los de la sentadilla, **son provisionales**: salen de la fisica del
/// gesto y no de datos reales, y la forma honesta de fijarlos es grabar a
/// alguien andando y pasar la grabacion por `ReproductorDePasos.barrido(_:)`.
///
/// La regla de producto es la misma y va en una sola direccion: no contarle un
/// paso real a quien esta andando a las seis de la manana es mucho peor que
/// colar un movimiento raro. Ante la duda, aflojar. Esa asimetria es
/// precisamente la que `CMPedometer` tenia al reves —descartaba pasos de verdad
/// por no estar seguro de que fueran una caminata— y lo que hacia falta andar
/// sesenta pasos para que contara veinte.
public struct ParametrosPaso: Sendable, Hashable, Codable {

    // MARK: - Filtros de la senal

    /// Constante de tiempo del filtro que quita el sesgo del acelerometro (s).
    /// 0,4 s pone el corte en ~0,4 Hz.
    ///
    /// No es solo el sesgo de fabrica: lo que de verdad tiene que comerse es el
    /// **vaiven lento del movil girando en la mano** mientras se anda. Ese
    /// vaiven va por debajo de 0,2 Hz y, si sobrevive, hace dos destrozos a la
    /// vez: mueve la linea base para que las pisadas no crucen el liston, e
    /// infla `amplitudSuave`, que sube el liston. El banco de estres lo midio:
    /// con 1,5 s —el valor con el que nacio esto— una deriva de 1 m/s^2 dejaba
    /// **sin terminar el reto** a quien anda flojo (0,6 m/s^2 de pisada), y a
    /// quien anda normal le pedia 32 pasos para marcar 20. Es el issue #35 otra
    /// vez, con otra causa. Con 0,4 s no se queda encerrado nadie y el peor caso
    /// baja a 20.
    ///
    /// Por abajo no conviene bajar mas: el corte se acercaria a la cadencia mas
    /// lenta que hay que contar (1,3 pasos/s), que es la senal, no el ruido.
    public var tauSesgo: Double

    /// Constante de tiempo de cada una de las **dos** etapas del suavizado (s).
    /// 0,05 s pone el corte en ~3,2 Hz.
    ///
    /// Es el techo de lo que puede ser un paso: andar deprisa son 2,5 pasos/s y
    /// correr 3, asi que por debajo del corte cabe cualquier caminata. Lo que
    /// queda fuera es el temblor de muneca, que empieza donde acaba esto.
    public var tauSuavizado: Double

    /// Constante de tiempo con la que se estima la amplitud tipica de la senal (s).
    ///
    /// Lenta a proposito: el umbral tiene que seguir a como camina esta persona,
    /// no a como ha sido el ultimo paso. Con una constante corta, un paso fuerte
    /// subiria el liston justo a tiempo de descartar el siguiente.
    public var tauAmplitud: Double

    // MARK: - Forma del paso

    /// Suelo absoluto del umbral de pico (m/s^2).
    ///
    /// Es lo unico que separa un paso del ruido del sensor cuando el movil esta
    /// quieto. `userAcceleration` en reposo se mueve en centesimas, asi que 0,3
    /// deja un margen enorme y aun asi esta muy por debajo del arrastrar los
    /// pies de alguien recien despertado.
    public var umbralMinimo: Double

    /// Que fraccion de la amplitud tipica hay que superar para abrir un pico.
    ///
    /// Se compara contra la media de `|senal|`, que para una oscilacion vale
    /// 0,64 veces su pico: con 0,7 el liston queda en torno al 45 % del pico, o
    /// sea holgado. El umbral es adaptativo y no fijo porque la diferencia entre
    /// caminar decidido y arrastrar los pies es un factor de cinco, y un numero
    /// fijo o se come los pasos flojos o cuenta el ruido de los fuertes.
    public var factorDeUmbral: Double

    /// Techo del pico (m/s^2). Por encima de esto, lo que ha pasado no es una
    /// pisada.
    ///
    /// Es el anti-agite que de verdad funciona, y sale de medir las grabaciones
    /// reales. Lo que ensenaron tira abajo la suposicion comoda: la sacudida
    /// **no** es un temblor rapido. Da picos crudos de 65 m/s^2 —casi 7 g— pero
    /// su ritmo, 1,7 sacudidas por segundo, cae de lleno en la banda de andar.
    /// Por forma o por frecuencia no hay quien la distinga: las dos grabaciones
    /// de trampa van a **1,30 Hz**, que es exactamente la cadencia de la
    /// caminata grabada. Por fuerza si, y no por poco. Medido el 21/08/2026 con
    /// el iPhone en la mano, ya filtrado:
    ///
    /// | ya filtrado | mediana | p90 | maximo |
    /// |---|---|---|---|
    /// | andar despacio (1,2 pasos/s, 20 pasos) | 0,33 | 0,99 | 1,8 |
    /// | andar deprisa (1,5 pasos/s, 20 pasos) | — | 2,75 | **5,5** |
    /// | agitar el movil sentado (2 sesiones) | 2,0-2,8 | 9,7-11,0 | **18,9** |
    ///
    /// **Por que 6 y no 4.** Con el techo en 4 las dos caminatas cuentan 20
    /// clavados y las trampas caen a 5 y 0: parece la eleccion obvia y es una
    /// trampa. Coge esa misma caminata real y subele el volumen —que es lo que
    /// cambia de una persona a otra— y con el techo en 4 se hunde: **11 de 20**
    /// a 1,5 veces la fuerza, 7 a dos veces. En 6 aguanta 18 y 21, y el precio
    /// es contar 23 donde hubo 20 andando deprisa. Pasarse un 15% solo adelanta
    /// el final del reto; quedarse a la mitad deja a alguien encerrado con la
    /// alarma sonando, y eso cuesta el triple. Lo vigila el test
    /// `laMismaCaminataMasFuerteSigueContando`.
    ///
    /// Andar deprisa mas que duplica la fuerza de andar despacio (8,85 m/s^2
    /// crudos frente a 3,9), asi que con dos caminatas de la misma persona el
    /// margen que parece enorme no lo es: por arriba, la trampa mas floja de las
    /// dos grabadas ya solo esta a 2,7 veces del pico de andar deprisa.
    ///
    /// **Lo que este numero enseño de paso.** Antes de tener estas grabaciones,
    /// el techo se defendia de una pisada de 12-20 m/s^2 que parecia razonable
    /// —tanto, que llego a haber un `factorDePicoAtipico` para no dejar a cero a
    /// quien pisara asi—. Con el movil en la mano **eso no existe**: el maximo
    /// medido son 3,9 m/s^2 crudos. Aquel parametro se quito el mismo dia que
    /// llegaron los ficheros. Es la moraleja de la carpeta `Grabaciones`: sin
    /// medir, uno se defiende de fantasmas y le abre la puerta a lo real.
    ///
    /// **Lo que no frena, y conviene no engañarse:** mecer el movil suave y
    /// sostenido al ritmo de una zancada, con fuerza de caminata, produce la
    /// misma senal que andar. Ningun umbral sobre esta senal las separa. Esta
    /// escrito como test en `mecerElMovilAlRitmoDeUnaZancadaSiCuela`. Lo que si
    /// se frena es la trampa que la gente hace de verdad, que es fuerte: las dos
    /// grabadas se quedan en 7 y en 4.
    ///
    /// **El ritmo no vale, y aqui ponia que si.** Hasta el 21/08/2026 esta nota
    /// decia que el siguiente discriminador seria el ritmo, porque andar es
    /// metronomico y sacudir no. Se midio sobre las grabaciones y es falso: la
    /// trampa 213452 sale **mas regular** que la caminata buena (coeficiente de
    /// variacion de los intervalos 0,50 frente a 0,51; desviacion entre
    /// intervalos seguidos 0,31 frente a 0,51). Sacudir el movil a mano tiene
    /// tanto ritmo como andar. Otro fantasma, como el `factorDePicoAtipico`.
    ///
    /// Lo que si se separa, medido en la ventana de 1 s anterior a cada paso
    /// contado (72 pasos reales, 11 de trampa):
    ///
    /// | | andar | trampa |
    /// |---|---|---|
    /// | giro del vector gravedad | 3-57 deg/s | 15-201 deg/s |
    /// | reparto vertical/horizontal | 0,32-1,86 | 0,13-1,76 |
    ///
    /// Una puerta en `giro < 60 deg/s` tira 7 de los 11 pasos de trampa y **cero**
    /// de los 72 reales. Es el candidato serio y aun asi no esta puesto: las tres
    /// caminatas grabadas son de la misma persona sujetando el movil delante, y
    /// andar con el brazo colgando gira mucho mas. Sin una grabacion asi, esa
    /// puerta puede dejar encerrado a quien ande normal, que es el issue #35 otra
    /// vez y cuesta el triple. Hace falta grabar antes.
    public var techoDePico: Double

    /// Por debajo de que fraccion del umbral se da el pico por cerrado.
    /// Es histeresis: sin ella, el rizado de la cresta cuenta tres pasos.
    public var fraccionDeCierre: Double

    /// Tiempo minimo entre dos pasos contados (s). 0,25 s son 4 pasos/s, por
    /// encima de correr. Tapa el rebote de un mismo impacto.
    public var intervaloMinimo: Double

    /// Cuanta de la energia de la senal tiene que estar por debajo del corte del
    /// suavizado para creerse el paso.
    ///
    /// Se compara la amplitud de la senal suavizada con la de la cruda. Con las
    /// dos etapas del filtro a 50 Hz, lo que sobrevive es:
    ///
    /// | senal | 1,4 Hz | 2 Hz | 3 Hz | 4 Hz | 5 Hz | 6 Hz | 8 Hz |
    /// |---|---|---|---|---|---|---|---|
    /// | queda | 0,90 | 0,81 | 0,66 | 0,52 | 0,41 | 0,33 | 0,22 |
    ///
    /// Andar son 1,4-2,5 pasos/s y correr 3, asi que con el liston en 0,45 pasa
    /// cualquier caminata y se queda fuera lo que vibre por encima de 5 Hz.
    ///
    /// **Cuidado con lo que este numero aparenta.** Parece el filtro anti-agite y
    /// no lo es: sobre la grabacion de trampa real esta fraccion vale 0,79 y no
    /// descarta ni un pico, porque sacudir el movil no es vibrar rapido. Quien
    /// frena el agite es `techoDePico`; esto solo tapa el temblor fino, que es un
    /// caso que nadie ha visto todavia.
    ///
    /// Del lado bueno esta holgado y medido: en las grabaciones de movimiento
    /// real la fraccion es 0,95 de mediana y 0,86 en el peor decil, o sea el
    /// doble del liston. El ruido del sensor no la baja.
    public var fraccionDeBajaFrecuencia: Double

    // MARK: - Orientacion del movil

    /// Constante de tiempo con la que se promedia el giro del movil (s).
    ///
    /// Un paso dura medio segundo largo; con 1 s el promedio cubre el paso
    /// entero y el anterior, que es lo que hace falta para saber si el movil
    /// **viene** girando o si es un tiron suelto.
    public var tauGiro: Double

    /// Techo del giro del movil, en grados por segundo. Por encima de esto lo
    /// que ha movido el telefono es una mano, no un cuerpo andando.
    ///
    /// Es el discriminador que faltaba, y es el unico que ha sobrevivido a los
    /// datos. Se mide cuanto rota el vector `gravity` —o sea, cuanto cambia la
    /// inclinacion del movil— promediado sobre `tauGiro`, y se mira el maximo
    /// alcanzado mientras el pico estaba abierto.
    ///
    /// La razon fisica es simple: andando, el movil lo lleva un cuerpo y gira
    /// despacio aunque la mano se mueva; agitandolo o moviendo la muneca, el
    /// telefono **pivota**, que es justo lo que la gravedad ve. Medido el
    /// 21/08/2026 en la ventana de cada paso contado:
    ///
    /// | | giro medido |
    /// |---|---|
    /// | andar despacio (20 pasos) | 8-20 deg/s |
    /// | andar deprisa (20 pasos) | 10-57 deg/s |
    /// | agitar el movil sentado | 15-201 deg/s |
    /// | mover la muneca sentado | 52-173 deg/s |
    ///
    /// Con el techo en 60 no se cae **ni uno** de los 72 pasos reales grabados,
    /// y las tres trampas pasan de contar 4, 7 y 16 a contar 0, 2 y 1. Entre 45
    /// y 60 las trampas no se mueven, asi que se coge 60: el extremo que mas
    /// margen deja a quien anda, gratis.
    ///
    /// **El riesgo que este numero tiene y no esta cerrado.** Las tres
    /// caminatas grabadas son de la misma persona sujetando el movil delante.
    /// Andar con el brazo colgando hace pivotar el telefono mucho mas y podria
    /// pasarse de 60. Lo que impide que eso encierre a nadie es que el veto no
    /// es la ultima palabra: `CMPedometer` sigue contando por debajo via
    /// `FusionDePasos`, y el brazo balanceandose es precisamente su caso facil.
    /// El peor final posible no es quedarse a cero, es volver a la velocidad del
    /// podometro. Aun asi, hace falta grabar esa caminata.
    ///
    /// Cuando no hay dato de orientacion —el banco de estres sintetico, que solo
    /// genera aceleracion— el veto **no se aplica**: sin evidencia no se quita
    /// un paso.
    public var techoDeGiro: Double

    public init(
        tauSesgo: Double = 0.4,
        tauSuavizado: Double = 0.05,
        tauAmplitud: Double = 1.2,
        umbralMinimo: Double = 0.25,
        factorDeUmbral: Double = 1.1,
        techoDePico: Double = 6.0,
        fraccionDeCierre: Double = 0.5,
        intervaloMinimo: Double = 0.30,
        fraccionDeBajaFrecuencia: Double = 0.45,
        tauGiro: Double = 1.0,
        techoDeGiro: Double = 60.0
    ) {
        self.tauSesgo = tauSesgo
        self.tauSuavizado = tauSuavizado
        self.tauAmplitud = tauAmplitud
        self.umbralMinimo = umbralMinimo
        self.factorDeUmbral = factorDeUmbral
        self.techoDePico = techoDePico
        self.fraccionDeCierre = fraccionDeCierre
        self.intervaloMinimo = intervaloMinimo
        self.fraccionDeBajaFrecuencia = fraccionDeBajaFrecuencia
        self.tauGiro = tauGiro
        self.techoDeGiro = techoDeGiro
    }

    /// Los valores por defecto: la hipotesis de partida, sin calibrar.
    public static let porDefecto = ParametrosPaso()
}
