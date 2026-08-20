import SwiftUI

// Las superficies neumorficas de RepRise.
//
// La regla que lo sostiene todo: la luz viene de arriba a la izquierda y no se
// mueve nunca. Una pieza en relieve pone su sombra abajo a la derecha y su
// brillo arriba a la izquierda; una pieza hundida hace exactamente lo
// contrario. En cuanto una sola pieza contradice eso, el efecto se cae y la
// pantalla parece un error de renderizado.

extension View {
    /// Pieza que sobresale del fondo.
    public func relieve<F: InsettableShape>(
        _ nivel: Relieve = .medio,
        forma: F,
        color: Color = Paleta.superficie
    ) -> some View {
        background {
            forma
                .fill(color)
                .shadow(color: Paleta.sombra, radius: nivel.difuminado,
                        x: nivel.desplazamiento, y: nivel.desplazamiento)
                .shadow(color: Paleta.luz, radius: nivel.difuminado,
                        x: -nivel.desplazamiento, y: -nivel.desplazamiento)
                // Un filo de un pixel arriba: es lo que separa "una tarjeta
                // con sombra" de "una pieza de plastico".
                .overlay {
                    forma
                        .strokeBorder(
                            LinearGradient(
                                colors: [Paleta.filo, .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                }
        }
    }

    /// Pieza que se hunde en el fondo.
    public func hueco<F: InsettableShape>(
        _ nivel: Hundido = .marcado,
        forma: F,
        color: Color = Paleta.hueco
    ) -> some View {
        background {
            forma.fill(
                color
                    .shadow(.inner(color: Paleta.sombra, radius: nivel.difuminado,
                                   x: nivel.desplazamiento, y: nivel.desplazamiento))
                    .shadow(.inner(color: Paleta.luz, radius: nivel.difuminado,
                                   x: -nivel.desplazamiento, y: -nivel.desplazamiento))
            )
        }
    }

    /// Atajo para el caso de siempre: un rectangulo redondeado.
    public func relieve(_ nivel: Relieve = .medio, radio: CGFloat = Radio.medio,
                        color: Color = Paleta.superficie) -> some View {
        relieve(nivel, forma: RoundedRectangle(cornerRadius: radio, style: .continuous), color: color)
    }

    /// Atajo para el caso de siempre: un rectangulo redondeado.
    public func hueco(_ nivel: Hundido = .marcado, radio: CGFloat = Radio.medio,
                      color: Color = Paleta.hueco) -> some View {
        hueco(nivel, forma: RoundedRectangle(cornerRadius: radio, style: .continuous), color: color)
    }

    /// Fondo de pantalla. Va en la raiz de cada pantalla, no en cada trozo.
    public func fondoDePantalla(_ color: Color = Paleta.fondo) -> some View {
        background(color.ignoresSafeArea())
    }
}

#Preview("Superficies") {
    MuestraDeSuperficies().preferredColorScheme(.dark)
}

struct MuestraDeSuperficies: View {
    var body: some View {
        VStack(spacing: Espacio.amplio) {
            HStack(spacing: Espacio.normal) {
                Color.clear.frame(width: 80, height: 80).relieve(.bajo, radio: Radio.medio)
                Color.clear.frame(width: 80, height: 80).relieve(.medio, radio: Radio.medio)
                Color.clear.frame(width: 80, height: 80).relieve(.alto, forma: Circle(), color: Paleta.superficieAlta)
            }
            HStack(spacing: Espacio.normal) {
                Color.clear.frame(width: 80, height: 80).hueco(.sutil, radio: Radio.medio)
                Color.clear.frame(width: 80, height: 80).hueco(.marcado, radio: Radio.medio)
                Color.clear.frame(width: 80, height: 80).hueco(.marcado, forma: Circle())
            }
        }
        .padding(Espacio.enorme)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoDePantalla()
    }
}
