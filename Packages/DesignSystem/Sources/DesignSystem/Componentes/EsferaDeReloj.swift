import SwiftUI

/// Cual de las dos bolitas de la esfera se esta moviendo.
///
/// Vive con la esfera y no dentro de la pantalla que la usa porque hay dos
/// mandos para lo mismo: la propia esfera y la regla de su pie. Si el dedo coge
/// la bolita de dentro, la regla tiene que enterarse de que ahora va de horas.
public enum Manecilla: Hashable, Sendable, CaseIterable {
    case hora
    case minuto

    /// Como se llama en pantalla.
    public var nombre: String {
        switch self {
        case .hora: "Hora"
        case .minuto: "Minuto"
        }
    }
}

/// La esfera del reloj: el objeto de la referencia 01.
///
/// Un disco casi blanco que sobresale del fondo, con el canto moleteado y la
/// hora en matriz de puntos a dos pisos. Es la pieza mas cara de la app en
/// atencion visual, asi que sale **una sola vez por pantalla**.
///
/// Tiene dos formas de existir:
///
/// - **De mirar** (`init(hora:minuto:...)`): la de la lista y la presentacion.
/// - **De tocar** (`init(hora:minuto:manecilla:...)`): la de crear o editar una
///   alarma. Ahi las dos bolitas se arrastran y la esfera *es* el selector de
///   hora; no hay rueda del sistema en ningun sitio.
public struct EsferaDeReloj: View {
    @Binding private var hora: Int
    @Binding private var minuto: Int
    @Binding private var manecilla: Manecilla
    private let activa: Bool
    private let diametro: CGFloat
    private let ajustable: Bool

    /// Esfera de mirar. No responde al dedo.
    public init(hora: Int, minuto: Int, activa: Bool = true, diametro: CGFloat = 260) {
        self._hora = .constant(hora)
        self._minuto = .constant(minuto)
        self._manecilla = .constant(.hora)
        self.activa = activa
        self.diametro = diametro
        self.ajustable = false
    }

    /// Esfera de tocar: las bolitas se arrastran para poner la hora.
    ///
    /// `manecilla` no es un detalle interno que se pueda esconder: es cual de
    /// las dos se esta moviendo, y lo comparte con el mando que haya al lado.
    public init(
        hora: Binding<Int>,
        minuto: Binding<Int>,
        manecilla: Binding<Manecilla>,
        diametro: CGFloat = 260
    ) {
        self._hora = hora
        self._minuto = minuto
        self._manecilla = manecilla
        self.activa = true
        self.diametro = diametro
        self.ajustable = true
    }

    /// Lo que dura un arrastre. `nil` mientras el dedo no esta puesto.
    @State private var arrastre: Arrastre?
    /// Solo sirve para enterarse de que el gesto acabo **o se cancelo**. Un
    /// `onEnded` no basta: si el ScrollView de la pantalla se lleva el gesto a
    /// medias, no llega nunca y el siguiente toque heredaria la manecilla del
    /// arrastre anterior.
    @GestureState private var dedoPuesto = false

