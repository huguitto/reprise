import SwiftUI

/// El interruptor fisico de la referencia: un mando redondo que corre por un
/// canal hundido, con un pozo vacio esperando al otro lado.
///
/// En RepRise tiene un papel muy concreto. Por decision de producto la alarma
/// **no se calla hasta terminar el reto**, asi que este dial pasa casi todo el
/// tiempo bloqueado: esta ahi, se ve, y no se mueve. Cuando el reto termina se
/// suelta y hay que arrastrarlo hasta el final. No vale un toque: apagar la
/// alarma es un gesto deliberado, no un reflejo de medio dormido.
public struct DialDeApagado: View {
    private let desbloqueado: Bool
    private let alApagar: () -> Void

    @State private var arrastre: CGFloat = 0
    @State private var apagado = false

    public init(desbloqueado: Bool, alApagar: @escaping () -> Void = {}) {
        self.desbloqueado = desbloqueado
        self.alApagar = alApagar
    }

    private let alto: CGFloat = 96

    public var body: some View {
        GeometryReader { medida in
            let recorrido = medida.size.width - alto
            let avance = min(max(arrastre, 0), recorrido)

            ZStack(alignment: .leading) {
                // El canal y, al fondo del todo, el pozo que espera al mando.
                Color.clear
                    .hueco(.marcado, forma: Capsule())
                    .overlay(alignment: .trailing) {
                        Color.clear
                            .frame(width: alto - 20, height: alto - 20)
                            .hueco(.sutil, forma: Circle())
                            .overlay {
                                Image(systemName: apagado ? "checkmark" : "power")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(desbloqueado ? Paleta.acento : Paleta.textoTenue)
                            }
                            .padding(.trailing, 10)
                            .opacity(avance > recorrido * 0.6 ? 0 : 1)
                    }

                Mando(texto: apagado ? "Ya" : "Off", activo: desbloqueado)
                    .frame(width: alto, height: alto)
                    .offset(x: avance)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { gesto in
                                guard desbloqueado, !apagado else { return }
                                arrastre = gesto.translation.width
                            }
                            .onEnded { _ in
                                guard desbloqueado, !apagado else { return }
                                if avance > recorrido * 0.7 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        arrastre = recorrido
                                        apagado = true
                                    }
                                    alApagar()
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        arrastre = 0
                                    }
                                }
                            }
                    )
            }
            .animation(.easeOut(duration: 0.2), value: desbloqueado)
        }
        .frame(height: alto)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Apagar la alarma"))
        .accessibilityHint(Text(desbloqueado
                                ? "Arrastra hasta el final para apagarla"
                                : "Se desbloquea al terminar el reto"))
    }
}

private struct Mando: View {
    let texto: String
    let activo: Bool

    var body: some View {
        Text(texto)
            .font(Tipografia.cuerpoFuerte)
            .foregroundStyle(activo ? Paleta.texto : Paleta.textoTenue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .relieve(.alto, forma: Circle(), color: Paleta.superficieAlta)
    }
}

#Preview("Dial de apagado · claro") {
    MuestraDeDial()
}

#Preview("Dial de apagado · oscuro") {
    MuestraDeDial().preferredColorScheme(.dark)
}

struct MuestraDeDial: View {
    var body: some View {
        VStack(spacing: Espacio.enorme) {
            VStack(alignment: .leading, spacing: Espacio.medio) {
                Text("Bloqueado").estiloRotulo()
                DialDeApagado(desbloqueado: false)
            }
            VStack(alignment: .leading, spacing: Espacio.medio) {
                Text("Suelto").estiloRotulo()
                DialDeApagado(desbloqueado: true)
            }
        }
        .padding(Espacio.amplio)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoDePantalla()
    }
}
