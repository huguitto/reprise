import Testing
import Foundation
@testable import AlarmCore

/// Lo que el plan gratis no deja hacer, y lo que pasa cuando se paga o se deja
/// de pagar a mitad de mes.
///
/// Las vidas se prueban aqui y no en el banco del motor porque ahi todo corre
/// con Pro. Aqui esta el otro lado: sin vidas no hay red, y un fallo del plan
/// gratis rompe la racha en el acto.
@Suite("Limites del plan")
struct LimitesDelPlanTests {

    private let alarmID = UUID()
    private func dia(_ d: Int, mes: Int = 8, ano: Int = 2026) -> Day {
        Day(year: ano, month: mes, day: d)
    }

    private func alarma(
        _ hora: Int,
        dias: Set<Weekday> = [],
        encendida: Bool = true,
        id: UUID = UUID()
    ) -> Alarm {
        Alarm(id: id, hour: hora, minute: 0, weekdays: dias, challenge: .pasos, isEnabled: encendida)
    }

    // MARK: - Vidas

    @Test("En gratis no hay vidas: el primer fallo rompe la racha")
    func gratisNoTieneVidas() {
        let state = StreakState(current: 30, best: 30,
                                livesRefilledYearMonth: dia(1).yearMonth,
                                diasCompletadosTotales: 30)
        let salida = StreakEngine.apply(outcome: .fallado(.paroSinReto), on: dia(10),
                                        alarmID: alarmID, challenge: .pasos,
                                        to: state, plan: .gratis)

        #expect(salida.state.current == 0, "sin vidas, el fallo se cobra entero")
        #expect(salida.record.outcome == .fallado(.paroSinReto), "y no se puede leer como salvado")
        #expect(salida.state.best == 30, "el record no se toca")
        #expect(salida.state.diasCompletadosTotales == 30, "lo acumulado tampoco")
    }

