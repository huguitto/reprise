import SwiftUI

/// El historico del ranking: lo que queda de cada temporada ya cerrada.
///
/// Existe porque el ranking se pone a cero el dia 1 y sin esta pantalla el mes
/// que hiciste se evaporaba. Aqui no se compite: se mira lo que ya paso, y por
/// eso va en hoja y no como cuarta seccion.
///
/// **Se ve gratis, como el resto del ranking.** Lo que es de Pro son las
/// estadisticas de la racha, no esto.
public struct PantallaHistoricoDeRanking: View {
    @Environment(\.dismiss) private var cerrar
    private let temporadas: [TemporadaDeRanking]
    private let mejorRacha: Int

    public init(
        temporadas: [TemporadaDeRanking] = DatosDeMentira.temporadasCerradas,
        mejorRacha: Int = DatosDeMentira.mejorRacha
    ) {
        self.temporadas = temporadas
        self.mejorRacha = mejorRacha
    }

    /// El puesto mas alto de todos, que es el numero *mas bajo*. Se calcula y
    /// no se guarda aparte: asi no puede contradecir a la lista de abajo.
    private var mejorPuesto: TemporadaDeRanking? {
        temporadas.min { $0.puestoMundial < $1.puestoMundial }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("Histórico", subtitulo: "mes a mes") {
                    Button { cerrar() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Cerrar"))
                }

                if temporadas.isEmpty {
                    sinTemporadas
                } else {
                    marcas
                    listaDeTemporadas
                    pie
                }
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
    }

    // MARK: - Piezas

    private var marcas: some View {
        HStack(spacing: Espacio.medio) {
            TarjetaDeMarca(
                rotulo: "Mejor puesto",
                // `.formatted()` y no interpolacion a pelo: la fila de abajo pinta el
                // puesto dentro de un `Text` localizado, que ya mete el punto de
                // los miles cuando toca (en español, a partir de cinco cifras:
                // 1204 pero 15.238). Sin esto, las dos cifras del mismo dato se
                // escribirian distinto en la misma pantalla.
                cifra: mejorPuesto.map { "#\($0.puestoMundial.formatted())" } ?? "—",
                detalle: mejorPuesto.map { "Mundial · \($0.mes.lowercased())" } ?? "Sin temporadas"
            )
            TarjetaDeMarca(
                rotulo: "Mejor racha",
                cifra: "\(mejorRacha)",
                detalle: "Días seguidos, de siempre"
            )
        }
        .padding(.horizontal, Espacio.margen)
    }

    private var listaDeTemporadas: some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            Text("Temporadas cerradas").estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)

            Bloque {
                ForEach(Array(temporadas.enumerated()), id: \.element.id) { indice, temporada in
                    if indice > 0 { Raya() }
                    FilaDeTemporada(
                        temporada: temporada,
                        esLaMejor: temporada.id == mejorPuesto?.id
                    )
                }
            }
            .padding(.horizontal, Espacio.margen)
        }
    }

    private var pie: some View {
        VStack(alignment: .leading, spacing: Espacio.mini) {
            Text("La temporada en curso entra aquí cuando acabe el mes.")
            Text("El ranking se pone a cero el día 1; esto no se borra nunca.")
        }
        .font(Tipografia.pie)
        .foregroundStyle(Paleta.textoTenue)
        .padding(.horizontal, Espacio.margen)
    }

    /// Un usuario nuevo llega aqui en su primer mes y no tiene nada. Mejor
    /// decirselo que ensenarle un bloque vacio que parece roto.
    private var sinTemporadas: some View {
        VStack(spacing: Espacio.medio) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Paleta.textoTenue)
            Text("Todavía no has cerrado ninguna temporada")
                .font(Tipografia.cuerpoFuerte)
                .foregroundStyle(Paleta.texto)
                .multilineTextAlignment(.center)
            Text("Cuando acabe el mes, tu puesto se guarda aquí y el ranking empieza de cero.")
                .font(Tipografia.pie)
                .foregroundStyle(Paleta.textoSuave)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Espacio.amplio)
        .hueco(.sutil, radio: Radio.medio)
        .padding(.horizontal, Espacio.margen)
    }
}

/// Marca personal: un rotulo, una cifra gorda y la letra pequena que la sitúa.
private struct TarjetaDeMarca: View {
    let rotulo: String
    let cifra: String
    let detalle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.mini) {
            Text(rotulo).estiloRotulo()
            Text(cifra)
                .font(Tipografia.cifra(26, .bold))
                .foregroundStyle(Paleta.texto)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detalle)
                .font(Tipografia.pie)
                .foregroundStyle(Paleta.textoSuave)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Espacio.normal)
        .relieve(.bajo, radio: Radio.medio)
        .accessibilityElement(children: .combine)
    }
}

/// Una temporada: el mes, con que racha acabo y en que puestos quedo.
private struct FilaDeTemporada: View {
    let temporada: TemporadaDeRanking
    let esLaMejor: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Espacio.medio) {
            VStack(alignment: .leading, spacing: Espacio.mini) {
                HStack(spacing: Espacio.corto) {
                    Text(temporada.mes)
                        .font(Tipografia.cuerpoFuerte)
                        .foregroundStyle(Paleta.texto)
                    if esLaMejor {
                        Pastilla("Tu mejor", acentuada: true)
                    }
                }
                Text("#\(temporada.puestoMundial) mundial · #\(temporada.puestoEnPais) en España")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
            }

            Spacer(minLength: Espacio.corto)

            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(esLaMejor ? Paleta.acento : Paleta.textoTenue)
                Text("\(temporada.rachaFinal)")
                    .font(Tipografia.cifra(15, .semibold))
                    .foregroundStyle(Paleta.texto)
            }
        }
        .padding(.horizontal, Espacio.normal)
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(etiqueta))
    }

    private var etiqueta: String {
        let marca = esLaMejor ? ", tu mejor temporada" : ""
        return "\(temporada.mes)\(marca). Puesto \(temporada.puestoMundial) mundial, \(temporada.puestoEnPais) en España, con \(temporada.rachaFinal) días de racha."
    }
}

#Preview("Histórico") {
    PantallaHistoricoDeRanking().preferredColorScheme(.dark)
}

#Preview("Histórico sin temporadas") {
    PantallaHistoricoDeRanking(temporadas: []).preferredColorScheme(.dark)
}