    public var body: some View {
        if ajustable {
            esfera
                .contentShape(Circle())
                .gesture(arrastreDeLaEsfera)
                .onChange(of: dedoPuesto) { _, puesto in
                    if !puesto { arrastre = nil }
                }
                .sensoryFeedback(.selection, trigger: hora * 60 + minuto)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Hora de la alarma"))
                .accessibilityValue(Text(String(format: "%d:%02d", hora, minuto)))
                .accessibilityHint(Text("Ajusta \(manecilla == .hora ? "la hora" : "los minutos")"))
                .accessibilityAdjustableAction(ajusta)
        } else {
            esfera
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(
                    String(format: activa ? "Alarma puesta a las %d:%02d" : "Alarma apagada, %d:%02d",
                           hora, minuto)
                ))
        }
    }

    private var esfera: some View {
        ZStack {
            Color.clear
                .relieve(.alto, forma: Circle(), color: Paleta.superficieAlta)

            CantoMoleteado()
                .padding(diametro * 0.055)

            HoraDeMatriz(
                hora: hora,
                minuto: minuto,
                altura: diametro * 0.235,
                color: activa ? Paleta.texto : Paleta.textoTenue
            )

            // Las dos marcas de la hora que muestra la esfera.
            //
            // Antes habia una sola bolita, clavada arriba a la izquierda, que
            // venia de la referencia y no significaba nada. Enganaba: en una
            // esfera con canto moleteado, un punto sobre el circulo se lee como
            // una aguja, y estaba siempre en el mismo sitio dijera la hora lo
            // que dijera.
            //
            // Ahora son dos y apuntan de verdad. Se reparten como las agujas de
            // un reloj, que es lo que todo el mundo sabe leer sin pensar: la de
            // la hora corta y por dentro, la de los minutos larga y por fuera.
            // Con radios distintos ademas no se pisan cuando coinciden, que
            // pasa a cada hora en punto y a y media —y es tambien lo que hace
            // que se puedan coger por separado con el dedo.
            marca(.hora)
            marca(.minuto)
        }
        .frame(width: diametro, height: diametro)
    }

    // MARK: - Las marcas

    /// Angulo de una marca, en radianes desde las doce.
    ///
    /// La de la hora salta de hora en hora y **no** avanza con los minutos. A
    /// las 7:05 sigue clavada en el 7: aqui la esfera se lee de un vistazo
    /// desde la cama, y una marca a medio camino entre dos numeros es justo lo
    /// que obliga a mirar dos veces.
    private func angulo(de cual: Manecilla) -> Double {
        switch cual {
        case .hora: Double(resto(hora, entre: 12)) / 12 * 2 * .pi
        case .minuto: Double(resto(minuto, entre: 60)) / 60 * 2 * .pi
        }
    }

    /// Una marca sobre la esfera. El angulo se mide desde las doce y en el
    /// sentido de las agujas, no desde el eje X: es como se piensa una hora.
    private func marca(_ cual: Manecilla) -> some View {
        let sitio = Esferica.sitio(de: cual)
        let inclinacion = angulo(de: cual)
        let tamano = diametro * sitio.bolita
        // El halo solo sale en la esfera de tocar, y solo en la manecilla que
        // manda ahora mismo: es la unica pista de que esto se arrastra.
        let elegida = ajustable && manecilla == cual

        return Circle()
            .fill(activa ? Paleta.acento : Paleta.textoTenue)
            .frame(width: tamano, height: tamano)
            .overlay {
                if elegida {
                    Circle()
                        .stroke(Paleta.acento.opacity(0.45), lineWidth: 2)
                        .padding(-tamano * 0.6)
                }
            }
            .offset(x: diametro * sitio.radio * sin(inclinacion),
                    y: -diametro * sitio.radio * cos(inclinacion))
            .animation(.snappy(duration: 0.14), value: inclinacion)
    }

    // MARK: - El dedo

    private var arrastreDeLaEsfera: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dedoPuesto) { _, puesto, _ in puesto = true }
            .onChanged { gesto in mueve(hasta: gesto.location) }
    }

    /// Un toque o un paso del arrastre.
    ///
    /// Que manecilla se mueve se decide **en el primer contacto y no cambia en
    /// todo el gesto**. Es la regla que evita el bug feo: al arrastrar la
    /// bolita de los minutos hacia dentro se cruza el anillo de la hora, y sin
    /// esta memoria el dedo soltaria una y engancharia la otra a medio camino.
    private func mueve(hasta punto: CGPoint) {
        let enCurso = arrastre ?? Arrastre(
            manecilla: Esferica.manecilla(paraToque: punto, diametro: diametro,
                                          hora: hora, minuto: minuto),
            posicionPreviaDeLaHora: nil
        )

        // El dedo empezo donde no se coge nada (los digitos del centro). El
        // gesto entero se ignora, aunque luego salga al anillo: si no, tocar
        // la hora y arrastrar sin querer la cambiaria.
        guard let cual = enCurso.manecilla else {
            arrastre = enCurso
            return
        }

        let vueltas = Esferica.vueltas(hasta: punto, diametro: diametro)
        switch cual {
        case .hora:
            let nueva = Esferica.hora(en: vueltas, desde: hora,
                                      posicionPrevia: enCurso.posicionPreviaDeLaHora)
            hora = nueva
            arrastre = Arrastre(manecilla: .hora, posicionPreviaDeLaHora: resto(nueva, entre: 12))
        case .minuto:
            minuto = Esferica.minuto(en: vueltas)
            arrastre = Arrastre(manecilla: .minuto, posicionPreviaDeLaHora: nil)
        }

        if manecilla != cual { manecilla = cual }
    }

    /// VoiceOver no arrastra: sube y baja de uno en uno la manecilla elegida.
    private func ajusta(_ direccion: AccessibilityAdjustmentDirection) {
        let paso = direccion == .increment ? 1 : -1
        switch manecilla {
        case .hora: hora = resto(hora + paso, entre: 24)
        case .minuto: minuto = resto(minuto + paso, entre: 60)
        }
    }

    private struct Arrastre {
        /// `nil` = este gesto no cogio ninguna bolita.
        var manecilla: Manecilla?
        /// En que hora del 0 al 11 estaba la marca en el paso anterior. Es lo
        /// que permite ver que ha dado la vuelta por las doce.
        var posicionPreviaDeLaHora: Int?
    }
}