    @Test("El mes nuevo no le repone vidas al plan gratis")
    func gratisNoReponeVidas() {
        let state = StreakState(current: 5, livesRemaining: 0, livesRefilledYearMonth: dia(1).yearMonth)
        let repuesto = StreakEngine.refillingLives(state, on: dia(1, mes: 9), plan: .gratis)

        #expect(repuesto.livesRemaining == 0)
        #expect(repuesto.livesRefilledYearMonth == dia(1, mes: 9).yearMonth,
                "el sello del mes se pone igual, o se reintentaria en cada arranque")
    }

    @Test("La suscripcion caducada se lleva las vidas que quedaban del mes")
    func caducarRecortaLasVidasDelMes() {
        // Pro el dia 1, con las dos vidas puestas. Deja de pagar el dia 12.
        let state = StreakState(current: 20, livesRemaining: 2, livesRefilledYearMonth: dia(1).yearMonth)
        let recortado = StreakEngine.refillingLives(state, on: dia(12), plan: .gratis)

        #expect(recortado.livesRemaining == 0,
                "las vidas son de Pro: no se quedan hasta fin de mes")
    }

    @Test("Comprar Pro a mitad de mes da las vidas en el acto")
    func comprarProDaLasVidasYa() {
        let state = StreakState(current: 4, livesRemaining: 0, livesRefilledYearMonth: dia(1).yearMonth)
        let conPro = StreakEngine.changingPlan(state, from: .gratis, to: .pro, on: dia(17))

        #expect(conPro.livesRemaining == StreakState.livesPerMonth,
                "quien acaba de pagar no espera al dia 1")
        #expect(conPro.current == 4, "y la racha no se toca al cambiar de plan")
    }

    @Test("Dejar Pro recorta las vidas en el acto")
    func dejarProRecortaYa() {
        let state = StreakState(current: 4, livesRemaining: 2, livesRefilledYearMonth: dia(1).yearMonth)
        let sinPro = StreakEngine.changingPlan(state, from: .pro, to: .gratis, on: dia(17))

        #expect(sinPro.livesRemaining == 0)
        #expect(sinPro.current == 4, "la racha ganada no se pierde por dejar de pagar")
    }

    @Test("Renovar el mismo plan no toca nada")
    func mismoPlanNoTocaNada() {
        let state = StreakState(current: 9, livesRemaining: 1, livesRefilledYearMonth: dia(1).yearMonth)
        #expect(StreakEngine.changingPlan(state, from: .pro, to: .pro, on: dia(17)) == state)
    }

    @Test("Comprar Pro no resucita una racha ya rota")
    func comprarProNoResucitaLaRacha() {
        // Importa: si pagar devolviera la racha, se estaria vendiendo la racha.
        var state = StreakState(current: 30, best: 30, livesRefilledYearMonth: dia(1).yearMonth)
        state = StreakEngine.apply(outcome: .fallado(.ignorada), on: dia(10),
                                   alarmID: nil, challenge: nil, to: state, plan: .gratis).state
        #expect(state.current == 0)

        let conPro = StreakEngine.changingPlan(state, from: .gratis, to: .pro, on: dia(10))
        #expect(conPro.current == 0, "la vida comprada llega tarde: el dia ya estaba resuelto")
    }

    // MARK: - Alarmas: el corte de antes

    @Test("En gratis la segunda alarma encendida no se puede guardar")
    func gratisSoloUnaAlarmaEncendida() {
        let ya = alarma(7)
        let motivo = PoliticaDelPlan.alGuardar(alarma(8), entre: [ya], plan: .gratis)
        #expect(motivo == .limiteDeAlarmasActivas(maximo: 1))
    }

    @Test("Editar la alarma que ya estaba encendida no cuenta como una segunda")
    func editarLaPropiaNoCuenta() {
        let id = UUID()
        let ya = alarma(7, id: id)
        var editada = ya
        editada.hour = 9
        #expect(PoliticaDelPlan.alGuardar(editada, entre: [ya], plan: .gratis) == nil)
    }

    @Test("En gratis una segunda alarma apagada si se guarda")
    func laSegundaApagadaSeGuarda() {
        let ya = alarma(7)
        #expect(PoliticaDelPlan.alGuardar(alarma(8, encendida: false), entre: [ya], plan: .gratis) == nil)
    }

    @Test("Con la primera apagada, encender otra vale")
    func encenderOtraConLaPrimeraApagada() {
        let apagada = alarma(7, encendida: false)
        #expect(PoliticaDelPlan.alGuardar(alarma(8), entre: [apagada], plan: .gratis) == nil)
    }

    @Test("En gratis la repeticion por dias no se puede guardar")
    func gratisSinRepeticion() {
        let motivo = PoliticaDelPlan.alGuardar(alarma(7, dias: [.lunes, .martes]), entre: [], plan: .gratis)
        #expect(motivo == .repeticionPorDias)
    }

    @Test("La repeticion se corta tambien con la alarma apagada")
    func laRepeticionSeCortaAunApagada() {
        // Si no, el usuario configura de lunes a viernes, la enciende y se
        // encuentra con que suena un solo dia sin que nadie se lo haya dicho.
        let motivo = PoliticaDelPlan.alGuardar(
            alarma(7, dias: [.lunes], encendida: false), entre: [], plan: .gratis)
        #expect(motivo == .repeticionPorDias)
    }

    @Test("En gratis la alarma de un solo uso pasa")
    func gratisAlarmaDeUnSoloUso() {
        #expect(PoliticaDelPlan.alGuardar(alarma(7), entre: [], plan: .gratis) == nil)
    }

    @Test("Con Pro no topa nada de esto")
    func proNoTopa() {
        let ya = [alarma(6), alarma(7), alarma(8)]
        #expect(PoliticaDelPlan.alGuardar(alarma(9, dias: Set(Weekday.allCases)), entre: ya, plan: .pro) == nil)
    }

    // MARK: - Alarmas: el filtro de despues

    @Test("Al caducar Pro solo queda encendida la primera, y sin dias")
    func alCaducarSoloSobreviveLaPrimera() {
        let guardadas = [
            alarma(6, dias: [.lunes, .martes, .miercoles, .jueves, .viernes]),
            alarma(7, dias: [.sabado]),
            alarma(8, encendida: false),
            alarma(9)
        ]

        let efectivas = PoliticaDelPlan.alarmasEfectivas(guardadas, plan: .gratis)

        #expect(efectivas.map(\.isEnabled) == [true, false, false, false])
        #expect(efectivas[0].weekdays.isEmpty, "sin Pro la alarma es de un solo uso")
        #expect(efectivas.count == guardadas.count, "no se borra ninguna: solo se apagan")
    }

    @Test("Lo guardado no se toca: al volver a Pro esta todo donde estaba")
    func volverAProLoDevuelveTodo() {
        // La clave de la degradacion: `alarmasEfectivas` es una lectura, no una
        // escritura. Si se guardase su salida, recuperar Pro dejaria al usuario
        // con las alarmas apagadas y los dias borrados para siempre.
        let guardadas = [
            alarma(6, dias: [.lunes, .martes]),
            alarma(7, dias: [.sabado, .domingo])
        ]
        _ = PoliticaDelPlan.alarmasEfectivas(guardadas, plan: .gratis)

        #expect(PoliticaDelPlan.alarmasEfectivas(guardadas, plan: .pro) == guardadas)
    }

    @Test("Con Pro las alarmas efectivas son las guardadas, tal cual")
    func conProNoSeFiltraNada() {
        let guardadas = [alarma(6), alarma(7, dias: [.lunes]), alarma(8)]
        #expect(PoliticaDelPlan.alarmasEfectivas(guardadas, plan: .pro) == guardadas)
    }

    @Test("El orden decide cual sobrevive, y no cambia entre arranques")
    func sobreviveLaPrimeraDeLaLista() {
        let guardadas = [alarma(6), alarma(7)]
        let una = PoliticaDelPlan.alarmasEfectivas(guardadas, plan: .gratis)
        let otra = PoliticaDelPlan.alarmasEfectivas(guardadas, plan: .gratis)

        #expect(una == otra, "dos lecturas seguidas tienen que dar lo mismo")
        #expect(una.first(where: \.isEnabled)?.hour == 6)
    }

    @Test("Los limites de cada plan son los de la ficha de producto")
    func laFichaDeProducto() {
        #expect(PlanDeSuscripcion.gratis.limites.maximoDeAlarmasActivas == 1)
        #expect(PlanDeSuscripcion.gratis.limites.permiteRepeticionPorDias == false)
        #expect(PlanDeSuscripcion.gratis.limites.vidasAlMes == 0)

        #expect(PlanDeSuscripcion.pro.limites.maximoDeAlarmasActivas == nil)
        #expect(PlanDeSuscripcion.pro.limites.permiteRepeticionPorDias)
        #expect(PlanDeSuscripcion.pro.limites.vidasAlMes == StreakState.livesPerMonth)
    }
}
