import Foundation
import Observation
import AlarmCore
import DesignSystem
import Persistence

/// Lo que hay entre el disco y la pantalla de racha.
///
/// Hace tres cosas y ninguna mas: arranca (que es cuando se cobran los dias que
/// nadie conto), lee, y le da a la vista un `DatosDeRacha` ya hecho. No decide
/// reglas — de eso va `AlarmCore` entero — ni escribe por su cuenta fuera del
/// arranque.
///
/// Es `@MainActor` porque lo unico que consume esto es una vista. El trabajo de
/// disco pasa por `AlmacenSwiftData`, que es un actor propio, asi que aqui solo
/// se espera.
@MainActor
@Observable
final class ModeloDeRacha {

    /// Lo que se pinta. Arranca vacio y con el plan de verdad para no ensenar
    /// datos de mentira ni medio segundo.
    private(set) var datos: DatosDeRacha

    /// El fallo que impide leer o escribir la racha, si lo hay. Se ensena en vez
    /// de la pantalla: una racha que no se puede leer no se puede inventar, y
    /// pintar un cero seria decirle a alguien con 200 dias que los ha perdido.
    private(set) var fallo: String?

    private let almacen: AlmacenSwiftData
    private let resolutor: ResolutorDeDia
    private let fuenteDelPlan: FuenteDelPlan
    /// El calendario del dispositivo, cogido una vez. Aqui es donde `Date` se
    /// convierte en `Day` y donde se queda: el dominio no ve fechas.
    private let calendario: Calendar

    init(almacen: AlmacenSwiftData, fuenteDelPlan: FuenteDelPlan = FuenteDelPlan(), calendario: Calendar = .current) {
        self.almacen = almacen
        self.fuenteDelPlan = fuenteDelPlan
        self.calendario = calendario
        self.resolutor = ResolutorDeDia(almacen: almacen, plan: { fuenteDelPlan.actual() })
        self.datos = DatosDeRacha(
            estado: StreakState(),
            plan: fuenteDelPlan.actual(),
            registrosDelMes: [],
            hoy: Day(Date(), calendar: calendario)
        )
    }

    private var hoy: Day { Day(Date(), calendar: calendario) }

    /// Lo primero que hace la app, y lo primero que hace al volver del fondo.
    ///
    /// El orden de los dos cobros no es intercambiable:
    ///
    /// 1. **El reto huerfano**, que puede ser de un dia anterior. Resolverlo
    ///    mueve `lastCountedDay`, que es la frontera desde la que barre el paso
    ///    siguiente.
    /// 2. **Los dias perdidos**, los que sonaron sin que nadie los contara.
    ///
    /// Se vuelve a llamar al volver del fondo porque el dia puede haber
    /// cambiado con la app abierta: quien la deja abierta toda la noche tiene
    /// que encontrarse el dia de ayer cobrado por la manana.
    func arrancar() async {
        do {
            try await resolutor.resolverRetoHuerfano()

            // Las alarmas, tal y como suenan de verdad con el plan de turno. Sin
            // este filtro se penalizarian dias en los que no sono nada porque el
            // plan ya le habia quitado al usuario la repeticion por dias.
            let plan = fuenteDelPlan.actual()
            let alarmas = PoliticaDelPlan.alarmasEfectivas(try await almacen.all(), plan: plan)
            try await resolutor.resolverDiasPerdidos(hasta: hoy, alarmas: alarmas, calendario: calendario)

            await recargar()
        } catch {
            fallo = "No se ha podido abrir tu racha."
        }
    }

    /// El reto de hoy, completado entero. Es lo unico que suma un dia.
    ///
    /// Vive aqui y no en `ModeloDeReto` por una razon que no es de estilo: el
    /// `ResolutorDeDia` es un actor **y tiene que haber uno solo**. Serializa
    /// las resoluciones para que dos no se pisen, y dos instancias distintas
    /// sobre el mismo disco no serializan nada: leerian el mismo estado de
    /// partida y una de las dos escrituras se perderia. El caso es real —al
    /// arrancar se resuelve el reto huerfano de anoche mientras el de hoy ya
    /// puede estar en marcha—, asi que el resolutor no sale de esta clase.
    ///
    /// Devuelve `false` si no se pudo guardar. Quien llama tiene que enterarse:
    /// callarselo seria dejar a alguien celebrando un dia que no esta escrito.
    @discardableResult
    func completarReto(
        alarmID: Alarm.ID,
        reto: ChallengeType,
        duracion: TimeInterval
    ) async -> Bool {
        do {
            try await resolutor.resolver(
                .completado,
                dia: hoy,
                alarmID: alarmID,
                challenge: reto,
                duration: duracion
            )
            await recargar()
            return true
        } catch {
            fallo = "No se ha podido guardar tu racha."
            return false
        }
    }

    /// Vuelve a leer del disco. Se llama tras resolver un dia.
    func recargar() async {
        let dia = hoy
        do {
            let estado = try await almacen.load()
            // Solo el mes que se ensena. `records(from:to:)` devuelve un rango y
            // el calendario de la pantalla se queda con el mes de `hoy` de todas
            // formas; pedir de mas seria traerse el historial entero a memoria.
            let registros = try await almacen.records(
                from: Day(year: dia.year, month: dia.month, day: 1),
                to: dia
            )
            datos = DatosDeRacha(
                estado: estado,
                plan: fuenteDelPlan.actual(),
                registrosDelMes: registros,
                hoy: dia
            )
            fallo = nil
        } catch {
            fallo = "No se ha podido leer tu racha."
        }
    }
}
