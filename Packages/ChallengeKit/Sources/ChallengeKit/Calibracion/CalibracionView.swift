import Foundation

#if os(iOS) && canImport(SwiftUI)
import SwiftUI
#if canImport(Charts)
import Charts
#endif

/// La herramienta de calibracion: graba sentadillas de verdad, las guarda y las
/// vuelve a pasar por el detector todas las veces que haga falta.
///
/// **Es una pantalla de desarrollo, no de producto.** No usa `DesignSystem` a
/// proposito: no es de la app que ve el usuario, y engancharla al sistema de
/// diseno la ataria al trabajo de otro agente sin ganar nada.
///
/// Para llegar a ella hace falta presentarla desde el target de la app. Eso son
/// ficheros que no son de este paquete, asi que no los toco: va explicado en el
/// PR.
public struct CalibracionView: View {

    @State private var modelo = ModeloDeCalibracion()
    @State private var seleccionada: Grabacion?

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                seccionGrabar
                seccionParametros
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
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .sheet(item: $seleccionada) { grabacion in
                DetalleDeGrabacionView(
                    resultado: modelo.reproduce(grabacion),
                    parametros: modelo.parametros
                )
            }
        }
    }

    // MARK: - Grabar

    private var seccionGrabar: some View {
        Section("Grabar") {
            Picker("Tipo", selection: $modelo.tipo) {
                Text("Sentadillas").tag(Grabacion.Tipo.sentadillas)
                Text("Trampa").tag(Grabacion.Tipo.trampa)
            }
            .pickerStyle(.segmented)
            .disabled(modelo.estado == .grabando)

            TextField("Etiqueta (mano derecha, Hugo 1,78 m)", text: $modelo.etiqueta)
                .disabled(modelo.estado == .grabando)

            if modelo.tipo == .sentadillas {
                Stepper(
                    "Repeticiones reales: \(modelo.repeticionesReales)",
                    value: $modelo.repeticionesReales,
                    in: 1...50
                )
                .disabled(modelo.estado == .grabando)
            }

            TextField("Notas", text: $modelo.notas, axis: .vertical)
                .disabled(modelo.estado == .grabando)

            if modelo.estado == .grabando {
                LabeledContent("Contadas en vivo") {
                    Text("\(modelo.repeticionesEnVivo)")
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(
                            modelo.repeticionesEnVivo == modelo.repeticionesReales
                                ? .green : .primary
                        )
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
                    contadas: modelo.contadasPorURL[fila.url] ?? 0
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

            ForEach(Array(modelo.candidatos.enumerated()), id: \.offset) { i, candidato in
                Button {
                    modelo.adopta(candidato)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("#\(i + 1) — clava \(candidato.aciertosExactos) de \(candidato.resultados.filter { $0.grabacion.tipo == .sentadillas }.count)")
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
            Text("Prueba cientos de combinaciones contra todas las grabaciones a la vez. Descarta las que dejarian que la trampa llegue a 10, y penaliza el triple no contar una sentadilla real que contar una de mas.")
        }
    }
}

// MARK: - Fila

private struct FilaDeGrabacion: View {
    let grabacion: Grabacion
    let url: URL
    let contadas: Int

    private var acierta: Bool {
        switch grabacion.tipo {
        case .sentadillas: contadas == grabacion.repeticionesReales
        case .trampa: contadas < 10
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(grabacion.etiqueta).font(.subheadline.bold())
                Text(String(
                    format: "%@ · %.0f s · %d muestras",
                    grabacion.tipo == .trampa ? "trampa" : "sentadillas",
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
#endif