// MARK: - La geometria de la esfera

/// Las cuentas de la esfera, aparte de la vista para poder probarlas.
///
/// Todo va en fracciones del diametro, nunca en puntos: la esfera sale a 230 en
/// la pantalla de editar, a 250 en la lista y a 82 en el muestrario, y las
/// bolitas tienen que caer en el mismo sitio en las tres.
enum Esferica {
    /// Donde vive cada bolita: a que distancia del centro y como de gorda.
    struct Sitio {
        let radio: Double
        let bolita: Double
    }

    static func sitio(de cual: Manecilla) -> Sitio {
        switch cual {
        case .hora: Sitio(radio: 0.315, bolita: 0.042)
        case .minuto: Sitio(radio: 0.415, bolita: 0.030)
        }
    }

    /// Por dentro de esto no se coge nada: son los digitos de matriz, que a dos
    /// pisos llegan bastante mas lejos del centro de lo que parece.
    static let zonaMuerta = 0.26

    /// Frontera entre el anillo de la hora y el de los minutos: justo en medio
    /// de las dos bolitas, salga donde salga cada una.
    static let frontera = (sitio(de: .hora).radio + sitio(de: .minuto).radio) / 2

    /// Si el dedo cae a menos de esto de una bolita, la coge aunque haya caido
    /// en el anillo del otro. Es lo que hace que apuntar a la bolita funcione
    /// aunque se falle por unos milimetros.
    static let agarre = 0.09

    /// Vueltas desde las doce y en el sentido de las agujas, de 0 a 1.
    static func vueltas(hasta punto: CGPoint, diametro: CGFloat) -> Double {
        let (dx, dy) = desviacion(punto, diametro)
        let vuelta = atan2(dx, -dy) / (2 * .pi)
        return vuelta < 0 ? vuelta + 1 : vuelta
    }

