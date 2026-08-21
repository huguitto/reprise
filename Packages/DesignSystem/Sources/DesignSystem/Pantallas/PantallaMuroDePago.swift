import SwiftUI
import AlarmCore

/// Muro de pago.
///
/// La regla cambio el 21/08/2026 y esta pantalla iba retrasada: **las vidas son
/// de Pro**. Lo que sigue sin venderse es la racha misma —el dinero no
/// reconstruye una rota ni sube el contador— y las vidas sueltas por compra
/// puntual.
///
/// Hasta ese cambio aqui ponia "las vidas no se venden, ni ahora ni nunca",
/// que era una promesa explicita al usuario. Con las vidas ya cobrandose, esa
/// frase pasaba de ser el argumento de la app a ser una mentira cobrada, y por
/// eso se va entera en vez de suavizarse.
///
/// Lo que sigue igual es el motivo de que haya letra pequena: el limite de lo
/// que se vende solo cuenta si el usuario lo lee antes de pagar.
public struct PantallaMuroDePago: View {
    @State private var plan: Plan = .anual
    @State private var restaurando = false
    @State private var condiciones = false
    @Environment(\.dismiss) private var cerrar

    /// Por que se ha abierto el muro, si es que se ha abierto por topar con
    /// algo. `nil` = lo ha abierto el usuario desde Ajustes, sin motivo.
    ///
    /// No es lo mismo topar con el limite de alarmas que con la repeticion por
    /// dias: el usuario venia haciendo una cosa concreta y hay que responderle
    /// a esa, no soltarle el catalogo entero.
    private let motivo: RestriccionDelPlan?
    /// Contratar. `nil` = el boton solo cierra, que es lo que hace en la
    /// galeria de diseno.
    private let alContratar: (() -> Void)?

    public init(motivo: RestriccionDelPlan? = nil, alContratar: (() -> Void)? = nil) {
        self.motivo = motivo
        self.alContratar = alContratar
    }

    /// La frase de arriba, la que responde a lo que el usuario acababa de
    /// intentar. Los limites en numero salen de `PlanDeSuscripcion`, no
    /// escritos a mano: si manana cambia el precio del plan gratis, este texto
    /// va detras solo.
    private var explicacionDelMotivo: String? {
        switch motivo {
        case let .limiteDeAlarmasActivas(maximo):
            maximo == 1
                ? "Con la versión gratis solo puede haber una alarma activa. Esta se guardará cuando tengas Pro."
                : "Con la versión gratis solo pueden estar activas \(maximo) alarmas a la vez."
        case .repeticionPorDias:
            "Repetir una alarma en días concretos es de Pro. Sin ella, la alarma suena una vez y se apaga sola."
        case nil:
            nil
        }
    }

    enum Plan: Hashable {
        case mensual, anual
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                // "sin tocar la racha" ya no valia: con las vidas dentro de Pro,
                // pagar si protege la racha de un fallo.
                Cabecera("RepRise Pro", subtitulo: "la racha se gana") {
                    Button { cerrar() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Cerrar"))
                }

                if let explicacionDelMotivo {
                    Text(explicacionDelMotivo)
                        .font(Tipografia.cuerpo)
                        .foregroundStyle(Paleta.texto)
                        .padding(Espacio.normal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hueco(.sutil, radio: Radio.medio, color: Paleta.acentoTenue)
                        .padding(.horizontal, Espacio.margen)
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
                    Button("Empezar") {
                        alContratar?()
                        cerrar()
                    }
                    .buttonStyle(.principal)
                    // Los dos botones estaban vacios: se pulsaban y no pasaba
                    // nada. "Restaurar compras" no puede hacer nada de verdad
                    // hasta que haya StoreKit —no hay compra que restaurar— asi
                    // que lo dice, que es distinto de no responder.
                    HStack(spacing: Espacio.amplio) {
                        Button("Restaurar compras") { restaurando = true }
                            .buttonStyle(.textoMenudo)
                        Button("Condiciones") { condiciones = true }
                            .buttonStyle(.textoMenudo)
                    }
                    if restaurando {
                        Text("Todavía no hay compras que restaurar: el cobro por App Store aún no está montado.")
                            .font(Tipografia.pie)
                            .foregroundStyle(Paleta.textoSuave)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, Espacio.margen)

                VStack(alignment: .leading, spacing: Espacio.corto) {
                    Text("La racha no se compra.")
                        .font(Tipografia.pieFuerte)
                        .foregroundStyle(Paleta.texto)
                    Text("Pro te da 2 vidas cada mes para que un mal día no te la tire. Lo que no hace el dinero es reconstruir una racha ya rota ni subirte el contador: eso solo se gana levantándose.")
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
        .sheet(isPresented: $condiciones) { PantallaCondiciones() }
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
