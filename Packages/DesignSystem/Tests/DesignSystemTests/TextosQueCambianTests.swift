import Testing
import Foundation
import AlarmCore
import AlarmScheduler
@testable import DesignSystem

/// Los textos que estaban escritos a mano y no se movian.
///
/// Los tres decian algo falso en cuanto pasaba el tiempo: la cabecera de la
/// lista ponia "Mañana" siempre, el ranking se llamaba "de agosto" en
/// septiembre y la temporada acababa "el 31" tambien en febrero. Se prueban
/// aqui porque son cuentas, no dibujo.
@Suite("Textos que dependen de la fecha")
@MainActor
struct TextosQueCambianTests {
    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        c.locale = Locale(identifier: "es_ES")
        return c
    }

    private func fecha(_ dia: Int, _ mes: Int = 8, hora: Int = 7) -> Date {
        calendario.date(from: DateComponents(year: 2026, month: mes, day: dia, hour: hora))!
    }

    @Test("Hoy se dice Hoy, y mañana Mañana")
    func hoyYManana() {
        let ahora = fecha(21, hora: 6)
        #expect(PantallaListaDeAlarmas.cuandoSuena(fecha(21), desde: ahora, calendario: calendario) == "Hoy")
        #expect(PantallaListaDeAlarmas.cuandoSuena(fecha(22), desde: ahora, calendario: calendario) == "Mañana")
    }

    @Test("Hoy se calcula desde la fecha indicada, no desde el reloj del sistema")
    func hoyConRelojInyectado() {
        let ahora = fecha(10, 2, hora: 6)
        #expect(PantallaListaDeAlarmas.cuandoSuena(fecha(10, 2), desde: ahora, calendario: calendario) == "Hoy")
        #expect(PantallaListaDeAlarmas.cuandoSuena(fecha(11, 2), desde: ahora, calendario: calendario) == "Mañana")
    }

    @Test("Mas alla de mañana, el nombre del dia")
    func elDiaPorSuNombre() {
        // 24 de agosto de 2026 es lunes.
        let texto = PantallaListaDeAlarmas.cuandoSuena(fecha(24), desde: fecha(21, hora: 6), calendario: calendario)
        #expect(texto == "El lunes")
    }

    @Test("La temporada acaba el ultimo dia del mes, y febrero no tiene 31")
    func finDeTemporada() {
        #expect(PantallaRanking.ultimoDiaDelMes(fecha(10, 8), calendario: calendario) == 31)
        #expect(PantallaRanking.ultimoDiaDelMes(fecha(10, 2), calendario: calendario) == 28)
        #expect(PantallaRanking.ultimoDiaDelMes(fecha(10, 4), calendario: calendario) == 30)
    }

    @Test("El ranking se llama como el mes que es")
    func mesDelRanking() {
        #expect(PantallaRanking.mesDeLaTemporada(fecha(10, 9)) == "septiembre")
    }
}

/// Lo que trae puesto una alarma nueva.
@Suite("Preferencias de la alarma nueva")
struct PreferenciasDeAlarmaTests {
    /// Un `UserDefaults` propio por prueba: escribir en el `standard` de la
    /// maquina que corre los tests es dejar basura fuera del proceso.
    private func defaults(_ nombre: String) -> UserDefaults {
        let d = UserDefaults(suiteName: "pruebas.\(nombre)")!
        d.removePersistentDomain(forName: "pruebas.\(nombre)")
        return d
    }

    @Test("Sin nada guardado: pasos y el tono del sistema")
    func deFabrica() {
        let d = defaults("vacio")
        #expect(PreferenciasDeAlarma.reto(d) == .pasos)
        #expect(PreferenciasDeAlarma.tono(d) == Tone.defaultID)
    }

    @Test("Lo guardado se devuelve")
    func loGuardado() {
        let d = defaults("puesto")
        d.set(ChallengeType.sentadillas.rawValue, forKey: PreferenciasDeAlarma.claveDelReto)
        d.set("campana", forKey: PreferenciasDeAlarma.claveDelTono)
        #expect(PreferenciasDeAlarma.reto(d) == .sentadillas)
        #expect(PreferenciasDeAlarma.tono(d) == "campana")
    }

    /// Un tono que ya no esta en el catalogo —una version vieja, un fichero
    /// retirado— no puede quedarse pegado a todas las alarmas nuevas.
    @Test("Un valor que no se reconoce cae al de fabrica")
    func basura() {
        let d = defaults("basura")
        d.set("flexiones", forKey: PreferenciasDeAlarma.claveDelReto)
        d.set("tono-que-ya-no-existe", forKey: PreferenciasDeAlarma.claveDelTono)
        #expect(PreferenciasDeAlarma.reto(d) == .pasos)
        #expect(PreferenciasDeAlarma.tono(d) == Tone.defaultID)
    }
}