    /// Distancia al centro, en fracciones del diametro.
    static func radio(hasta punto: CGPoint, diametro: CGFloat) -> Double {
        let (dx, dy) = desviacion(punto, diametro)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Que bolita coge este toque, o `nil` si no coge ninguna.
    ///
    /// Se decide en dos pasos, y el orden importa:
    ///
    /// 1. **Por cercania a la bolita.** Si el dedo cae encima de una, es esa.
    ///    Cuando las dos coinciden —cada hora en punto, y a y media— este paso
    ///    sigue sin dudar: estan a distinto radio, asi que la de dentro y la de
    ///    fuera nunca empatan salvo justo en el punto medio, y ahi manda la
    ///    hora.
    /// 2. **Por anillo.** Si no, el de dentro es la hora y el de fuera los
    ///    minutos, apunte el dedo a donde apunte. Asi tocar el borde de la
    ///    esfera mueve los minutos aunque las dos bolitas esten en la otra
    ///    punta, que es lo que se espera de un reloj.
    static func manecilla(
        paraToque punto: CGPoint,
        diametro: CGFloat,
        hora: Int,
        minuto: Int
    ) -> Manecilla? {
        let distanciaAlCentro = radio(hasta: punto, diametro: diametro)
        guard distanciaAlCentro >= zonaMuerta else { return nil }

        let (dx, dy) = desviacion(punto, diametro)
        let aLaHora = distancia(dx, dy, a: Double(resto(hora, entre: 12)) / 12, sitio: sitio(de: .hora))
        let alMinuto = distancia(dx, dy, a: Double(resto(minuto, entre: 60)) / 60, sitio: sitio(de: .minuto))
        if min(aLaHora, alMinuto) <= agarre {
            return aLaHora <= alMinuto ? .hora : .minuto
        }
        return distanciaAlCentro < frontera ? .hora : .minuto
    }

    /// El minuto al que apunta el dedo. Da la vuelta sola: pasado el 59 vuelve
    /// al 0 sin tocar la hora.
    static func minuto(en vueltas: Double) -> Int {
        resto(Int((vueltas * 60).rounded()), entre: 60)
    }

    /// La hora a la que apunta el dedo, de 0 a 23.
    ///
    /// La esfera tiene doce posiciones y el dia tiene veinticuatro horas, asi
    /// que hace falta una regla para la mitad del dia. Es esta: **la mitad solo
    /// cambia dando la vuelta por las doce**. Arrastrando hacia adelante, de
    /// las 11 a las 12 se pasa al mediodia; siguiendo hasta las 23, otra vuelta
    /// mas y vuelve a la madrugada. Dos vueltas enteras son el dia entero.
    ///
    /// El primer contacto del gesto no lleva `posicionPrevia` y por eso nunca
    /// cambia de mitad: tocar el 1 estando a las 11 de la manana pone la 1 de
    /// la tarde solo si se ha llegado ahi arrastrando, no de un salto.
    static func hora(en vueltas: Double, desde actual: Int, posicionPrevia: Int?) -> Int {
        let posicion = resto(Int((vueltas * 12).rounded()), entre: 12)
        var tarde = resto(actual, entre: 24) >= 12
        if let previa = posicionPrevia {
            let saltoHaciaAdelante = previa >= 9 && posicion <= 2
            let saltoHaciaAtras = previa <= 2 && posicion >= 9
            if saltoHaciaAdelante || saltoHaciaAtras { tarde.toggle() }
        }
        return posicion + (tarde ? 12 : 0)
    }

    // MARK: - Cuentas sueltas

    /// Del punto de la vista a fracciones del diametro desde el centro.
    private static func desviacion(_ punto: CGPoint, _ diametro: CGFloat) -> (Double, Double) {
        let centro = diametro / 2
        return (Double(punto.x - centro) / Double(diametro),
                Double(punto.y - centro) / Double(diametro))
    }

    /// Distancia del dedo a una bolita puesta en `vueltas`.
    private static func distancia(_ dx: Double, _ dy: Double, a vueltas: Double, sitio: Sitio) -> Double {
        let angulo = vueltas * 2 * .pi
        let bx = sitio.radio * sin(angulo)
        let by = -sitio.radio * cos(angulo)
        return ((dx - bx) * (dx - bx) + (dy - by) * (dy - by)).squareRoot()
    }
}

/// Resto que nunca sale negativo. `-1 % 12` en Swift es `-1`, y una manecilla
/// en la posicion -1 no existe: bajando de las 00:00 se va a las 23:00.
func resto(_ valor: Int, entre modulo: Int) -> Int {
    let sobra = valor % modulo
    return sobra < 0 ? sobra + modulo : sobra
}

/// El canto del disco: rayitas finas hacia dentro, como el moleteado de una
/// rueda de metal. Es lo que le quita cara de circulo dibujado.
private struct CantoMoleteado: View {
    var body: some View {
        Canvas { contexto, tamano in
            let centro = CGPoint(x: tamano.width / 2, y: tamano.height / 2)
            let radio = min(tamano.width, tamano.height) / 2
            let rayas = 120
            for indice in 0..<rayas {
                let angulo = Double(indice) / Double(rayas) * 2 * .pi
                let larga = indice % 10 == 0
                let dentro = radio - (larga ? radio * 0.05 : radio * 0.028)
                var trazo = Path()
                trazo.move(to: CGPoint(x: centro.x + cos(angulo) * dentro,
                                       y: centro.y + sin(angulo) * dentro))
                trazo.addLine(to: CGPoint(x: centro.x + cos(angulo) * radio,
                                          y: centro.y + sin(angulo) * radio))
                contexto.stroke(
                    trazo,
                    with: .color(Paleta.textoTenue.opacity(larga ? 0.45 : 0.22)),
                    lineWidth: 1
                )
            }
        }
    }
}

#Preview("Esfera") {
    MuestraDeEsfera().preferredColorScheme(.dark)
}

struct MuestraDeEsfera: View {
    // Las horas elegidas son las que hacen dano: 12:00 pone las dos marcas en
    // el mismo angulo, 6:30 tambien, y 7:05 es la que pidio el usuario.
    private let horas = [(6, 30), (7, 5), (12, 0), (9, 45)]

    @State private var hora = 7
    @State private var minuto = 0
    @State private var manecilla: Manecilla = .hora

    var body: some View {
        ScrollView {
            VStack(spacing: Espacio.ancho) {
                EsferaDeReloj(hora: $hora, minuto: $minuto, manecilla: $manecilla)
                Text("De tocar. Ahora manda: \(manecilla.nombre)")
                    .font(Tipografia.pie)
                    .foregroundStyle(Paleta.textoTenue)
                HStack(spacing: Espacio.normal) {
                    ForEach(horas, id: \.0) { hora, minuto in
                        EsferaDeReloj(hora: hora, minuto: minuto, diametro: 82)
                    }
                }
                EsferaDeReloj(hora: 8, minuto: 20, activa: false, diametro: 140)
            }
            .padding(Espacio.ancho)
            .frame(maxWidth: .infinity)
        }
        .fondoDePantalla()
    }
}
