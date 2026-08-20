import SwiftUI
import AlarmCore

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
public struct PantallaReto: View {
    private let reto: ChallengeType
    private let hechos: Int
    private let segundos: Int

    public init(reto: ChallengeType = .pasos, hechos: Int = 7, segundos: Int = 47) {
        self.reto = reto
        self.hechos = hechos
        self.segundos = segundos
    }

    private var completado: Bool { hechos >= reto.goal }
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
    }

    private var titular: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(completado ? "Ya está" : reto.instruccion)
                .estiloTitular()
                .foregroundStyle(Paleta.retoTinta)
            Text(completado ? "puedes apagarla" : "y se calla")
                .estiloTitular()
                // Gris sobre el fondo del reto, no `textoSuave`: este tiene que
                // seguir leyendose con los ojos a medio abrir.
                .foregroundStyle(Paleta.retoTinta.opacity(0.45))
        }
        .padding(.horizontal, Espacio.margen)
        .accessibilityElement(children: .combine)
    }

    private var contador: some View {
        VStack(spacing: Espacio.amplio) {
            AnilloDeProgreso(
                progreso: progreso,
                grosor: 14,
                colorArco: completado ? Paleta.retoTinta : Paleta.acento,
                colorPista: Paleta.retoApagado
            ) {
                TextoDeMatriz(
                    String(format: "%02d", min(hechos, reto.goal)),
                    altura: 118,
                    grosor: 0.72,
                    color: Paleta.retoTinta
                )
            }
            .frame(width: 300, height: 300)

            Text("de \(reto.goal) \(reto.unidad)")
                .font(Tipografia.rotulo)
                .tracking(Tipografia.abiertoRotulo)
                .textCase(.uppercase)
                .foregroundStyle(Paleta.retoTinta.opacity(0.45))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(hechos) de \(reto.goal) \(reto.unidad)"))
    }

    private var pie: some View {
        VStack(alignment: .leading, spacing: Espacio.normal) {
            HStack(alignment: .firstTextBaseline) {
                CifraConPrefijo(prefijo: minutos, cifra: restoDeSegundos, tamano: 30)
                Spacer()
                Text(completado ? "Arrastra para apagarla" : "No se apaga hasta terminar")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.retoTinta.opacity(completado ? 0.75 : 0.4))
            }
            DialDeApagado(desbloqueado: completado)
        }
        .padding(.horizontal, Espacio.margen)
    }
}

#Preview("Reto en curso · claro") {
    PantallaReto(reto: .pasos, hechos: 7, segundos: 47)
}

#Preview("Reto en curso · oscuro") {
    PantallaReto(reto: .pasos, hechos: 7, segundos: 47)
        .preferredColorScheme(.dark)
}

#Preview("Reto terminado · claro") {
    PantallaReto(reto: .sentadillas, hechos: 10, segundos: 62)
}

#Preview("Reto terminado · oscuro") {
    PantallaReto(reto: .sentadillas, hechos: 10, segundos: 62)
        .preferredColorScheme(.dark)
}
