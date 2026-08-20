import Foundation

/// Los textos y el enlace de la ruta de permiso denegado.
///
/// Viven aqui, y no en la pantalla, porque son parte del contrato con el
/// usuario: una app despertador a la que le dices que no al permiso de alarmas
/// no sirve para nada, y hay que decirlo claro en vez de fallar en silencio o
/// dejar una lista de alarmas que nunca van a sonar.
public enum AlarmAuthorizationCopy {
    public static let titulo = "RepRise no puede despertarte"

    public static let explicacion = """
    Sin permiso de alarmas, iOS no deja que RepRise suene con la app cerrada, \
    ni que rompa el modo silencio o el modo de concentración. Es decir: no hay \
    despertador.

    El permiso se concede una sola vez y desde Ajustes.
    """

    public static let botonAjustes = "Abrir Ajustes"

    /// Aviso corto para la lista de alarmas mientras el permiso siga denegado.
    public static let avisoEnLista = "Estas alarmas no van a sonar: falta el permiso de alarmas."

    /// Ajustes de la app. Es el valor de `UIApplication.openSettingsURLString`,
    /// escrito a mano para no arrastrar `UIKit` (y su aislamiento en el hilo
    /// principal) hasta un simple texto. `nil` fuera de iOS.
    public static var urlDeAjustes: URL? {
        #if os(iOS)
        URL(string: "app-settings:")
        #else
        nil
        #endif
    }
}
