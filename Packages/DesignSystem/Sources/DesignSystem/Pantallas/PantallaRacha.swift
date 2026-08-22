import SwiftUI
import AlarmCore

/// Racha, nivel, vidas e insignias.
///
/// El numero de la racha es el protagonista de la pantalla, en matriz de
/// puntos y del tamano de una mano. Todo lo demas lo explica.
///
/// Todo lo que pinta sale de un solo `DatosDeRacha`. No se lee nada de
/// `DatosDeMentira` aqui dentro a proposito: si la mitad de la pantalla mira a
/// un sitio y la otra mitad a otro, se puede pasar una racha de 0 y seguir
/// ensenando las insignias de una racha de 12. Ya pasaba.
public struct PantallaRacha: View {
    private let datos: DatosDeRacha
    /// Esta pantalla no usa el plan para nada suyo: solo se lo pasa a Ajustes,
    /// que es de donde cuelga. Va aparte de `datos.plan` porque son dos cosas
    /// distintas: `datos.plan` es el plan **leido** para pintar, y esto es el
    /// modelo con el que se **cambia**. Suelto (`nil`) Ajustes sale como gratis,
    /// que es lo que quieren la galeria y los `#Preview`.
    private let plan: ModeloDelPlan?
    @State private var mostrarAjustes = false

    public init(datos: DatosDeRacha = .deMentira, plan: ModeloDelPlan? = nil) {
        self.datos = datos
        self.plan = plan
    }

    private var racha: Int { datos.racha }
    private var nivel: Nivel { datos.nivel }

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
                insignias
                vidasDelMes
                calendario
                marcaPersonal
            }
            .padding(.vertical, Espacio.amplio)
            // El hueco de la barra de secciones, que flota encima. Sin el,
            // "Mejor racha" se queda debajo y no se ve ni bajando del todo.
            .padding(.bottom, BarraDeSecciones.hueco)
        }
        .fondoDePantalla()
        .sheet(isPresented: $mostrarAjustes) { PantallaAjustes(plan: plan) }
    }

    // MARK: - Piezas

    private var numeroGrande: some View {
        VStack(spacing: Espacio.normal) {
            TextoDeMatriz("\(racha)", altura: 150, color: Paleta.texto)
            HStack(spacing: Espacio.corto) {
                Image(systemName: "flame.fill").foregroundStyle(Paleta.acento)
                Text(racha == 1 ? "día sin fallar" : "días sin fallar")
                    .font(Tipografia.rotulo)
                    .tracking(Tipografia.abiertoRotulo)
                    .textCase(.uppercase)
                    .foregroundStyle(Paleta.textoSuave)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Espacio.normal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(racha == 1 ? "Racha de 1 día sin fallar" : "Racha de \(racha) días sin fallar"))
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
            Text(textoDelSiguienteNivel)
                .font(Tipografia.pie)
                .foregroundStyle(Paleta.textoSuave)
        }
        .padding(Espacio.normal)
        .relieve(.bajo, radio: Radio.medio)
        .padding(.horizontal, Espacio.margen)
    }

    private var textoDelSiguienteNivel: String {
        guard nivel.hasta != nil else { return "No hay nivel por encima de este." }
        let faltan = nivel.diasQueFaltan(conRacha: racha)
        return faltan == 1
            ? "Falta 1 día para el nivel \(nivel.numero + 1)."
            : "Faltan \(faltan) días para el nivel \(nivel.numero + 1)."
    }

    private var vidasDelMes: some View {
        HStack(spacing: Espacio.normal) {
            HStack(spacing: Espacio.corto) {
                // Siempre se dibujan las casillas del tope de Pro, aunque el
                // plan de turno no de ninguna: al usuario gratis las dos vacias
                // le ensenan exactamente lo que le falta.
                ForEach(0..<StreakState.livesPerMonth, id: \.self) { indice in
                    Image(systemName: indice < datos.vidas ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(indice < datos.vidas ? Paleta.acento : Paleta.textoTenue)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tituloDeVidas)
                    .font(Tipografia.cuerpoFuerte)
                    .foregroundStyle(Paleta.texto)
                // Las dos reglas que mas se malentienden, dichas donde se
                // miran: una vida no suma dia, y lo que no gastas se pierde.
                Text(pieDeVidas)
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoSuave)
            }
            Spacer(minLength: 0)
        }
        .padding(Espacio.normal)
        .relieve(.bajo, radio: Radio.medio)
        .padding(.horizontal, Espacio.margen)
        .accessibilityElement(children: .combine)
    }

    /// El plan gratis no tiene vidas y no las va a tener el dia 1, asi que
    /// decirle "se reponen el dia 1" es prometerle algo que no llega. Se le dice
    /// de quien son.
    private var tituloDeVidas: String {
        guard datos.plan.limites.vidasAlMes > 0 else { return "Las vidas son de Pro" }
        switch datos.vidas {
        case 0: return "No te quedan vidas"
        case 1: return "Te queda 1 vida"
        default: return "Te quedan \(datos.vidas) vidas"
        }
    }

    private var pieDeVidas: String {
        datos.plan.limites.vidasAlMes > 0
            ? "Congelan la racha, no la suben. Se reponen el día 1."
            : "Con Pro, 2 al mes: congelan la racha en vez de romperla."
    }

    private var calendario: some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            Text(Self.nombreDelMes(datos.hoy)).estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)
            CalendarioDelMes(
                registros: datos.registrosDelMes,
                hoy: datos.hoy
            )
            .padding(Espacio.normal)
            .relieve(.bajo, radio: Radio.medio)
            .padding(.horizontal, Espacio.margen)
        }
    }

    /// El mes en palabras. Estaba escrito a mano —"Agosto"— y en septiembre
    /// seguia diciendo agosto.
    static func nombreDelMes(_ dia: Day) -> String {
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "es_ES")
        formato.setLocalizedDateFormatFromTemplate("MMMM")
        return formato.string(from: dia.date())
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
                            conseguida: datos.insignias.contains(insignia)
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
            TextoDeMatriz("\(datos.mejor)", altura: 24, color: Paleta.texto)
        }
        .padding(Espacio.normal)
        .relieve(.bajo, radio: Radio.medio)
        .padding(.horizontal, Espacio.margen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Mejor racha: \(datos.mejor) días"))
    }
}

