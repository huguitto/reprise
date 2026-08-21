import SwiftUI
import AlarmCore

/// En que punto esta el reto.
///
/// Lo decide quien tiene los sensores —la app, con `ChallengeKit`— y aqui solo
/// se pinta. La pantalla no sabe contar pasos ni sentadillas, y es a proposito:
/// asi se puede mirar entera desde la galeria y desde los `#Preview`, que es lo
/// unico que hay sin un iPhone en la mano.
public enum EstadoDelReto: Sendable, Hashable {
    /// Contando. Es el estado normal y casi todo el tiempo.
    case enMarcha
    /// Objetivo alcanzado: el dial se suelta y la alarma se puede apagar.
    case completado
    /// No hay con que contar —sin sensor o sin permiso de movimiento—, con el
    /// motivo ya escrito para el usuario.
    ///
    /// Suelta el dial igual que `completado`. No es generosidad: el reto que el
    /// telefono no puede medir no lo puede completar nadie, y dejar a alguien
    /// encerrado con la alarma sonando y sin salida es peor que perder el dia.
    case sinSensor(String)
}

/// El reto en curso. La pantalla mas importante de la app y la unica que
/// rompe las reglas visuales del resto.
///
/// Se mira a las seis de la manana, a oscuras, con los ojos a medio abrir y con
/// la alarma sonando. Ahi el neumorfismo no vale: vive de contrastes bajisimos
/// y a esa hora no se lee nada. Asi que aqui:
///
/// - fondo plano de maximo contraste (`retoFondo` / `retoTinta`), no `fondo`;
/// - el contador ocupa media pantalla y no lleva puntos apagados detras;
/// - de noche el fondo es casi negro. Encender una pantalla blanca en la cara
///   de alguien que acaba de abrir los ojos es una crueldad y ademas le hace
///   apartar la vista justo de la cifra que tiene que leer;
/// - cero adornos. Por decision de producto el unico feedback durante el reto
///   es el contador, asi que no hay animos, ni consejos, ni progreso social.
///
/// Ese contador es ademas la unica prueba que tiene el usuario de que el sensor
/// le esta viendo. Por eso cada repeticion que entra da un golpe de cifra y una
/// vibracion corta: no son adorno, son el acuse de recibo de "ese ha contado".
/// Sin el, quien lleva diez sentadillas y ve un 4 no sabe si va mal o si la app
/// esta muerta.
public struct PantallaReto: View {
    private let reto: ChallengeType
    private let hechos: Int
    private let segundos: Int
    private let estado: EstadoDelReto
    private let alApagar: () -> Void

    /// Los valores por defecto son los del muestrario, no los de la app: la
    /// galeria y los `#Preview` pintan esta pantalla sin nadie que la mueva.
    /// La app pasa siempre los cuatro.
    public init(
        reto: ChallengeType = .pasos,
        hechos: Int = 7,
        segundos: Int = 47,
        estado: EstadoDelReto = .enMarcha,
        alApagar: @escaping () -> Void = {}
    ) {
        self.reto = reto
        self.hechos = hechos
        self.segundos = segundos
        self.estado = estado
        self.alApagar = alApagar
    }

    /// El dial se suelta con el reto hecho y tambien cuando no hay con que
    /// contarlo. `hechos >= goal` entra aqui para que la galeria siga pudiendo
    /// ensenar el reto terminado pasando solo la cifra.
    private var desbloqueado: Bool {
        switch estado {
        case .completado, .sinSensor: true
        case .enMarcha: hechos >= reto.goal
        }
    }

    private var roto: Bool {
        if case .sinSensor = estado { return true }
        return false
    }

    private var progreso: Double { Double(hechos) / Double(reto.goal) }

