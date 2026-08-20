import SwiftUI
import AlarmCore

/// Racha, nivel, vidas e insignias.
///
/// El numero de la racha es el protagonista de la pantalla, en matriz de
/// puntos y del tamano de una mano. Todo lo demas lo explica.
public struct PantallaRacha: View {
    private let racha: Int
    private let mejor: Int
    private let vidas: Int
    @State private var mostrarAjustes = false

    public init(
        racha: Int = DatosDeMentira.rachaActual,
        mejor: Int = DatosDeMentira.mejorRacha,
        vidas: Int = DatosDeMentira.vidasRestantes
    ) {
        self.racha = racha
        self.mejor = mejor
        self.vidas = vidas
    }

    private var nivel: Nivel { Niveles.nivel(racha: racha) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera("Racha", subtitulo: nivel.nombre.lowercased()) {
                    Button { mostrarAjustes = true } label: { Image(systemName: "gearshape") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Ajustes"))
                }

                numeroGrande
                nivelYProgreso
                vidasDelMes
                calendario
                insignias
                marcaPersonal
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
        .sheet(isPresented: $mostrarAjustes) { PantallaAjustes() }
    }

    // MARK: - Piezas

    private var numeroGrande: some View {
        VStack(spacing: Espacio.normal) {
            TextoDeMatriz("\(racha)", altura: 150, color: Paleta.texto)
            HStack(spacing: Espacio.corto) {
                Image(systemName: "flame.fill").foregroundStyle(Paleta.acento)
                Text("días sin fallar")
                    .font(Tipografia.rotulo)
                    .tracking(Tipografia.abiertoRotulo)
                    .textCase(.uppercase)
                    .foregroundStyle(Paleta.textoSuave)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Espacio.normal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Racha de \(racha) días sin fallar"))
    }

    private var nivelYProgreso: some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            HStack(alignment: .firstTextBaseline) {
                Text("Nivel \(nivel.numero)")
                    .font(Tipografia.titulo)
                    .foregroundStyle(Paleta.texto)
                Text(nivel.nombre)
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
                Spacer()
            }
            BarraDeProgreso(progreso: nivel.progreso(conRacha: racha))
            if nivel.hasta != nil {
                Text("Faltan \(nivel.diasQueFaltan(conRacha: racha)) días para el nivel \(nivel.numero + 1).")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
            } else {
                Text("No hay nivel por encima de este.")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
            }
        }
        .padding(Espacio.normal)
        .relieve(.bajo, radio: Radio.medio)
        .padding(.horizontal, Espacio.margen)
    }

    private var vidasDelMes: some View {
        HStack(spacing: Espacio.normal) {
            HStack(spacing: Espacio.corto) {
                ForEach(0..<StreakState.livesPerMonth, id: \.self) { indice in
                    Image(systemName: indice < vidas ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(indice < vidas ? Paleta.acento : Paleta.textoTenue)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(vidas == 1 ? "Te queda 1 vida" : "Te quedan \(vidas) vidas")
                    .font(Tipografia.cuerpoFuerte)
                    .foregroundStyle(Paleta.texto)
                // Las dos reglas que mas se malentienden, dichas donde se
                // miran: una vida no suma dia, y lo que no gastas se pierde.
                Text("Congelan la racha, no la suben. Se reponen el día 1.")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
            }
            Spacer(minLength: 0)
        }
        .padding(Espacio.normal)
        .relieve(.bajo, radio: Radio.medio)
        .padding(.horizontal, Espacio.margen)
    }

    private var calendario: some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            Text("Agosto").estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)
            CalendarioDelMes(
                registros: DatosDeMentira.mesDeEjemplo,
                hoy: DatosDeMentira.hoy
            )
            .padding(Espacio.normal)
            .relieve(.bajo, radio: Radio.medio)
            .padding(.horizontal, Espacio.margen)
        }
    }

