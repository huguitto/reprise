import SwiftUI

/// Lo que se ve al abrir la app: la presentacion y, al pulsar "Empezar" o
/// "Saltar", la app entera — `NavegacionPrincipal`, con su barra de secciones.
/// No la lista a secas: aterrizar en una pantalla sin barra deja al recien
/// llegado sin ver que hay racha y ranking, que es justo lo que le acaba de
/// prometer la tercera pagina.
///
/// Las dos salidas de la presentacion llevan al mismo sitio a proposito. La
/// diferencia entre pasarse las tres paginas y saltarselas es lo que sabe el
/// usuario, no donde acaba: si "Saltar" mandase a otro lado seria una trampa.
///
/// **La presentacion sale una vez y no vuelve.** La bandera va en
/// `UserDefaults` y no en `Persistence` a proposito: "ya he visto la
/// presentacion" no es estado de dominio — no entra en la racha, no tiene que
/// migrar de esquema y perderlo cuesta exactamente tres pantallas. Meterlo en
/// el almacen de las rachas seria darle un peso que no tiene.
public struct FlujoDeEntrada: View {
    @AppStorage(Self.bandera) private var vista = false
    /// La salida de la galeria, que enseña el flujo sin dejar rastro.
    @State private var vistaSoloAhora = false

    private let recordar: Bool
    /// Los modelos de la app, para pasarselos a `NavegacionPrincipal` al
    /// aterrizar. Sin esto la app entraria a datos de mentira: los parametros
    /// de `NavegacionPrincipal` tienen valor por defecto para los `#Preview`, y
    /// no pasarselos aqui no da error de compilacion, solo una app que no lee
    /// el disco de nadie.
    private let modeloDeAlarmas: ModeloDeAlarmas?
    private let plan: ModeloDelPlan?

    /// - Parameter recordar: si es `false`, el flujo no escribe ni lee la
    ///   bandera. Es lo que usa la galeria de diseño: alli la presentacion hay
    ///   que poder verla las veces que haga falta, y verla no es haberla
    ///   pasado.
    public init(
        recordar: Bool = true,
        modeloDeAlarmas: ModeloDeAlarmas? = nil,
        plan: ModeloDelPlan? = nil
    ) {
        self.recordar = recordar
        self.modeloDeAlarmas = modeloDeAlarmas
        self.plan = plan
    }

    /// La clave, en un sitio con nombre para que quien tenga que borrarla
    /// —un boton de "volver a ver la presentacion" en ajustes, un reinicio de
    /// pruebas— no la copie a mano y se equivoque en una letra.
    public static let bandera = "reprise.presentacionVista"

    private var yaPasada: Bool { recordar ? vista : vistaSoloAhora }

    public var body: some View {
        ZStack {
            if yaPasada {
                NavegacionPrincipal(modeloDeAlarmas: modeloDeAlarmas, plan: plan)
                    .transition(.opacity)
            } else {
                PantallaPresentacion(alTerminar: pasar)
                    .transition(.opacity)
            }
        }
    }

    private func pasar() {
        withAnimation(.easeInOut(duration: 0.35)) {
            if recordar {
                vista = true
            } else {
                vistaSoloAhora = true
            }
        }
    }
}

#Preview("Entrada") {
    // Sin recordar: si no, el preview solo se veria una vez por simulador.
    FlujoDeEntrada(recordar: false).preferredColorScheme(.dark)
}