/// Los desenlaces del mes que se ensena, indexados por numero de dia.
///
/// Fuera de la vista para poder probarla: el fallo que arregla no se ve mirando
/// la pantalla, se ve cuando la app se cierra sola.
///
/// Filtra por ano y mes, y no por el numero de dia suelto, porque el numero
/// suelto se repite todos los meses. Antes esto era un
/// `Dictionary(uniqueKeysWithValues:)` sobre `day.day`: en cuanto le llegaran
/// los registros de dos meses —que es justo lo que devuelve
/// `DayRecordRepository.records(from:to:)`, un rango— el 3 de julio y el 3 de
/// agosto chocaban de clave y la app se caia ahi mismo, en la pantalla de racha.
func desenlacesPorDia(_ registros: [DayRecord], mes hoy: Day) -> [Int: DayOutcome] {
    let delMes = registros.filter { $0.day.year == hoy.year && $0.day.month == hoy.month }
    return Dictionary(delMes.map { ($0.day.day, $0.outcome) }, uniquingKeysWith: { _, ultimo in ultimo })
}

/// El mes en una rejilla de siete columnas, empezando en lunes.
///
/// Los cuatro estados se distinguen sin color salvo el acento: lleno = hecho,
/// hundido y vacio = fallado, aro de acento = salvado por una vida, plano =
/// todavia no ha pasado.
struct CalendarioDelMes: View {
    let registros: [DayRecord]
    let hoy: Day

    private var porDia: [Int: DayOutcome] { desenlacesPorDia(registros, mes: hoy) }

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

#Preview("Racha") {
    PantallaRacha().preferredColorScheme(.dark)
}

#Preview("Racha · usuario nuevo y gratis") {
    PantallaRacha(datos: DatosDeRacha(
        estado: StreakState(),
        plan: .gratis,
        registrosDelMes: [],
        hoy: DatosDeMentira.hoy
    ))
    .preferredColorScheme(.dark)
}
