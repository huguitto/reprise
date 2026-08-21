import SwiftUI
import AlarmCore

/// Las tres pantallas de presentacion, las primeras que se ven al instalar.
///
/// Son tres y no cinco a proposito: la app se explica con una promesa por
/// pantalla — **suena**, **te levanta**, **cuenta los dias** — y cada una se
/// tiene que entender sin leer el parrafo. Por eso la ilustracion de cada
/// pagina no es un dibujo aparte: es la pieza de verdad de la app, la esfera,
/// el anillo del reto y la cifra de la racha. Quien pasa de aqui ya ha visto
/// las tres pantallas que va a usar.
///
/// No pide cuenta ni permisos. La alarma funciona sin registro y el permiso se
/// pide cuando hace falta, no antes de haber enseniado para que sirve.
public struct PantallaPresentacion: View {
    @State private var paginaVisible: Pagina? = .suena
    /// A donde ha pedido ir el boton o los puntos. Se separa de `paginaVisible`
    /// porque esa la escribe el propio scroll al arrastrar, y reescribirla no
    /// mueve nada.
    @State private var destino: Pagina?

    private let alTerminar: () -> Void

    /// - Parameter alTerminar: se llama tanto al pulsar "Empezar" en la ultima
    ///   pagina como al saltarse la presentacion. Quien la presenta decide que
    ///   pasa despues; aqui no se sabe.
    public init(alTerminar: @escaping () -> Void = {}) {
        self.alTerminar = alTerminar
    }

    private var pagina: Pagina { paginaVisible ?? .suena }

    public var body: some View {
        VStack(spacing: 0) {
            barraDeSaltar
            paginas
            pie
        }
        .fondoDePantalla()
    }

    // MARK: - Barra de arriba

    private var barraDeSaltar: some View {
        HStack {
            Spacer()
            // En la ultima pagina el boton no se atenua: se va.
            //
            // Estuvo escondido con `opacity(0)` y `disabled`, y eso deja el
            // boton dentro del arbol de accesibilidad: quien navega con
            // VoiceOver aterrizaba en la tercera pagina sobre un "Saltar"
            // que no esta en la pantalla. `accessibilityHidden` tampoco lo
            // saco —se probo—, asi que no se pinta y punto.
            //
            // El hueco de 44 puntos no se pierde por esto: lo reserva el
            // `frame` de la barra, no el boton. Y el desvanecido sigue,
            // ahora por la transicion.
            if pagina != .cuenta {
                Button("Saltar", action: alTerminar)
                    .buttonStyle(.texto)
                    .transition(.opacity)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, Espacio.margen)
        .animation(.easeOut(duration: 0.2), value: pagina)
    }

    // MARK: - Las tres paginas

    private var paginas: some View {
        ScrollViewReader { desplazador in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Pagina.allCases) { pagina in
                        contenido(de: pagina)
                            .containerRelativeFrame(.horizontal)
                            .id(pagina)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            // Lee el arrastre del dedo; escribirle NO mueve el scroll, por eso
            // los saltos van por el `ScrollViewReader` de fuera.
            .scrollPosition(id: $paginaVisible)
            .scrollIndicators(.hidden)
            .onChange(of: destino) { _, nuevo in
                guard let nuevo else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    desplazador.scrollTo(nuevo, anchor: .center)
                }
                // Y se apunta a mano donde hemos ido: el scroll solo escribe
                // `paginaVisible` cuando el que arrastra es el dedo.
                paginaVisible = nuevo
                // Se vacia para que el siguiente encargo cuente aunque sea a la
                // misma pagina: ir a la 2, volver arrastrando y pulsar
                // "Siguiente" otra vez repite el valor, y sin esto `onChange`
                // no se entera y el boton se queda muerto.
                destino = nil
            }
        }
    }

    @ViewBuilder
    private func contenido(de pagina: Pagina) -> some View {
        switch pagina {
        case .suena:
            Lamina(pagina: pagina) {
                EsferaDeReloj(hora: 6, minuto: 30, diametro: 210)
            }
        case .levanta:
            Lamina(pagina: pagina) {
                AnilloDeProgreso(progreso: 0.35, grosor: 14) {
                    TextoDeMatriz("7", altura: 74, colorApagado: Paleta.retoApagado)
                }
                .frame(width: 200, height: 200)
            }
        case .cuenta:
            Lamina(pagina: pagina) {
                CifraDeRacha()
            }
        }
    }

    // MARK: - Pie

    private var pie: some View {
        VStack(spacing: Espacio.amplio) {
            Puntos(actual: pagina) { elegida in
                destino = elegida
            }

            Button(pagina.boton) {
                if let siguiente = pagina.siguiente {
                    destino = siguiente
                } else {
                    alTerminar()
                }
            }
            .buttonStyle(.principal)
        }
        .padding(.horizontal, Espacio.margen)
        .padding(.top, Espacio.normal)
        .padding(.bottom, Espacio.corto)
    }
}

// MARK: - Las paginas

extension PantallaPresentacion {
    /// Una promesa por pagina, en el orden en que importan: primero **por que**
    /// estas aqui — la disciplina de levantarte temprano —, luego **como** te
    /// obliga la app, y solo entonces **que ganas** por sostenerlo.
    enum Pagina: Int, CaseIterable, Identifiable, Hashable {
        case suena, levanta, cuenta

        var id: Int { rawValue }

        /// Primera linea del titular, en tinta.
        var titulo: String {
            switch self {
            case .suena: "La disciplina"
            case .levanta: "Se apaga"
            case .cuenta: "Y mañana,"
            }
        }

