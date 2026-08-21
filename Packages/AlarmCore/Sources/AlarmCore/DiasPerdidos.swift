import Foundation

/// Los dias que se perdieron sin que nadie los contara.
///
/// El motor solo sabe de los dias que alguien le trae, y hay una forma de fallar
/// que no trae ninguno: el usuario pulsa "Stop" en la interfaz de AlarmKit, o no
/// se entera de que ha sonado, y no abre la app. Ahi no se ejecuta ni una linea
/// de codigo nuestro, asi que ese dia nunca llega a `StreakEngine` y la racha
/// sobrevive a una manana en la que nadie se levanto.
///
/// `docs/decisiones-producto.md` dice lo contrario —"se pierde la racha por:
/// pulsar Stop sin hacer el reto, ..., o ignorar la alarma"— asi que el hueco
/// hay que mirarlo desde fuera, al arrancar la app, comparando el calendario de
/// alarmas con hasta donde llego el motor.
///
/// Todo lo de aqui son funciones puras: entra el ultimo dia contado, el dia de
/// hoy y las alarmas, y sale la lista. Ninguna fecha del sistema.
public enum DiasPerdidos {

    /// Un dia que se perdio, con la alarma que sono en el. La alarma se arrastra
    /// porque el registro del dia la guarda, y sin ella el calendario no puede
    /// decir que reto se fallo.
    public struct Perdido: Hashable, Sendable {
        public let dia: Day
        public let alarmID: Alarm.ID
        public let challenge: ChallengeType

        public init(dia: Day, alarmID: Alarm.ID, challenge: ChallengeType) {
            self.dia = dia
            self.alarmID = alarmID
            self.challenge = challenge
        }
    }

    /// Cuantos dias hacia atras se mira como mucho.
    ///
    /// La racha se rompe con el primer dia perdido, asi que barrer dos anos no
    /// cambia el resultado y si cuesta una escritura por dia en el arranque. Un
    /// ano es de sobra para que el calendario del usuario que vuelve tenga
    /// sentido, y pone techo al caso feo: alguien mueve el reloj del movil a
    /// 2019 y al volver el hueco es de miles de dias.
    public static let topeDeDias = 366

    /// Los dias entre `ultimoContado` (excluido) y `hoy` (**excluido tambien**)
    /// en los que sono una alarma y no quedo registro.
    ///
    /// Hoy queda fuera a proposito: el dia en curso todavia se puede completar.
    /// Penalizarlo al abrir la app seria romperle la racha al que abre a las
    /// 06:31 justo para hacer el reto.
    ///
    /// - Parameters:
    ///   - ultimoContado: `StreakState.lastCountedDay`. Sirve de frontera y ya
    ///     dice todo lo que hace falta: resolver un dia lo mueve, asi que
    ///     cualquier dia posterior a el esta sin registro por definicion y no
    ///     hace falta preguntarle al historial.
    ///   - alarmas: las alarmas **efectivas**, es decir, ya pasadas por
    ///     `PoliticaDelPlan.alarmasEfectivas`. Si no, se penalizarian dias en los
    ///     que la alarma no sono porque el plan del usuario le habia quitado la
    ///     repeticion.
    public static func entre(
        ultimoContado: Day?,
        y hoy: Day,
        alarmas: [Alarm],
        calendario: Calendar = .current
    ) -> [Perdido] {
        // Usuario nuevo, o usuario que todavia no ha contado ni un dia: no hay
        // pasado que juzgar. Sin esta salida, instalar la app un jueves seria
        // empezar con un ano de fallos a la espalda.
        guard let ultimoContado else { return [] }

        // Solo cuentan las alarmas repetidas por dias de la semana. Una alarma de
        // un solo uso —la unica que tiene el plan gratis— suena "el proximo dia
        // que toque" y se apaga sola, y desde el estado guardado no hay forma de
        // saber que dia fue. Ante la duda no se inventa un fallo: el barrido solo
        // penaliza lo que se puede demostrar que estaba programado.
        let repetidas = alarmas.filter { $0.isEnabled && $0.repeats }
        guard !repetidas.isEmpty else { return [] }

        var dia = ultimoContado.adding(days: 1, calendar: calendario)
        let arranqueMinimo = hoy.adding(days: -Self.topeDeDias, calendar: calendario)
        if dia < arranqueMinimo { dia = arranqueMinimo }

        var salida: [Perdido] = []
        while dia < hoy {
            if let alarma = primeraAlarma(el: dia, entre: repetidas, calendario: calendario) {
                salida.append(Perdido(dia: dia, alarmID: alarma.id, challenge: alarma.challenge))
            }
            dia = dia.adding(days: 1, calendar: calendario)
        }
        return salida
    }

    /// La primera alarma que sono ese dia, o `nil` si no sono ninguna.
    ///
    /// Un dia es un dia: aunque suenen tres, el dia perdido es uno solo y se
    /// apunta con la mas temprana. Se ordena por hora y se desempata por `id`
    /// para que el registro guardado no dependa del orden en que vengan las
    /// alarmas ni cambie entre dos arranques.
    private static func primeraAlarma(
        el dia: Day,
        entre alarmas: [Alarm],
        calendario: Calendar
    ) -> Alarm? {
        let numero = calendario.component(.weekday, from: dia.date(calendar: calendario))
        guard let deLaSemana = Weekday(calendarWeekday: numero) else { return nil }

        return alarmas
            .filter { $0.weekdays.contains(deLaSemana) }
            .min {
                ($0.hour, $0.minute, $0.id.uuidString) < ($1.hour, $1.minute, $1.id.uuidString)
            }
    }
}
