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
        // Esta pantalla no se desplaza entera: cabe y se queda quieta. Lo unico
        // que crece sin limite es el top —hoy son ocho, manana son cien— y es
        // lo unico que lleva `ScrollView`. Asi tu puesto, que es lo que se
        // viene a mirar, esta siempre en el mismo sitio, y la letra del pie no
        // se esconde por debajo de una lista larga.
        GeometryReader { medida in
            VStack(alignment: .leading, spacing: Espacio.normal) {
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

                top
            }
            .padding(.top, Espacio.amplio)
            .frame(width: medida.size.width, height: medida.size.height, alignment: .top)
        }
        .fondoDePantalla()
        .sheet(isPresented: $mostrarHistorico) { PantallaHistoricoDeRanking() }
    }

    /// Cuanto tarda una fila en desaparecer al colarse debajo del rotulo.
    ///
    /// Sin esto la lista se corta contra un canto duro, que es justo lo que no
    /// hace ninguna otra pantalla: en la de racha lo que se va por abajo se
    /// apaga contra el velo de la barra. Aqui hace falta el mismo desvanecido
    /// arriba, porque el rotulo se queda fijo y las filas le pasan por debajo.
    private static let desvanecido: CGFloat = Espacio.normal

    /// El top de la temporada. Es lo unico que se desplaza, y llega hasta abajo
    /// del todo: lo ultimo se apaga contra el velo de la barra de secciones, no
    /// contra un borde.
    private var top: some View {
        VStack(alignment: .leading, spacing: Espacio.corto) {
            Text(ambito == .mundial ? "Top mundial" : "Top de España")
                .estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)

            ScrollView {
                VStack(spacing: Espacio.corto) {
                    ForEach(lista) { puesto in
                        FilaDeRanking(puesto: puesto)
                    }
                }
                .padding(.horizontal, Espacio.margen)
                // Arriba, lo que mide el desvanecido: asi la primera fila, con
                // la lista quieta, se ve entera y no medio apagada.
                .padding(.top, Self.desvanecido)
                // Y abajo, el hueco de la barra, que flota encima. Sin el, el
                // ultimo puesto no llega a salir nunca del velo.
                .padding(.bottom, BarraDeSecciones.hueco)
            }
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: Self.desvanecido)
                    Color.black
                }
            }
            // Con ocho puestos la lista no rebota como si hubiera algo mas
            // abajo: solo se desplaza cuando de verdad no cabe.
            .scrollBounceBehavior(.basedOnSize)
        }
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
