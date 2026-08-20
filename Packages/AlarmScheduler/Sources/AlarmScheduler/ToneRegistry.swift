import Foundation

/// Que tono le toca a cada alarma, en disco.
///
/// Hace falta porque el momento en que la app necesita el dato es justo el peor:
/// el usuario ha pulsado el boton secundario de la alerta, la app arranca de
/// cero y tiene que seguir sonando con el mismo tono sin esperar a que nadie
/// cargue la base de datos. Son dos cadenas por alarma; `UserDefaults` sobra.
struct ToneRegistry {
    private static let clave = "reprise.tonos-por-alarma"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func toneID(for alarmID: UUID) -> String? {
        tabla()[alarmID.uuidString]
    }

    func record(toneID: String, for alarmID: UUID) {
        var tabla = tabla()
        tabla[alarmID.uuidString] = toneID
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
