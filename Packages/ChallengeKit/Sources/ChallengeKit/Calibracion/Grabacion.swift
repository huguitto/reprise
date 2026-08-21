import Foundation

/// Una muestra cruda de `CMDeviceMotion`, ya reducida a numeros.
///
/// Se guardan los vectores en bruto y no la aceleracion vertical ya calculada:
/// esa cuenta es parte de lo que se esta calibrando, y si la grabacion la
/// llevara hecha, cambiar de idea sobre como proyectar la vertical obligaria a
/// volver a grabar. Con los vectores crudos, no.
public struct MuestraDeMovimiento: Codable, Sendable, Hashable {
    /// Segundos desde el inicio de la grabacion.
    public let t: Double
    /// `userAcceleration` en g, marco del dispositivo.
    public let ax: Double, ay: Double, az: Double
    /// `gravity` en g, marco del dispositivo. Vector unitario apuntando al suelo.
    public let gx: Double, gy: Double, gz: Double

    public init(t: Double, ax: Double, ay: Double, az: Double, gx: Double, gy: Double, gz: Double) {
        self.t = t
        self.ax = ax; self.ay = ay; self.az = az
        self.gx = gx; self.gy = gy; self.gz = gz
    }

    /// Aceleracion del usuario proyectada sobre la vertical, en m/s^2 y positiva
    /// hacia arriba.
    ///
    /// `gravity` apunta hacia el suelo, asi que el producto escalar sale positivo
    /// cuando el movil acelera hacia abajo: de ahi el signo cambiado. Proyectar
    /// sobre la gravedad y no sobre un eje del movil es lo que hace que dé igual
    /// como se sujete el telefono.
    public var aceleracionVertical: Double {
        -(ax * gx + ay * gy + az * gz) * 9.80665
    }
}

/// Una sesion grabada: la senal cruda mas lo que la persona dice que hizo.
///
/// `repeticionesReales` es la verdad contra la que se mide todo. Sin ese numero
/// una grabacion no vale para calibrar, solo para mirar dibujos.
public struct Grabacion: Codable, Sendable, Identifiable, Hashable {

    /// Para que sirve la grabacion al calibrar.
    public enum Tipo: String, Codable, Sendable, Hashable {
        /// Sentadillas de verdad: aqui el detector tiene que acertar el numero.
        case sentadillas
        /// Trampa deliberada (agitar el movil sentado en la cama). Aqui el
        /// detector tiene que quedarse corto.
        case trampa
    }

    public let id: UUID
    public let fecha: Date
    public let tipo: Tipo
    /// Lo que hizo la persona de verdad. Para `.trampa`, normalmente 0.
    public let repeticionesReales: Int
    /// Con que mano, que persona, que estatura. El encargo pide probar las dos
    /// manos y estaturas distintas, y sin escribirlo aqui se pierde.
    public let etiqueta: String
    public let notas: String
    public let frecuenciaHz: Double
    public let muestras: [MuestraDeMovimiento]

    public init(
        id: UUID = UUID(),
        fecha: Date = Date(),
        tipo: Tipo = .sentadillas,
        repeticionesReales: Int,
        etiqueta: String,
        notas: String = "",
        frecuenciaHz: Double,
        muestras: [MuestraDeMovimiento]
    ) {
        self.id = id
        self.fecha = fecha
        self.tipo = tipo
        self.repeticionesReales = repeticionesReales
        self.etiqueta = etiqueta
        self.notas = notas
        self.frecuenciaHz = frecuenciaHz
        self.muestras = muestras
    }

    public var duracion: Double { muestras.last?.t ?? 0 }

    /// Nombre de fichero estable y legible de un vistazo en la app Archivos.
    public var nombreDeFichero: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        let limpia = etiqueta
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return "grabacion-\(f.string(from: fecha))-\(tipo.rawValue)-\(limpia).json"
    }
}
