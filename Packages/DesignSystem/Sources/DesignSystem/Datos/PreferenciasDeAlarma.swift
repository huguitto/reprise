import Foundation
import AlarmCore
import AlarmScheduler

/// Lo que trae puesto una alarma recien creada.
///
/// Hasta el 21/08/2026 estas dos preferencias vivian en dos `@State` de
/// `PantallaAjustes`: se podian mover, se veian moverse y no llegaban a ningun
/// sitio. Al cerrar la hoja volvian a su valor de fabrica, y la alarma nueva
/// salia siempre con pasos y con el tono del sistema dijera lo que dijera
/// Ajustes. Un ajuste que no ajusta nada es peor que no tenerlo: el usuario lo
/// pone, se lo cree, y se entera de que no era verdad a las siete de la manana.
///
/// Van en `UserDefaults` y no en `Persistence` por lo mismo que la bandera de la
/// presentacion: no son estado de dominio —no entran en la racha, no migran de
/// esquema— y perderlas cuesta dos toques.
public enum PreferenciasDeAlarma {
    public static let claveDelReto = "reprise.retoPorDefecto"
    public static let claveDelTono = "reprise.tonoPorDefecto"

    /// El reto con el que sale una alarma nueva.
    ///
    /// Si lo guardado no se reconoce —una version vieja, alguien toqueteando
    /// los defaults— vuelve a pasos, que es el reto que puede hacer cualquiera
    /// en cualquier sitio.
    public static func reto(_ defaults: UserDefaults = .standard) -> ChallengeType {
        guard let crudo = defaults.string(forKey: claveDelReto),
              let reto = ChallengeType(rawValue: crudo)
        else { return .pasos }
        return reto
    }

    /// El tono con el que sale una alarma nueva.
    ///
    /// Se comprueba contra el catalogo antes de devolverlo: un id que ya no
    /// existe se cae al del sistema aqui, y no cuando suene.
    public static func tono(_ defaults: UserDefaults = .standard) -> String {
        guard let id = defaults.string(forKey: claveDelTono),
              ToneCatalog.tono(id: id) != nil
        else { return Tone.defaultID }
        return id
    }
}
