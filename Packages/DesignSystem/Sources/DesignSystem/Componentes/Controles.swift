import SwiftUI

/// Interruptor neumorfico: canal hundido y mando en relieve.
///
/// No usa el `Toggle` del sistema a proposito. El de iOS es una pieza de
/// material distinto y en medio de esta pantalla canta como un injerto.
public struct Interruptor: View {
    @Binding private var encendido: Bool

    public init(encendido: Binding<Bool>) {
        self._encendido = encendido
    }

    private let ancho: CGFloat = 56
    private let alto: CGFloat = 32

    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                encendido.toggle()
            }
        } label: {
            ZStack(alignment: encendido ? .trailing : .leading) {
                Capsule()
                    .fill(encendido ? Paleta.acento : Color.clear)
                    .hueco(.sutil, forma: Capsule())

                // Las dos sombras, no solo la oscura: sobre el canal de acento
                // el mando necesita el brillo de arriba a la izquierda o parece
                // un agujero en vez de una pieza que sobresale.
                Circle()
                    .fill(Paleta.superficieAlta)
                    .shadow(color: Paleta.sombra, radius: 3, x: 2, y: 2)
                    .shadow(color: Paleta.luz, radius: 3, x: -1, y: -1)
                    .padding(3)
            }
            .frame(width: ancho, height: alto)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(encendido ? "Activada" : "Desactivada"))
    }
}

/// Selector de una opcion entre varias, en pastilla hundida con el mando en
/// relieve encima. Es el mismo lenguaje que el dial: algo que corre por un
/// canal.
public struct SelectorSegmentado<Opcion: Hashable>: View {
    private let opciones: [Opcion]
    private let titulo: (Opcion) -> String
    @Binding private var seleccion: Opcion
    @Namespace private var animacion

    public init(
        opciones: [Opcion],
        seleccion: Binding<Opcion>,
        titulo: @escaping (Opcion) -> String
    ) {
        self.opciones = opciones
        self._seleccion = seleccion
        self.titulo = titulo
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(opciones, id: \.self) { opcion in
                let elegida = opcion == seleccion
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        seleccion = opcion
                    }
                } label: {
                    Text(titulo(opcion))
                        .font(Tipografia.pieFuerte)
                        .foregroundStyle(elegida ? Paleta.texto : Paleta.textoSuave)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if elegida {
                                Color.clear
                                    .relieve(.bajo, forma: Capsule(), color: Paleta.superficieAlta)
                                    .matchedGeometryEffect(id: "mando", in: animacion)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .hueco(.sutil, forma: Capsule())
    }
}

/// Campo de texto hundido. En esta app se usa exactamente una vez: la etiqueta
/// de la alarma.
public struct CampoDeTexto: View {
    private let marcador: String
    @Binding private var texto: String

    public init(_ marcador: String, texto: Binding<String>) {
        self.marcador = marcador
        self._texto = texto
    }

    public var body: some View {
        TextField(marcador, text: $texto)
            .textFieldStyle(.plain)
            .font(Tipografia.cuerpo)
            .foregroundStyle(Paleta.texto)
            .padding(.horizontal, Espacio.normal)
            .padding(.vertical, 14)
            .hueco(.marcado, radio: Radio.chico)
    }
}

/// Fila de ajuste: rotulo a la izquierda, lo que sea a la derecha.
///
/// Todas las listas de la app son esta fila. Que no haya dos maneras de
/// presentar una opcion es la mitad de lo que hace que parezca un producto.
public struct FilaDeAjuste<Derecha: View>: View {
    private let icono: String?
    private let titulo: String
    private let detalle: String?
    private let derecha: Derecha

    public init(
        icono: String? = nil,
        titulo: String,
        detalle: String? = nil,
        @ViewBuilder derecha: () -> Derecha = { EmptyView() }
    ) {
        self.icono = icono
        self.titulo = titulo
        self.detalle = detalle
        self.derecha = derecha()
    }

    public var body: some View {
        HStack(spacing: Espacio.medio) {
            if let icono {
                Image(systemName: icono)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Paleta.textoSuave)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(Tipografia.cuerpo)
                    .foregroundStyle(Paleta.texto)
                if let detalle {
                    Text(detalle)
                        .font(Tipografia.pie)
                        .foregroundStyle(Paleta.textoSuave)
                }
            }
            Spacer(minLength: Espacio.medio)
            derecha
        }
        .padding(.horizontal, Espacio.normal)
        .padding(.vertical, 14)
    }
}

/// Variante de `FilaDeAjuste` para controles anchos.
///
/// Un selector segmentado no cabe al lado del rotulo: le roba el sitio y parte
/// el titulo en columnas de una palabra. Cuando el control necesita el ancho
/// entero, va debajo.
public struct FilaApilada<Control: View>: View {
    private let icono: String?
    private let titulo: String
    private let control: Control

    public init(icono: String? = nil, titulo: String, @ViewBuilder control: () -> Control) {
        self.icono = icono
        self.titulo = titulo
        self.control = control()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            HStack(spacing: Espacio.medio) {
                if let icono {
                    Image(systemName: icono)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Paleta.textoSuave)
                        .frame(width: 24)
                }
                Text(titulo)
                    .font(Tipografia.cuerpo)
                    .foregroundStyle(Paleta.texto)
                Spacer(minLength: 0)
            }
            control
        }
        .padding(.horizontal, Espacio.normal)
        .padding(.vertical, 14)
    }
}

/// Grupo de filas dentro de una sola pieza en relieve, con separadores finos.
public struct Bloque<Contenido: View>: View {
    private let contenido: Contenido

    public init(@ViewBuilder contenido: () -> Contenido) {
        self.contenido = contenido()
    }

    public var body: some View {
        VStack(spacing: 0) {
            contenido
        }
        .relieve(.bajo, radio: Radio.medio)
    }
}

/// Separador entre filas de un `Bloque`.
public struct Raya: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Paleta.textoTenue.opacity(0.25))
            .frame(height: 1)
            .padding(.leading, Espacio.normal)
    }
}

#Preview("Controles") {
    MuestraDeControles().preferredColorScheme(.dark)
}

struct MuestraDeControles: View {
    @State private var encendido = true
    @State private var apagado = false
    @State private var ambito = "Mundial"
    @State private var etiqueta = ""

    var body: some View {
        VStack(spacing: Espacio.amplio) {
            HStack(spacing: Espacio.amplio) {
                Interruptor(encendido: $encendido)
                Interruptor(encendido: $apagado)
            }
            SelectorSegmentado(opciones: ["Mundial", "España"], seleccion: $ambito) { $0 }
            CampoDeTexto("Etiqueta de la alarma", texto: $etiqueta)
            Bloque {
                FilaDeAjuste(icono: "bell", titulo: "Tono", detalle: "Amanecer") {
                    Image(systemName: "chevron.right").foregroundStyle(Paleta.textoTenue)
                }
                Raya()
                FilaDeAjuste(icono: "moon", titulo: "Modo oscuro") {
                    Interruptor(encendido: $encendido)
                }
            }
        }
        .padding(Espacio.amplio)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoDePantalla()
    }
}
