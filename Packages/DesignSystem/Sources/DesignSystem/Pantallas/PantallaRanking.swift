import SwiftUI
import Foundation
import AlarmCore

/// Ranking mundial y por paises, con temporada mensual.
///
/// **El ranking entero es gratis, mundial y por pais.** Hasta el 21/08/2026 el
/// filtro por pais estaba detras del muro de pago y la pestana de España se
/// ensenaba borrosa; el usuario lo abrio a todo el mundo. Queda dicho aqui
/// porque el codigo de tapar la lista se ha ido entero: si vuelve a hacer
/// falta, se reescribe, no se descomenta.
public struct PantallaRanking: View {
    @State private var ambito: Ambito = .mundial
    @State private var mostrarHistorico = false

    public init() {}

    enum Ambito: String, CaseIterable {
        case mundial = "Mundial"
        case espana = "España"
    }

    /// El mes en curso, en palabras. Estaba escrito "de agosto" y el dia 1 de
    /// septiembre la temporada nueva seguia llamandose agosto. Mismo problema
    /// que tenia el calendario de la racha, y se arregla igual.
    static func mesDeLaTemporada(_ ahora: Date = Date()) -> String {
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "es_ES")
        formato.setLocalizedDateFormatFromTemplate("MMMM")
        return formato.string(from: ahora)
    }

    /// El ultimo dia del mes en curso. Estaba escrito "el 31", asi que en
    /// febrero prometia tres dias de temporada que no existen.
    static func ultimoDiaDelMes(_ ahora: Date = Date(), calendario: Calendar = .current) -> Int {
        calendario.range(of: .day, in: .month, for: ahora)?.count ?? 30
    }

    private var lista: [PuestoDeRanking] {
        ambito == .mundial ? DatosDeMentira.rankingMundial : DatosDeMentira.rankingDeEspana
    }

    private var tuPuesto: PuestoDeRanking {
        ambito == .mundial ? DatosDeMentira.tuPuestoMundial : DatosDeMentira.tuPuestoEnEspana
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("Ranking", subtitulo: "de \(Self.mesDeLaTemporada())") {
                    Button { mostrarHistorico = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.redondo)
                    .accessibilityLabel(Text("Histórico de temporadas"))
                }

                SelectorSegmentado(opciones: Ambito.allCases, seleccion: $ambito) { $0.rawValue }
                    .padding(.horizontal, Espacio.margen)

                // Tu fila va arriba y fija. Nadie baja cuatro mil puestos para
                // buscarse.
                FilaDeRanking(puesto: tuPuesto)
                    .padding(.horizontal, Espacio.margen)

                VStack(alignment: .leading, spacing: Espacio.medio) {
                    Text(ambito == .mundial ? "Top mundial" : "Top de España")
                        .estiloRotulo()
                        .padding(.horizontal, Espacio.mini)

                    VStack(spacing: Espacio.corto) {
                        ForEach(lista) { puesto in
                            FilaDeRanking(puesto: puesto)
                        }
                    }
                }
                .padding(.horizontal, Espacio.margen)

                VStack(alignment: .leading, spacing: Espacio.mini) {
                    Text("La temporada acaba el \(Self.ultimoDiaDelMes()). Tu récord histórico se guarda aparte.")
                    Text("Se ven los cien primeros y tu puesto, pagues o no.")
                }
                .font(Tipografia.pie)
                .foregroundStyle(Paleta.textoTenue)
                .padding(.horizontal, Espacio.margen)
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
        .sheet(isPresented: $mostrarHistorico) { PantallaHistoricoDeRanking() }
    }
}

/// Una linea del ranking. La tuya lleva el acento; las demas, ninguno.
struct FilaDeRanking: View {
    let puesto: PuestoDeRanking

    var body: some View {
        HStack(spacing: Espacio.medio) {
            Text("\(puesto.posicion)")
                .font(Tipografia.cifra(15, .semibold))
                .foregroundStyle(puesto.eresTu ? Paleta.acento : Paleta.textoSuave)
                .frame(minWidth: 34, alignment: .trailing)

            Text(puesto.bandera)
                .font(.system(size: 20))

            Text(puesto.eresTu ? "Tú" : puesto.nombre)
                .font(puesto.eresTu ? Tipografia.cuerpoFuerte : Tipografia.cuerpo)
                .foregroundStyle(Paleta.texto)
                .lineLimit(1)

            Spacer(minLength: Espacio.corto)

            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(puesto.eresTu ? Paleta.acento : Paleta.textoTenue)
                Text("\(puesto.racha)")
                    .font(Tipografia.cifra(15, .semibold))
                    .foregroundStyle(Paleta.texto)
            }
        }
        .padding(.horizontal, Espacio.normal)
        .padding(.vertical, 14)
        .background {
            if puesto.eresTu {
                RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                    .fill(Paleta.acentoTenue)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radio.medio, style: .continuous)
                            .strokeBorder(Paleta.acento.opacity(0.35), lineWidth: 1)
                    }
            } else {
                Color.clear.relieve(.bajo, radio: Radio.medio)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Ranking") {
    PantallaRanking().preferredColorScheme(.dark)
}

#Preview("Ranking · histórico") {
    PantallaHistoricoDeRanking().preferredColorScheme(.dark)
}
