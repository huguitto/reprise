import SwiftUI

/// Muro de pago.
///
/// La regla de producto es que **se vende todo lo que rodea a la racha y nunca
/// la racha**. Eso se dice en la pantalla, en la letra pequena, porque es
/// exactamente lo que diferencia a esta app de las que venden vidas: si el
/// argumento no se ve, no existe.
public struct PantallaMuroDePago: View {
    @State private var plan: Plan = .anual
    @Environment(\.dismiss) private var cerrar

    public init() {}

    enum Plan: Hashable {
        case mensual, anual
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("RepRise Pro", subtitulo: "sin tocar la racha") {
                    Button { cerrar() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Cerrar"))
                }

                VStack(alignment: .leading, spacing: Espacio.normal) {
                    ForEach(DatosDeMentira.ventajasPro, id: \.texto) { ventaja in
                        HStack(spacing: Espacio.medio) {
                            Image(systemName: ventaja.simbolo)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Paleta.acento)
                                .frame(width: 28)
                            Text(ventaja.texto)
                                .font(Tipografia.cuerpo)
                                .foregroundStyle(Paleta.texto)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(Espacio.normal)
                .relieve(.bajo, radio: Radio.medio)
                .padding(.horizontal, Espacio.margen)

                HStack(alignment: .top, spacing: Espacio.medio) {
                    TarjetaDePlan(
                        titulo: "Al mes",
                        precio: "3,99 EUR",
                        detalle: "Sin permanencia",
                        distintivo: nil,
                        elegido: plan == .mensual
                    ) { plan = .mensual }

                    TarjetaDePlan(
                        titulo: "Al año",
                        precio: "24,99 EUR",
                        detalle: "2,08 EUR al mes",
                        distintivo: "Ahorras un 48 %",
                        elegido: plan == .anual
                    ) { plan = .anual }
                }
                .padding(.horizontal, Espacio.margen)

                VStack(spacing: Espacio.medio) {
                    Button("Empezar") {}.buttonStyle(.principal)
                    HStack(spacing: Espacio.amplio) {
                        Button("Restaurar compras") {}.buttonStyle(.textoMenudo)
                        Button("Condiciones") {}.buttonStyle(.textoMenudo)
                    }
                }
                .padding(.horizontal, Espacio.margen)

                VStack(alignment: .leading, spacing: Espacio.corto) {
                    Text("Las vidas no se venden.")
                        .font(Tipografia.pieFuerte)
                        .foregroundStyle(Paleta.texto)
                    Text("Ni ahora ni nunca. Comprar vidas convertiría el ranking en una lista de quien paga más, y entonces la racha dejaría de significar nada.")
                        .font(Tipografia.pie)
                        .foregroundStyle(Paleta.textoSuave)
                }
                .padding(Espacio.normal)
                .hueco(.sutil, radio: Radio.medio)
                .padding(.horizontal, Espacio.margen)
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
    }
}

private struct TarjetaDePlan: View {
    let titulo: String
    let precio: String
    let detalle: String
    let distintivo: String?
    let elegido: Bool
    let alPulsar: () -> Void

    var body: some View {
        Button(action: alPulsar) {
            VStack(alignment: .leading, spacing: Espacio.corto) {
                Text(titulo)
                    .font(Tipografia.rotulo)
                    .tracking(Tipografia.abiertoRotulo)
                    .textCase(.uppercase)
                    .foregroundStyle(Paleta.textoSuave)
                Text(precio)
                    .font(Tipografia.cifra(22, .bold))
                    .foregroundStyle(Paleta.texto)
                Text(detalle)
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
                // El hueco del distintivo se reserva siempre, tenga o no
                // texto: si no, las dos tarjetas salen con alturas distintas y
                // parece que una este rota.
                Group {
                    if let distintivo {
                        Pastilla(distintivo, acentuada: true)
                    } else {
                        Pastilla("").opacity(0)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Espacio.normal)
            .background {
                if elegido {
                    RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                        .fill(Paleta.superficieAlta)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                                .strokeBorder(Paleta.acento, lineWidth: 2)
                        }
                        .shadow(color: Paleta.sombra, radius: 10, x: 5, y: 5)
                } else {
                    Color.clear.hueco(.sutil, radio: Radio.medio, color: Paleta.hueco)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: elegido)
        .accessibilityAddTraits(elegido ? [.isSelected] : [])
    }
}

#Preview("Muro de pago") {
    PantallaMuroDePago().preferredColorScheme(.dark)
}
