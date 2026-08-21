import Foundation
import AlarmCore

/// Cuando suena una alarma, dicho en palabras.
///
/// Lo dicen dos sitios a la vez —la cabecera de la lista y el pie de cada
/// diapositiva del carrusel— y tiene que salir igual en los dos: dos frases
/// distintas para la misma alarma, a un centimetro una de otra, es justo lo que
/// hace dudar de si son la misma alarma.
extension Alarm {
    /// "Mañana a las 7:15".
    func cuandoSuenaEnPalabras(desde ahora: Date = Date(), calendario: Calendar = .current) -> String {
        let hora = String(format: "%d:%02d", hour, minute)
        guard let cuando = proximaVez(desde: ahora, calendario: calendario) else {
            // No deberia pasar nunca. Antes que inventarse un dia, la hora sola.
            return "A las \(hora)"
        }
        return "\(Self.diaEnPalabras(cuando, desde: ahora, calendario: calendario)) a las \(hora)"
    }

    /// "Hoy", "Mañana" o el nombre del dia. Mas alla de una semana no hace
    /// falta mas detalle: el dia de la semana ya es unico.
    ///
    /// Ponia "Mañana a las 7:30" pasara lo que pasara: a las seis de la manana,
    /// con la alarma puesta a las siete de ese mismo dia, la app decia que
    /// sonaba manana. Quien lo cuenta ahora es `Alarm.proximaVez`, que sabe de
    /// dias de la semana y esta probado en `AlarmCore`.
    static func diaEnPalabras(_ fecha: Date, desde ahora: Date = Date(), calendario: Calendar = .current) -> String {
        // Contra `ahora` y no contra el reloj del sistema: `isDateInToday` se
        // saltaba el parametro y hacia intestable el limite entre hoy y manana.
        let hoy = calendario.startOfDay(for: ahora)
        let dia = calendario.startOfDay(for: fecha)
        if dia == hoy { return "Hoy" }
        if dia == calendario.date(byAdding: .day, value: 1, to: hoy) { return "Mañana" }
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "es_ES")
        formato.dateFormat = "EEEE"
        // "El sábado", no "sábado": la cabecera es una frase, no una etiqueta.
        return "El \(formato.string(from: fecha))"
    }
}
