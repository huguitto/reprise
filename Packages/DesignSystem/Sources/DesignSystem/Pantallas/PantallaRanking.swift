import SwiftUI

/// Ranking mundial y por paises, con temporada mensual.
///
/// El filtro por pais es de Pro, asi que en la version gratis la pestana existe
/// pero la lista no se lee. Se ensena tapada en vez de esconderla: que se vea
/// lo que hay detras es justo el argumento de venta, y esconderlo del todo solo
/// consigue que nadie sepa que existe.
public struct PantallaRanking: View {
    @State private var ambito: Ambito = .mundial
    @State private var mostrarPro = false
    private let esPro: Bool

    public init(esPro: Bool = false) {
        self.esPro = esPro
    }

    enum Ambito: String, CaseIterable {
        case mundial = "Mundial"
        case espana = "España"
    }

    private var lista: [PuestoDeRanking] {
        ambito == .mundial ? DatosDeMentira.rankingMundial : DatosDeMentira.rankingDeEspana
    }

    private var tuPuesto: PuestoDeRanking {
        ambito == .mundial ? DatosDeMentira.tuPuestoMundial : DatosDeMentira.tuPuestoEnEspana
    }

    private var tapado: Bool { ambito == .espana && !esPro }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("Ranking", subtitulo: "de agosto") {
                    Button { } label: { Image(systemName: "clock.arrow.circlepath") }
                        .buttonStyle(.redondo)
                }

                SelectorSegmentado(opciones: Ambito.allCases, seleccion: $ambito) { $0.rawValue }
                    .padding(.horizontal, Espacio.margen)

                // Tu fila va arriba y fija. Nadie baja cuatro mil puestos para
                // buscarse.
                FilaDeRanking(puesto: tuPuesto)
                    .padding(.horizontal, Espacio.margen)

                ZStack {
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
                    .blur(radius: tapado ? 7 : 0)
                    .opacity(tapado ? 0.5 : 1)
                    .accessibilityHidden(tapado)

                    if tapado {
                        CarteldePro { mostrarPro = true }
                    }
                }
                .animation(.easeOut(duration: 0.2), value: tapado)

                if !tapado {
                    VStack(alignment: .leading, spacing: Espacio.mini) {
                        Text("La temporada acaba el 31. Tu récord histórico se guarda aparte.")
                        Text("En la versión gratis se ven los cien primeros y tu puesto.")
                    }
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoTenue)
                    .padding(.horizontal, Espacio.margen)
                }
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
        .sheet(isPresented: $mostrarPro) { PantallaMuroDePago() }
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

private struct CarteldePro: View {
    let alPulsar: () -> Void

    var body: some View {
        VStack(spacing: Espacio.normal) {
            Image(systemName: "flag.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Paleta.acento)
            Text("Filtrar por país es de Pro")
                .font(Tipografia.cuerpoFuerte)
                .foregroundStyle(Paleta.texto)
            Text("El ranking mundial y tu puesto siguen siendo gratis.")
                .font(Tipografia.pie)
                .foregroundStyle(Paleta.textoSuave)
                .multilineTextAlignment(.center)
            Button("Ver Pro", action: alPulsar)
                .buttonStyle(.principal)
                .frame(maxWidth: 200)
        }
        .padding(Espacio.amplio)
        .relieve(.medio, radio: Radio.grande, color: Paleta.superficieAlta)
        .padding(.horizontal, Espacio.enorme)
    }
}

#Preview("Ranking · claro") {
    PantallaRanking()
}

#Preview("Ranking · oscuro") {
    PantallaRanking().preferredColorScheme(.dark)
}

#Preview("Ranking con Pro · claro") {
    PantallaRanking(esPro: true)
}
