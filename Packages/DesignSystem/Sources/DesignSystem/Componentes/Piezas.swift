import SwiftUI

/// Cabecera de pantalla, tomada de la referencia 02: titular grande en dos
/// lineas, la segunda en gris. La segunda linea es donde va el contexto —
/// "mañana", "temporada de agosto" — y por eso casi nunca sobra.
public struct Cabecera<Accion: View>: View {
    private let titulo: String
    private let subtitulo: String?
    private let accion: Accion

    public init(
        _ titulo: String,
        subtitulo: String? = nil,
        @ViewBuilder accion: () -> Accion = { EmptyView() }
    ) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.accion = accion()
    }

    public var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: -2) {
                Text(titulo)
                    .estiloTitular()
                    .foregroundStyle(Paleta.texto)
                if let subtitulo {
                    Text(subtitulo)
                        .estiloTitular()
                        .foregroundStyle(Paleta.textoSuave)
                }
            }
            Spacer(minLength: Espacio.normal)
            accion
        }
        .padding(.horizontal, Espacio.margen)
        .accessibilityElement(children: .combine)
    }
}

/// Pastilla pequena de etiqueta: el reto de una alarma, un pais, un estado.
public struct Pastilla: View {
    private let texto: String
    private let icono: String?
    private let acentuada: Bool

    public init(_ texto: String, icono: String? = nil, acentuada: Bool = false) {
        self.texto = texto
        self.icono = icono
        self.acentuada = acentuada
    }

    public var body: some View {
        HStack(spacing: 5) {
            if let icono {
                Image(systemName: icono).font(.system(size: 10, weight: .semibold))
            }
            Text(texto).font(Tipografia.pieFuerte)
        }
        .foregroundStyle(acentuada ? Paleta.acento : Paleta.textoSuave)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(acentuada ? Paleta.acentoTenue : Paleta.hueco)
        }
    }
}

/// Cifra grande con el prefijo apagado, el truco tipografico de la referencia
/// 02: en "00:50" el "00:" va en gris y pequeno, y el ojo salta directo al
/// numero que importa.
public struct CifraConPrefijo: View {
    private let prefijo: String
    private let cifra: String
    private let tamano: CGFloat

    public init(prefijo: String, cifra: String, tamano: CGFloat = 34) {
        self.prefijo = prefijo
        self.cifra = cifra
        self.tamano = tamano
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(prefijo)
                .font(Tipografia.cifra(tamano * 0.62, .semibold))
                .foregroundStyle(Paleta.textoTenue)
            Text(cifra)
                .font(Tipografia.cifra(tamano, .bold))
                .foregroundStyle(Paleta.texto)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(prefijo + cifra))
    }
}

/// Sello de insignia: disco en relieve con un simbolo dentro. Las que no se han ganado
/// se quedan hundidas y en gris, sin candado ni cartel: el hueco ya dice que
/// falta algo.
public struct SelloDeInsignia: View {
    private let simbolo: String
    private let nombre: String
    private let conseguida: Bool

    public init(simbolo: String, nombre: String, conseguida: Bool) {
        self.simbolo = simbolo
        self.nombre = nombre
        self.conseguida = conseguida
    }

    public var body: some View {
        VStack(spacing: Espacio.corto) {
            Image(systemName: simbolo)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(conseguida ? Paleta.acento : Paleta.textoTenue)
                .frame(width: 62, height: 62)
                .background {
                    if conseguida {
                        Color.clear.relieve(.medio, forma: Circle(), color: Paleta.superficieAlta)
                    } else {
                        Color.clear.hueco(.sutil, forma: Circle())
                    }
                }
            Text(nombre)
                .font(Tipografia.pie)
                .foregroundStyle(conseguida ? Paleta.texto : Paleta.textoTenue)
                .multilineTextAlignment(.center)
                .frame(width: 76)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(conseguida ? "\(nombre), conseguida" : "\(nombre), pendiente"))
    }
}

/// Barra de progreso fina, en canal hundido. Para el avance de nivel.
public struct BarraDeProgreso: View {
    private let progreso: Double

    public init(progreso: Double) {
        self.progreso = min(max(progreso, 0), 1)
    }

    public var body: some View {
        GeometryReader { medida in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.clear).hueco(.sutil, forma: Capsule())
                Capsule()
                    .fill(Paleta.acento)
                    .frame(width: medida.size.width * progreso)
                    .padding(2)
            }
        }
        .frame(height: 12)
        .accessibilityValue(Text("\(Int(progreso * 100)) por ciento"))
    }
}

/// La regla del pie de la referencia 01: rayitas finas y una marca de acento.
/// Aqui sirve para mover la hora sin abrir un selector del sistema.
public struct ReglaHorizontal: View {
    private let progreso: Double

    public init(progreso: Double) {
        self.progreso = min(max(progreso, 0), 1)
    }

    public var body: some View {
        VStack(spacing: Espacio.corto) {
            Circle()
                .fill(Paleta.acento)
                .frame(width: 7, height: 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 0)
                .offset(x: 0)
                .modifier(ColocarEnProgreso(progreso: progreso))

            Canvas { contexto, tamano in
                let rayas = 60
                for indice in 0...rayas {
                    let x = tamano.width * CGFloat(indice) / CGFloat(rayas)
                    let larga = indice % 5 == 0
                    var trazo = Path()
                    trazo.move(to: CGPoint(x: x, y: tamano.height))
                    trazo.addLine(to: CGPoint(x: x, y: tamano.height - (larga ? tamano.height : tamano.height * 0.5)))
                    contexto.stroke(trazo,
                                    with: .color(Paleta.textoTenue.opacity(larga ? 0.6 : 0.3)),
                                    lineWidth: 1)
                }
            }
            .frame(height: 16)
        }
        .accessibilityHidden(true)
    }
}

private struct ColocarEnProgreso: ViewModifier {
    let progreso: Double

    func body(content: Content) -> some View {
        GeometryReader { medida in
            content.offset(x: medida.size.width * progreso - 3.5)
        }
        .frame(height: 7)
    }
}

#Preview("Piezas · claro") {
    MuestraDePiezas()
}

#Preview("Piezas · oscuro") {
    MuestraDePiezas().preferredColorScheme(.dark)
}

struct MuestraDePiezas: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.amplio) {
            Cabecera("Racha", subtitulo: "12 días seguidos") {
                Button { } label: { Image(systemName: "gearshape") }.buttonStyle(.redondo)
            }
            HStack(spacing: Espacio.corto) {
                Pastilla("20 pasos", icono: "figure.walk")
                Pastilla("Pro", icono: "lock.fill", acentuada: true)
            }
            .padding(.horizontal, Espacio.margen)

            CifraConPrefijo(prefijo: "00:", cifra: "50")
                .padding(.horizontal, Espacio.margen)

            HStack(spacing: Espacio.normal) {
                SelloDeInsignia(simbolo: "flame.fill", nombre: "7 días", conseguida: true)
                SelloDeInsignia(simbolo: "sunrise.fill", nombre: "Madrugador", conseguida: true)
                SelloDeInsignia(simbolo: "crown.fill", nombre: "30 días", conseguida: false)
            }
            .padding(.horizontal, Espacio.margen)

            BarraDeProgreso(progreso: 0.6).padding(.horizontal, Espacio.margen)
            ReglaHorizontal(progreso: 0.4).padding(.horizontal, Espacio.margen)
        }
        .padding(.vertical, Espacio.amplio)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fondoDePantalla()
    }
}