    /// El cronometro partido en dos: los minutos van apagados y los segundos
    /// en tinta. Es el truco de la referencia 02, y ademas es lo correcto —
    /// 62 segundos se escriben 01:02, no 00:62.
    private var minutos: String { String(format: "%02d:", segundos / 60) }
    private var restoDeSegundos: String { String(format: "%02d", segundos % 60) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titular

            Spacer(minLength: Espacio.normal)

            contador
                .frame(maxWidth: .infinity)

            Spacer(minLength: Espacio.normal)

            pie
        }
        .padding(.vertical, Espacio.ancho)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Paleta.retoFondo.ignoresSafeArea())
        // El acuse de recibo del sensor, por si la cifra se mira de reojo:
        // un toque corto por repeticion y el de exito al llegar al objetivo.
        .sensoryFeedback(.impact(weight: .light), trigger: hechos)
        .sensoryFeedback(.success, trigger: desbloqueado) { antes, ahora in
            !antes && ahora && !roto
        }
    }

    private var titular: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(tituloPrimeraLinea)
                .estiloTitular()
                .foregroundStyle(Paleta.retoTinta)
            Text(tituloSegundaLinea)
                .estiloTitular()
                // Gris sobre el fondo del reto, no `textoSuave`: este tiene que
                // seguir leyendose con los ojos a medio abrir.
                .foregroundStyle(Paleta.retoTinta.opacity(0.45))
        }
        .padding(.horizontal, Espacio.margen)
        .accessibilityElement(children: .combine)
    }

    private var tituloPrimeraLinea: String {
        if roto { return "No se puede contar" }
        return desbloqueado ? "Ya está" : reto.instruccion
    }

    private var tituloSegundaLinea: String {
        if roto { return "puedes apagarla" }
        return desbloqueado ? "puedes apagarla" : "y se calla"
    }

    private var contador: some View {
        VStack(spacing: Espacio.amplio) {
            AnilloDeProgreso(
                progreso: progreso,
                grosor: 14,
                colorArco: desbloqueado ? Paleta.retoTinta : Paleta.acento,
                colorPista: Paleta.retoApagado
            ) {
                TextoDeMatriz(
                    String(format: "%02d", min(hechos, reto.goal)),
                    altura: 118,
                    grosor: 0.72,
                    color: Paleta.retoTinta
                )
                // El golpe de cifra: sube un 8% y vuelve. Dura poco mas de un
                // cuarto de segundo porque a cuatro pasos por segundo, uno mas
                // largo se solaparia consigo mismo y quedaria un temblor.
                .keyframeAnimator(initialValue: 1.0, trigger: hechos) { cifra, escala in
                    cifra.scaleEffect(escala)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        CubicKeyframe(1.08, duration: 0.10)
                        CubicKeyframe(1.0, duration: 0.16)
                    }
                }
            }
            .frame(width: 300, height: 300)

            Text(roto ? "el móvil no cuenta ahora mismo" : "de \(reto.goal) \(reto.unidad)")
                .font(Tipografia.rotulo)
                .tracking(Tipografia.abiertoRotulo)
                .textCase(.uppercase)
                .foregroundStyle(Paleta.retoTinta.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Espacio.margen)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(hechos) de \(reto.goal) \(reto.unidad)"))
    }

    private var pie: some View {
        VStack(alignment: .leading, spacing: Espacio.normal) {
            HStack(alignment: .firstTextBaseline) {
                CifraConPrefijo(prefijo: minutos, cifra: restoDeSegundos, tamano: 30)
                Spacer()
                Text(desbloqueado ? "Arrastra para apagarla" : "No se apaga hasta terminar")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.retoTinta.opacity(desbloqueado ? 0.75 : 0.4))
            }
            DialDeApagado(desbloqueado: desbloqueado, alApagar: alApagar)
        }
        .padding(.horizontal, Espacio.margen)
    }
}

#Preview("Reto en curso") {
    PantallaReto(reto: .pasos, hechos: 7, segundos: 47)
        .preferredColorScheme(.dark)
}

#Preview("Reto terminado") {
    PantallaReto(reto: .sentadillas, hechos: 10, segundos: 62, estado: .completado)
        .preferredColorScheme(.dark)
}

#Preview("Sin sensor") {
    PantallaReto(
        reto: .sentadillas,
        hechos: 0,
        segundos: 12,
        estado: .sinSensor("Sin permiso de movimiento")
    )
    .preferredColorScheme(.dark)
}
