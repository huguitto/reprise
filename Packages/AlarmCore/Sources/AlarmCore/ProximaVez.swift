import Foundation

public extension Alarm {
    /// Cuando va a sonar esta alarma a partir de un momento dado.
    ///
    /// Existe porque la cabecera de la lista ponia "Mañana a las 7:30" siempre,
    /// dijera lo que dijera la alarma: a las seis de la manana, con la alarma
    /// puesta a las siete de esa misma manana, la app te decia que sonaba
    /// manana. Y con una alarma de lunes y miercoles seguia diciendo "manana"
    /// cualquier dia de la semana.
    ///
    /// Reglas:
    ///
    ///   - Sin dias marcados es de un solo uso: suena hoy si esa hora todavia
    ///     no ha pasado, y si ya paso, manana.
    ///   - Con dias marcados, el primero de esos dias cuya hora aun no haya
    ///     pasado. Hoy cuenta si la hora esta por llegar.
    ///   - El minuto exacto cuenta como pasado: a las 7:30:00 en punto, la
    ///     alarma de las 7:30 es la de manana. Es lo que hace el sistema y es
    ///     lo que espera el usuario que acaba de apagarla.
    ///
    /// Devuelve `nil` solo si el calendario no sabe construir la fecha, que no
    /// deberia pasar nunca; quien lo llama tiene que decidir que ensena
    /// entonces, en vez de recibir una fecha inventada.
    func proximaVez(desde ahora: Date = Date(), calendario: Calendar = .current) -> Date? {
        // Ocho dias y no siete: el octavo es el mismo dia de la semana que hoy,
        // y hace falta para la alarma que solo se repite hoy y cuya hora ya ha
        // pasado. Con siete, esa alarma no encontraria hueco.
        for salto in 0...8 {
            guard let dia = calendario.date(byAdding: .day, value: salto, to: ahora),
                  let momento = calendario.date(
                      bySettingHour: hour, minute: minute, second: 0, of: dia
                  )
            else { continue }
            guard momento > ahora else { continue }
            if weekdays.isEmpty { return momento }
            guard let queDia = Weekday(
                calendarWeekday: calendario.component(.weekday, from: momento)
            ) else { continue }
            if weekdays.contains(queDia) { return momento }
        }
        return nil
    }
}