    private var insignias: some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            Text("Insignias").estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Espacio.normal) {
                    ForEach(Insignia.allCases) { insignia in
                        SelloDeInsignia(
                            simbolo: insignia.simbolo,
                            nombre: insignia.nombre,
                            conseguida: insignia.concedida(DatosDeMentira.estadoDeRacha)
                        )
                    }
                }
                .padding(.horizontal, Espacio.margen)
                .padding(.vertical, Espacio.corto)
            }
        }
    }

    private var marcaPersonal: some View {
        HStack {
            Text("Mejor racha")
                .font(Tipografia.cuerpo)
                .foregroundStyle(Paleta.textoSuave)
            Spacer()
            TextoDeMatriz("\(mejor)", altura: 24, color: Paleta.texto)
        }
        .padding(Espacio.normal)
        .relieve(.bajo, radio: Radio.medio)
        .padding(.horizontal, Espacio.margen)
    }
}

/// El mes en una rejilla de siete columnas, empezando en lunes.
///
/// Los cuatro estados se distinguen sin color salvo el acento: lleno = hecho,
/// hundido y vacio = fallado, aro de acento = salvado por una vida, plano =
/// todavia no ha pasado.
struct CalendarioDelMes: View {
    let registros: [DayRecord]
    let hoy: Day

    private var porDia: [Int: DayOutcome] {
        Dictionary(uniqueKeysWithValues: registros.map { ($0.day.day, $0.outcome) })
    }

    /// Cuantas casillas vacias van antes del dia 1.
    private var huecoInicial: Int {
        let primero = Day(year: hoy.year, month: hoy.month, day: 1)
        let numero = Calendar.current.component(.weekday, from: primero.date())
        guard let dia = Weekday(calendarWeekday: numero) else { return 0 }
        return dia.rawValue - 1
    }

    private var diasDelMes: Int {
        Calendar.current.range(of: .day, in: .month, for: hoy.date())?.count ?? 30
    }

    private let columnas = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: Espacio.corto) {
            HStack(spacing: 6) {
                ForEach(Weekday.allCases, id: \.self) { dia in
                    Text(dia.inicial)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Paleta.textoTenue)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columnas, spacing: 6) {
                ForEach(0..<huecoInicial, id: \.self) { indice in
                    Color.clear.frame(height: 34).id("hueco\(indice)")
                }
                ForEach(1...diasDelMes, id: \.self) { numero in
                    CeldaDeDia(
                        numero: numero,
                        desenlace: porDia[numero],
                        esHoy: numero == hoy.day,
                        pasado: numero <= hoy.day
                    )
                }
            }
        }
    }
}

private struct CeldaDeDia: View {
    let numero: Int
    let desenlace: DayOutcome?
    let esHoy: Bool
    let pasado: Bool

    var body: some View {
        Text("\(numero)")
            .font(Tipografia.cifra(11, .semibold))
            .foregroundStyle(colorDelNumero)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background { fondo }
            // Hoy se marca siempre, tenga desenlace o no: si no, el dia en
            // curso desaparece entre los que ya estan hechos. El aro va
            // discontinuo para que no se confunda con el aro macizo del dia
            // salvado por una vida.
            .overlay {
                if esHoy {
                    Circle()
                        .strokeBorder(Paleta.acento,
                                      style: StrokeStyle(lineWidth: 2, dash: [3.5, 3]))
                        .padding(1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(etiqueta))
    }

    @ViewBuilder
    private var fondo: some View {
        switch desenlace {
        case .completado:
            Circle().fill(Paleta.texto).padding(4)
        case .salvadoPorVida:
            Circle().strokeBorder(Paleta.acento, lineWidth: 2).padding(4)
        case .fallado:
            Color.clear.hueco(.sutil, forma: Circle()).padding(4)
        case .none:
            Color.clear
        }
    }

    private var colorDelNumero: Color {
        switch desenlace {
        case .completado: Paleta.superficieAlta
        case .salvadoPorVida: Paleta.acento
        case .fallado: Paleta.textoTenue
        case .none: pasado ? Paleta.textoSuave : Paleta.textoTenue
        }
    }

    private var etiqueta: String {
        if let desenlace { return "Día \(numero): \(desenlace.descripcion)" }
        return esHoy ? "Día \(numero), hoy" : "Día \(numero)"
    }
}

#Preview("Racha · claro") {
    PantallaRacha()
}

#Preview("Racha · oscuro") {
    PantallaRacha().preferredColorScheme(.dark)
}
