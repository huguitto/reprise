import SwiftUI
import AlarmCore

// Los nombres de los dias viven aqui, en la capa de presentacion, y no en
// AlarmCore: el dominio no sabe en que idioma se le va a ensenar.
extension Weekday {
    /// Inicial para el selector. Miercoles es X, como en todos los
    /// calendarios en espanol, porque la M ya es de martes.
    public var inicial: String {
        switch self {
        case .lunes: "L"
        case .martes: "M"
        case .miercoles: "X"
        case .jueves: "J"
        case .viernes: "V"
        case .sabado: "S"
        case .domingo: "D"
        }
    }

    public var nombre: String {
        switch self {
        case .lunes: "lunes"
        case .martes: "martes"
        case .miercoles: "miércoles"
        case .jueves: "jueves"
        case .viernes: "viernes"
        case .sabado: "sábado"
        case .domingo: "domingo"
        }
    }
}

extension Set where Element == Weekday {
    /// Como se lee una repeticion debajo de la hora.
    ///
    /// Los casos con nombre propio van primero porque son el 90 % de las
    /// alarmas reales: nadie quiere leer "L, M, X, J, V" cada manana.
    public var resumen: String {
        let ordenados = sorted()
        switch Set(ordenados) {
        case []:
            return "Una sola vez"
        case Set(Weekday.allCases):
            return "Todos los días"
        case [.lunes, .martes, .miercoles, .jueves, .viernes]:
            return "De lunes a viernes"
        case [.sabado, .domingo]:
            return "Fines de semana"
        default:
            return ordenados.map(\.inicial).joined(separator: " · ")
        }
    }
}

/// Los siete dias en fila. Un dia elegido se hunde y se marca con el acento:
/// hundido = pulsado, que es la misma gramatica que el resto de la app.
public struct SelectorDeDias: View {
    @Binding private var dias: Set<Weekday>

    public init(dias: Binding<Set<Weekday>>) {
        self._dias = dias
    }

    public var body: some View {
        HStack(spacing: Espacio.corto) {
            ForEach(Weekday.allCases, id: \.self) { dia in
                let elegido = dias.contains(dia)
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        if elegido { dias.remove(dia) } else { dias.insert(dia) }
                    }
                } label: {
                    Text(dia.inicial)
                        .font(Tipografia.pieFuerte)
                        .foregroundStyle(elegido ? Paleta.acento : Paleta.textoSuave)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if elegido {
                                Color.clear.hueco(.sutil, forma: Circle(), color: Paleta.acentoTenue)
                            } else {
                                Color.clear.relieve(.bajo, forma: Circle())
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(dia.nombre))
                .accessibilityAddTraits(elegido ? [.isSelected] : [])
            }
        }
    }
}

#Preview("Días · claro") {
    MuestraDeDias()
}

#Preview("Días · oscuro") {
    MuestraDeDias().preferredColorScheme(.dark)
}

struct MuestraDeDias: View {
    @State private var dias: Set<Weekday> = [.lunes, .martes, .miercoles, .jueves, .viernes]

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.normal) {
            SelectorDeDias(dias: $dias)
            Text(dias.resumen)
                .font(Tipografia.pie)
                .foregroundStyle(Paleta.textoSuave)
        }
        .padding(Espacio.amplio)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fondoDePantalla()
    }
}
