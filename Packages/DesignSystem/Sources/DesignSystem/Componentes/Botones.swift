import SwiftUI

/// Boton principal: una pastilla en relieve que **se hunde** al pulsarla.
///
/// El hundido no es un adorno: en una interfaz sin bordes ni sombras de
/// material, es la unica senal de que el dedo ha llegado.
public struct BotonPrincipal: ButtonStyle {
    private let acentuado: Bool

    public init(acentuado: Bool = true) {
        self.acentuado = acentuado
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pulsado = configuration.isPressed
        return configuration.label
            .font(Tipografia.cuerpoFuerte)
            .foregroundStyle(acentuado ? Color.white : Paleta.texto)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                if acentuado {
                    Capsule()
                        .fill(Paleta.acento)
                        .shadow(color: Paleta.acento.opacity(pulsado ? 0.15 : 0.35),
                                radius: pulsado ? 4 : 14, x: 0, y: pulsado ? 2 : 8)
                } else {
                    Color.clear.relieve(pulsado ? .bajo : .medio, forma: Capsule())
                }
            }
            .scaleEffect(pulsado ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: pulsado)
    }
}

/// Boton secundario: la misma pastilla, sin relleno de acento.
public struct BotonSecundario: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        let pulsado = configuration.isPressed
        return configuration.label
            .font(Tipografia.cuerpoFuerte)
            .foregroundStyle(Paleta.texto)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                if pulsado {
                    Color.clear.hueco(.sutil, forma: Capsule(), color: Paleta.superficie)
                } else {
                    Color.clear.relieve(.medio, forma: Capsule())
                }
            }
            .animation(.easeOut(duration: 0.12), value: pulsado)
    }
}

/// Boton de solo texto, para lo que no debe invitar: borrar, cancelar, salir.
public struct BotonDeTexto: ButtonStyle {
    private let color: Color
    private let fuente: Font

    public init(color: Color = Paleta.textoSuave, fuente: Font = Tipografia.cuerpoFuerte) {
        self.color = color
        self.fuente = fuente
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(fuente)
            .foregroundStyle(color.opacity(configuration.isPressed ? 0.5 : 1))
    }
}

/// Boton redondo de barra: el "mas" de la lista, el atras, el cerrar.
public struct BotonRedondo: ButtonStyle {
    private let diametro: CGFloat

    public init(diametro: CGFloat = 44) {
        self.diametro = diametro
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pulsado = configuration.isPressed
        return configuration.label
            .font(.system(size: diametro * 0.4, weight: .medium))
            .foregroundStyle(Paleta.texto)
            .frame(width: diametro, height: diametro)
            .background {
                if pulsado {
                    Color.clear.hueco(.sutil, forma: Circle(), color: Paleta.superficie)
                } else {
                    Color.clear.relieve(.bajo, forma: Circle())
                }
            }
            .animation(.easeOut(duration: 0.12), value: pulsado)
    }
}

extension ButtonStyle where Self == BotonPrincipal {
    public static var principal: BotonPrincipal { BotonPrincipal() }
    public static var principalSinAcento: BotonPrincipal { BotonPrincipal(acentuado: false) }
}

extension ButtonStyle where Self == BotonSecundario {
    public static var secundario: BotonSecundario { BotonSecundario() }
}

extension ButtonStyle where Self == BotonDeTexto {
    public static var texto: BotonDeTexto { BotonDeTexto() }
    public static var textoDeAviso: BotonDeTexto { BotonDeTexto(color: Paleta.acento) }
    /// Para la letra pequena: restaurar compras, condiciones legales.
    public static var textoMenudo: BotonDeTexto {
        BotonDeTexto(color: Paleta.textoTenue, fuente: Tipografia.pie)
    }
}

extension ButtonStyle where Self == BotonRedondo {
    public static var redondo: BotonRedondo { BotonRedondo() }
}

#Preview("Botones") {
    MuestraDeBotones().preferredColorScheme(.dark)
}

struct MuestraDeBotones: View {
    var body: some View {
        VStack(spacing: Espacio.normal) {
            Button("Guardar alarma") {}.buttonStyle(.principal)
            Button("Probar el tono") {}.buttonStyle(.secundario)
            HStack(spacing: Espacio.normal) {
                Button { } label: { Image(systemName: "plus") }.buttonStyle(.redondo)
                Button { } label: { Image(systemName: "chevron.left") }.buttonStyle(.redondo)
                Spacer()
                Button("Eliminar") {}.buttonStyle(.texto)
            }
        }
        .padding(Espacio.amplio)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoDePantalla()
    }
}
