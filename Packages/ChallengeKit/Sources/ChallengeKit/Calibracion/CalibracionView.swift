import Foundation
import AlarmCore

#if os(iOS) && canImport(SwiftUI)
import SwiftUI
#if canImport(Charts)
import Charts
#endif

/// La herramienta de calibracion: graba movimiento de verdad —sentadillas o
/// pasos—, lo guarda y lo vuelve a pasar por el detector todas las veces que
/// haga falta.
///
/// **Es una pantalla de desarrollo, no de producto.** No usa `DesignSystem` a
/// proposito: no es de la app que ve el usuario, y engancharla al sistema de
/// diseno la ataria al trabajo de otro agente sin ganar nada.
///
/// Cuelga de una pestana en `RepRiseApp`, solo en `DEBUG` y solo mientras no
/// haya un reto en marcha: durante el reto la pestana desaparece, que si no
/// seria la via de escape mas comoda para no levantarse de la cama.
public struct CalibracionView: View {

    @State private var modelo = ModeloDeCalibracion()
    @State private var seleccionada: Grabacion?

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                seccionGrabar
                seccionParametros
                seccionParametrosDePaso
                seccionGrabaciones
                seccionBarrido
            }
            .navigationTitle("Calibracion")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                modelo.carga()
                // Grabar con la pantalla apagandose a mitad arruina la sesion.
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                // Si salta una alarma con esto grabando, SwiftUI se lleva la
                // pestana por delante y nadie para el `CMMotionManager`. Se
                // quedaria vivo mientras `StepDetector` arranca el suyo, y Apple
                // avisa de que dos instancias degradan la entrega: justo en el
                // momento en que hace falta contar bien. Se descarta, no se
                // guarda: una sesion cortada a medias no vale para calibrar.
                Task { await modelo.descarta() }
            }
            .sheet(item: $seleccionada) { grabacion in
                if grabacion.tipo == .pasos {
                    DetalleDePasosView(resultado: modelo.reproducePasos(grabacion))
                } else {
                    DetalleDeGrabacionView(
                        resultado: modelo.reproduce(grabacion),
                        parametros: modelo.parametros
                    )
                }
            }
        }
    }

    // MARK: - Grabar

    private var seccionGrabar: some View {
        Section("Grabar") {
            Picker("Tipo", selection: $modelo.tipo) {
                Text("Sentadillas").tag(Grabacion.Tipo.sentadillas)
                Text("Pasos").tag(Grabacion.Tipo.pasos)
                Text("Trampa").tag(Grabacion.Tipo.trampa)
            }
            .pickerStyle(.segmented)
            .disabled(modelo.estado == .grabando)
            // Los objetivos de los dos retos son distintos y teclearlo cada vez
            // es la clase de friccion que acaba en grabaciones mal etiquetadas.
            .onChange(of: modelo.tipo) { _, nuevo in
                switch nuevo {
                case .sentadillas: modelo.repeticionesReales = ChallengeType.sentadillas.goal
                case .pasos: modelo.repeticionesReales = ChallengeType.pasos.goal
                case .trampa: break
                }
            }

            TextField("Etiqueta (mano derecha, Hugo 1,78 m)", text: $modelo.etiqueta)
                .disabled(modelo.estado == .grabando)

            if modelo.tipo != .trampa {
                Stepper(
                    "\(modelo.tipo == .pasos ? "Pasos" : "Repeticiones") reales: \(modelo.repeticionesReales)",
                    value: $modelo.repeticionesReales,
                    in: 1...100
                )
                .disabled(modelo.estado == .grabando)
            }

            TextField("Notas", text: $modelo.notas, axis: .vertical)
                .disabled(modelo.estado == .grabando)

            if modelo.estado == .grabando {
                if modelo.tipo == .trampa {
                    // Una trampa lo es de los dos retos, asi que se enseñan los
                    // dos contadores. Enseñar solo uno fue como se colo un fallo
                    // entero: la muneca marcaba 1 sentadilla y 16 pasos.
                    LabeledContent("Sentadillas en vivo") {
                        Text("\(modelo.repeticionesEnVivo)")
                            .font(.title2.monospacedDigit().bold())
                    }
                    LabeledContent("Pasos en vivo") {
                        Text("\(modelo.pasosEnVivo)")
                            .font(.title2.monospacedDigit().bold())
                    }
                } else {
                    LabeledContent("Contadas en vivo") {
                        Text("\(modelo.contadasEnVivo)")
                            .font(.title2.monospacedDigit().bold())
                            .foregroundStyle(
                                modelo.contadasEnVivo == modelo.repeticionesReales
                                    ? .green : .primary
                            )
                    }
                }
                LabeledContent("Muestras", value: "\(modelo.muestrasGrabadas)")
                LabeledContent("Duracion", value: String(format: "%.1f s", modelo.duracionGrabada))

                Button("Parar y guardar") {
                    Task { await modelo.paraYGuarda() }
                }
                .buttonStyle(.borderedProminent)

                Button("Descartar", role: .destructive) {
                    Task { await modelo.descarta() }
                }
            } else {
                Button("Empezar a grabar") {
                    Task { await modelo.empieza() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(modelo.estado == .barriendo)
            }

            if let error = modelo.ultimoError {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
        }
    }

    // MARK: - Parametros

    private var seccionParametros: some View {
        Section {
            deslizador("Recorrido minimo", $modelo.parametros.recorridoMinimo, 0.02...0.30, "%.3f m")
            deslizador("Duracion minima", $modelo.parametros.duracionMinima, 0.30...1.50, "%.2f s")
            deslizador("Velocidad de subida", $modelo.parametros.velocidadSubidaMinima, 0.02...0.30, "%.3f m/s")
            deslizador("Fuga de la altura", $modelo.parametros.tauAltura, 0.4...3.0, "%.2f s")
            deslizador("Suavizado", $modelo.parametros.tauSuavizado, 0.03...0.30, "%.3f s")

            Button("Volver a los de por defecto") {
                modelo.parametros = .porDefecto
            }
            Button("Copiar como codigo Swift") {
                UIPasteboard.general.string = modelo.parametrosComoSwift
            }
        } header: {
            Text("Parametros")
        } footer: {
            Text("Cambiarlos aqui recuenta al vuelo todas las grabaciones de abajo. Cuando uno convenza, copialo y pegalo en ParametrosSentadilla.")
        }
    }

    private func deslizador(
        _ titulo: String,
        _ valor: Binding<Double>,
        _ rango: ClosedRange<Double>,
        _ formato: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(titulo).font(.subheadline)
                Spacer()
                Text(String(format: formato, valor.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: valor, in: rango) { editando in
                // Al soltar, no en cada pixel: recontar es recorrer todas las
                // grabaciones enteras.
                if !editando { modelo.recuenta() }
            }
        }
    }

    // MARK: - Parametros de paso

    private var seccionParametrosDePaso: some View {
        Section {
            deslizador("Umbral minimo", $modelo.parametrosDePaso.umbralMinimo, 0.05...1.0, "%.2f m/s²")
            deslizador("Factor del umbral", $modelo.parametrosDePaso.factorDeUmbral, 0.3...1.5, "%.2f")
            deslizador("Tiempo entre pasos", $modelo.parametrosDePaso.intervaloMinimo, 0.10...0.50, "%.2f s")
            deslizador("Techo del pico", $modelo.parametrosDePaso.techoDePico, 3.0...20.0, "%.1f m/s²")
            deslizador("Filtro de vibracion", $modelo.parametrosDePaso.fraccionDeBajaFrecuencia, 0.10...0.80, "%.2f")
            deslizador("Suavizado", $modelo.parametrosDePaso.tauSuavizado, 0.02...0.20, "%.3f s")

            Button("Volver a los de por defecto") {
                modelo.parametrosDePaso = .porDefecto
                modelo.recuenta()
            }
            Button("Copiar como codigo Swift") {
                UIPasteboard.general.string = modelo.parametrosDePasoComoSwift
            }
        } header: {
            Text("Parametros de paso")
        } footer: {
            Text("El techo del pico es el que frena la sacudida: bajarlo cierra la trampa pero empieza a comerse pisadas fuertes, y comerse pasos de quien esta andando es el fallo que trajo aqui. Ante la duda, subirlo.")
        }
    }

    // MARK: - Grabaciones

    private var seccionGrabaciones: some View {
        Section("Grabaciones (\(modelo.grabaciones.count))") {
            if modelo.grabaciones.isEmpty {
                Text("Todavia ninguna. Sin grabaciones, afinar el detector es adivinar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(modelo.grabaciones, id: \.url) { fila in
                FilaDeGrabacion(
                    grabacion: fila.grabacion,
                    url: fila.url,
                    contadas: modelo.contadasPorURL[fila.url] ?? 0,
                    acierta: modelo.aciertaPorURL[fila.url] ?? false
                )
                .contentShape(Rectangle())
                .onTapGesture { seleccionada = fila.grabacion }
                .swipeActions {
                    Button("Borrar", role: .destructive) { modelo.borra(fila.url) }
                }
            }
        }
    }

    // MARK: - Barrido

    private var seccionBarrido: some View {
        Section {
            Button(modelo.estado == .barriendo ? "Barriendo..." : "Barrer parametros") {
                Task { await modelo.barre() }
            }
            .disabled(modelo.estado != .parado || modelo.grabaciones.isEmpty)

            if modelo.candidatosDePaso.isEmpty && !modelo.grabaciones.isEmpty {
                Text("Para barrer los pasos hace falta al menos una grabacion de tipo Pasos: sin ella el barrido no puede saber a quien le esta quitando pisadas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(modelo.candidatosDePaso.enumerated()), id: \.offset) { i, candidato in
                Button {
                    modelo.adopta(candidato)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pasos #\(i + 1) — clava \(candidato.aciertosExactos) de \(candidato.resultados.filter { $0.grabacion.tipo == .pasos }.count)")
                            .font(.subheadline.bold())
                        Text("faltan \(candidato.faltantes) · sobran \(candidato.sobrantes) · trampa llega a \(candidato.maximoEnTrampas)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(String(
                            format: "umbral %.2f · factor %.2f · intervalo %.2f · techo %.1f",
                            candidato.parametros.umbralMinimo,
                            candidato.parametros.factorDeUmbral,
                            candidato.parametros.intervaloMinimo,
                            candidato.parametros.techoDePico
                        ))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(Array(modelo.candidatos.enumerated()), id: \.offset) { i, candidato in
                Button {
                    modelo.adopta(candidato)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sentadillas #\(i + 1) — clava \(candidato.aciertosExactos) de \(candidato.resultados.filter { $0.grabacion.tipo == .sentadillas }.count)")
                            .font(.subheadline.bold())
                        Text("faltan \(candidato.faltantes) · sobran \(candidato.sobrantes) · trampa llega a \(candidato.maximoEnTrampas)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(String(
                            format: "recorrido %.3f · duracion %.2f · vel %.3f · tau %.2f",
                            candidato.parametros.recorridoMinimo,
                            candidato.parametros.duracionMinima,
                            candidato.parametros.velocidadSubidaMinima,
                            candidato.parametros.tauAltura
                        ))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Barrido")
        } footer: {
            Text("Prueba cientos de combinaciones contra todas las grabaciones a la vez, para los dos retos. Descarta las que dejarian que la trampa llegue al objetivo, y penaliza el triple no contar algo real que contar de mas.")
        }
    }
}

// MARK: - Fila

private struct FilaDeGrabacion: View {
    let grabacion: Grabacion
    let url: URL
    let contadas: Int
    /// Lo decide `ModeloDeCalibracion`, que es donde se tienen las dos cuentas.
    let acierta: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(grabacion.etiqueta).font(.subheadline.bold())
                Text(String(
                    format: "%@ · %.0f s · %d muestras",
                    grabacion.tipo.rawValue,
                    grabacion.duracion,
                    grabacion.muestras.count
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(contadas) / \(grabacion.repeticionesReales)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(acierta ? .green : .red)
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    .labelStyle(.iconOnly)
            }
        }
    }
}

// MARK: - Detalle

/// La curva. Mirar la senal es la mitad del trabajo: el numero dice que fallo,
/// el dibujo dice por que.
private struct DetalleDeGrabacionView: View {
    let resultado: ResultadoDeReproduccion
    let parametros: ParametrosSentadilla
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(resultado.grabacion.etiqueta).font(.headline)
                    Text("Contadas \(resultado.contadas) de \(resultado.grabacion.repeticionesReales) reales")
                        .font(.subheadline)
                        .foregroundStyle(resultado.acierta ? .green : .red)
                    if !resultado.grabacion.notas.isEmpty {
                        Text(resultado.grabacion.notas)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    grafico

                    if !resultado.instantes.isEmpty {
                        Text("Repeticiones en: " + resultado.instantes
                            .map { String(format: "%.1f s", $0) }
                            .joined(separator: ", "))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Grabacion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var grafico: some View {
        #if canImport(Charts)
        Chart {
            ForEach(Array(resultado.traza.enumerated()), id: \.offset) { _, s in
                LineMark(
                    x: .value("t", s.t),
                    y: .value("altura", s.altura),
                    series: .value("senal", "altura")
                )
                .foregroundStyle(.blue)
            }
            RuleMark(y: .value("umbral", -parametros.recorridoMinimo))
                .foregroundStyle(.orange.opacity(0.6))
                .lineStyle(StrokeStyle(dash: [4, 4]))
            ForEach(Array(resultado.instantes.enumerated()), id: \.offset) { _, t in
                RuleMark(x: .value("rep", t))
                    .foregroundStyle(.green.opacity(0.5))
            }
        }
        .frame(height: 220)
        .chartYAxisLabel("altura estimada (m)")
        #else
        Text("Sin Charts en esta plataforma.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        #endif
    }
}

// MARK: - Detalle de una grabacion de pasos

/// La misma idea que el detalle de sentadillas, con la senal que importa aqui:
/// la aceleracion ya filtrada y el umbral, que es adaptativo. Sin pintar el
/// umbral la curva no explica nada, porque el liston se mueve con la senal.
private struct DetalleDePasosView: View {
    let resultado: ResultadoDePasos
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(resultado.grabacion.etiqueta).font(.headline)
                    Text("Contados \(resultado.contados) de \(resultado.grabacion.repeticionesReales) reales")
                        .font(.subheadline)
                        .foregroundStyle(resultado.acierta ? .green : .red)
                    if !resultado.grabacion.notas.isEmpty {
                        Text(resultado.grabacion.notas)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    grafico

                    if !resultado.instantes.isEmpty {
                        Text("Cadencia media: " + cadencia)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Grabacion de pasos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    /// Pasos por segundo entre el primero y el ultimo. Un numero fuera de 1-3
    /// delata que se estan contando picos que no son pisadas.
    private var cadencia: String {
        guard let primero = resultado.instantes.first,
              let ultimo = resultado.instantes.last,
              ultimo > primero
        else { return "—" }
        let pasos = Double(resultado.instantes.count - 1)
        return String(format: "%.2f pasos/s", pasos / (ultimo - primero))
    }

    @ViewBuilder
    private var grafico: some View {
        #if canImport(Charts)
        Chart {
            ForEach(Array(resultado.traza.enumerated()), id: \.offset) { _, s in
                LineMark(
                    x: .value("t", s.t),
                    y: .value("aceleracion", s.aceleracionFiltrada),
                    series: .value("senal", "aceleracion")
                )
                .foregroundStyle(.blue)
                LineMark(
                    x: .value("t", s.t),
                    y: .value("umbral", s.umbral),
                    series: .value("senal", "umbral")
                )
                .foregroundStyle(.orange.opacity(0.7))
            }
            ForEach(Array(resultado.instantes.enumerated()), id: \.offset) { _, t in
                RuleMark(x: .value("paso", t))
                    .foregroundStyle(.green.opacity(0.35))
            }
        }
        .frame(height: 220)
        .chartYAxisLabel("aceleracion vertical filtrada (m/s²)")
        #else
        Text("Sin Charts en esta plataforma.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        #endif
    }
}
#endif
