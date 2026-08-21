import Foundation
import AlarmCore

/// Todo lo que la pantalla de racha necesita para pintarse, de una pieza.
///
/// Existe para que la pantalla no tenga que recibir seis parametros sueltos y,
/// sobre todo, para que no pueda pintar la mitad con datos de verdad y la otra
/// mitad con datos de mentira. Eso es exactamente lo que pasaba antes: la racha
/// y las vidas entraban por parametro, pero el calendario y las insignias
/// estaban clavados a `DatosDeMentira` dentro de la propia vista, asi que
/// pasarle una racha de 0 seguia ensenando las insignias de una racha de 12.
///
/// Sigue sin hablar con persistencia: lo monta la app y se lo da hecho. El
/// sistema de diseno no sabe de discos.
public struct DatosDeRacha: Hashable, Sendable {
    public var estado: StreakState
    /// El plan manda en las vidas: cuantas hay y si se reponen siquiera.
    public var plan: PlanDeSuscripcion
    /// Los registros del mes de `hoy`. El calendario se queda solo con los de
    /// ese mes de todas formas, asi que pasar de mas no rompe nada.
    public var registrosDelMes: [DayRecord]
    /// El dia de hoy, ya convertido con el calendario del dispositivo. La vista
    /// no llama a `Date()` por su cuenta: asi se puede pintar cualquier dia en
    /// un `#Preview` y en las capturas.
    public var hoy: Day

    public init(
        estado: StreakState,
        plan: PlanDeSuscripcion,
        registrosDelMes: [DayRecord],
        hoy: Day
    ) {
        self.estado = estado
        self.plan = plan
        self.registrosDelMes = registrosDelMes
        self.hoy = hoy
    }

    public var racha: Int { estado.current }
    public var mejor: Int { estado.best }
    public var nivel: Nivel { Niveles.nivel(de: estado) }

    /// Las vidas que el usuario tiene **hoy**, no las que quedaron guardadas.
    ///
    /// Se pasan por el motor antes de ensenarlas por dos motivos, y los dos son
    /// mentiras que se veian en pantalla:
    ///
    ///   - Un usuario recien instalado arranca con `StreakState()`, que trae dos
    ///     vidas puestas. Si es de plan gratis no tiene ninguna, y hasta que
    ///     resolviera su primer dia veia dos corazones llenos que no existian.
    ///   - Un usuario de Pro que no abre la app desde el mes pasado tiene las
    ///     vidas del mes viejo guardadas, y le tocan las de este.
    ///
    /// Es una proyeccion, no una escritura: quien guarda la reposicion es el
    /// motor, al resolver el primer dia del mes.
    public var vidas: Int {
        StreakEngine.refillingLives(estado, on: hoy, plan: plan).livesRemaining
    }

    /// Insignias conseguidas, contra el estado de verdad.
    public var insignias: Set<Insignia> { Insignias.concedidas(estado) }

    // MARK: - De mentira

    /// El juego con el que se pintan los `#Preview`, la galeria de diseno y la
    /// presentacion. La app de verdad nunca pasa por aqui.
    public static let deMentira = DatosDeRacha(
        estado: DatosDeMentira.estadoDeRacha,
        plan: .pro,
        registrosDelMes: DatosDeMentira.mesDeEjemplo,
        hoy: DatosDeMentira.hoy
    )
}