        /// Segunda linea, en gris. Es la que remata la frase: sola no dice
        /// nada, y esa es la idea.
        var remate: String {
            switch self {
            case .suena: "empieza por levantarse."
            case .levanta: "con las piernas."
            case .cuenta: "otra vez."
            }
        }

        var explicacion: String {
            switch self {
            case .suena:
                "Nadie instala un despertador por gusto: lo instalas porque quieres levantarte temprano y sostenerlo. Por eso este suena con la app cerrada y por encima del silencio, y por eso no tiene botón de posponer."
            case .levanta:
                "Eliges el reto al crear la alarma. Hasta que no lo terminas entero, no se calla; si lo dejas a medias, vuelve a sonar."
            case .cuenta:
                "Cada mañana cumplida suma un día. Tienes dos vidas al mes para los días malos, y un ranking mundial y por países para ver hasta dónde aguantas."
            }
        }

        /// Las dos pastillas de debajo del titular. Son el resumen del resumen:
        /// si alguien solo mira esto, se lleva lo importante.
        var etiquetas: [(texto: String, icono: String)] {
            switch self {
            case .suena:
                [("Rompe el silencio", "bell.fill"), ("Sin posponer", "zzz")]
            case .levanta:
                [(ChallengeType.pasos.instruccion, ChallengeType.pasos.simbolo),
                 (ChallengeType.sentadillas.instruccion, ChallengeType.sentadillas.simbolo)]
            case .cuenta:
                [("2 vidas al mes", "heart.fill"), ("Ranking mundial", "globe")]
            }
        }

        var boton: String {
            switch self {
            case .suena, .levanta: "Siguiente"
            case .cuenta: "Empezar"
            }
        }

        var siguiente: Pagina? {
            Pagina(rawValue: rawValue + 1)
        }
    }
}

// MARK: - Piezas de la presentacion

/// El molde de las tres paginas: ilustracion arriba, titular editorial en dos
/// lineas, parrafo y pastillas. Todas iguales para que al pasar de una a otra
/// solo cambie el contenido y no el sitio donde esta cada cosa.
private struct Lamina<Ilustracion: View>: View {
    let pagina: PantallaPresentacion.Pagina
    @ViewBuilder let ilustracion: Ilustracion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: Espacio.normal)

            ilustracion
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Spacer(minLength: Espacio.amplio)

            VStack(alignment: .leading, spacing: -2) {
                Text(pagina.titulo)
                    .estiloTitular()
                    .foregroundStyle(Paleta.texto)
                Text(pagina.remate)
                    .estiloTitular()
                    .foregroundStyle(Paleta.textoSuave)
            }
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .accessibilityElement(children: .combine)

            Text(pagina.explicacion)
                .font(Tipografia.cuerpo)
                .foregroundStyle(Paleta.textoSuave)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Espacio.medio)

            HStack(spacing: Espacio.corto) {
                ForEach(pagina.etiquetas, id: \.texto) { etiqueta in
                    Pastilla(etiqueta.texto, icono: etiqueta.icono)
                }
            }
            .padding(.top, Espacio.normal)

            Spacer(minLength: Espacio.normal)
        }
        .padding(.horizontal, Espacio.margen)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// La ilustracion de la tercera pagina: la cifra de la racha en matriz de
/// puntos con las insignias debajo, que es exactamente lo que se ve en
/// `PantallaRacha`. Ensenar la pantalla de verdad vende mas que un icono.
private struct CifraDeRacha: View {
    /// El simbolo sale de `Insignia`, pero el nombre no: los de verdad
    /// ("Treinta seguidos") no caben debajo del sello y se cortan. Aqui se
    /// ensenia de que van, no como se llaman.
    private let insignias: [(insignia: Insignia, corto: String)] = [
        (.primerDia, "Primer día"),
        (.semanaEnPie, "7 días"),
        (.mesEnPie, "30 días")
    ]

    var body: some View {
        VStack(spacing: Espacio.normal) {
            TextoDeMatriz("\(DatosDeMentira.rachaActual)", altura: 108, color: Paleta.texto)

            HStack(spacing: Espacio.corto) {
                Image(systemName: "flame.fill").foregroundStyle(Paleta.acento)
                Text("días sin fallar").estiloRotulo()
            }

            HStack(spacing: Espacio.normal) {
                // La ultima esta sin conseguir: la presentacion no promete que
                // ya lo tengas todo, promete que hay sitio a donde llegar.
                ForEach(Array(insignias.enumerated()), id: \.offset) { indice, sello in
                    SelloDeInsignia(
                        simbolo: sello.insignia.simbolo,
                        nombre: sello.corto,
                        conseguida: indice < insignias.count - 1
                    )
                }
            }
            .padding(.top, Espacio.corto)
        }
    }
}

/// Los tres puntos del paso. Son puntos porque la app entera esta hecha de
/// puntos; el activo se estira en pastilla de acento en vez de cambiar de
/// tamanio, que es lo unico que se lee de un vistazo.
private struct Puntos: View {
    let actual: PantallaPresentacion.Pagina
    let alElegir: (PantallaPresentacion.Pagina) -> Void

    var body: some View {
        HStack(spacing: Espacio.corto) {
            ForEach(PantallaPresentacion.Pagina.allCases) { pagina in
                let esActual = pagina == actual
                Button { alElegir(pagina) } label: {
                    Capsule()
                        .fill(esActual ? Paleta.acento : Paleta.textoTenue)
                        .frame(width: esActual ? 22 : 7, height: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Página \(pagina.rawValue + 1) de \(PantallaPresentacion.Pagina.allCases.count)"))
                .accessibilityAddTraits(esActual ? [.isSelected] : [])
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: actual)
    }
}

#Preview("Presentación") {
    PantallaPresentacion().preferredColorScheme(.dark)
}
