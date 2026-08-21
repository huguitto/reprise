import Foundation
import AlarmCore

/// Lo que se le pidio al sistema la ultima vez que se programo cada alarma.
///
/// Existe por una limitacion de AlarmKit que costo un issue (#36): **no sabe
/// actualizar**. Programar sobre un `id` que ya tiene puesto no reemplaza la
/// configuracion, falla —con un `com.apple.AlarmKit.Alarm code=0 "(null)"` que
/// no explica nada— y hay que cancelar antes.
///
/// Cancelar y volver a poner en cada sincronizacion no vale: entre las dos
/// llamadas hay un instante en el que esa alarma no existe en el sistema, y
/// aqui se sincroniza muchas veces al dia. Con la huella solo se paga ese
/// instante cuando de verdad ha cambiado algo.
///
/// Del `AlarmKit.Alarm` que devuelve el sistema solo se puede leer el `id`, el
/// `schedule` y el estado: ni la etiqueta, ni el reto, ni el tono. Por eso la
/// comparacion se guarda por nuestra cuenta y no se le pregunta a el.
struct RegistroDeHuellas {
    private static let clave = "reprise.huellas-de-programacion"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func huella(de alarmID: UUID) -> String? {
        tabla()[alarmID.uuidString]
    }

    func record(_ huella: String, for alarmID: UUID) {
        var tabla = tabla()
        tabla[alarmID.uuidString] = huella
        defaults.set(tabla, forKey: Self.clave)
    }

    func forget(alarmID: UUID) {
        var tabla = tabla()
        tabla.removeValue(forKey: alarmID.uuidString)
        defaults.set(tabla, forKey: Self.clave)
    }

    /// Tira lo que ya no corresponde a ninguna alarma programada.
    func prune(keeping alarmIDs: Set<UUID>) {
        let vivos = Set(alarmIDs.map(\.uuidString))
        let tabla = tabla().filter { vivos.contains($0.key) }
        defaults.set(tabla, forKey: Self.clave)
    }

    private func tabla() -> [String: String] {
        defaults.dictionary(forKey: Self.clave) as? [String: String] ?? [:]
    }
}

extension DomainAlarm {
    /// Todo lo de la alarma que acaba dentro de la configuracion de AlarmKit, en
    /// una cadena.
    ///
    /// Estan los seis campos que cambian lo que el sistema hace: la hora y los
    /// dias van al `Schedule`, la etiqueta al titulo de la alerta, el reto al
    /// icono del boton y al `metadata`, y el tono al sonido. **No** estan
    /// `isEnabled` —una alarma apagada no se programa, se cancela— ni
    /// `creadaEn`, que solo ordena la lista.
    var huellaDeProgramacion: String {
        let dias = weekdays.sorted().map { String($0.rawValue) }.joined(separator: ",")
        // La etiqueta puede traer cualquier cosa, saltos de linea incluidos.
        // Va la ultima y con su longitud delante para que no se pueda colar un
        // separador y hacer que dos alarmas distintas den la misma huella.
        return "\(hour):\(minute)|\(dias)|\(challenge.rawValue)|\(toneID)|\(label.count)|\(label)"
    }
}
