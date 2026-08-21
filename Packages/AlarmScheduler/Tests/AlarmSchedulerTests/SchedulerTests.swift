import Testing
import Foundation
import AlarmCore
@testable import AlarmScheduler

@Suite("Programador de vista previa")
struct PreviewAlarmSchedulerTests {
    private let alarma = DomainAlarm(hour: 7, minute: 0, weekdays: [.lunes], challenge: .pasos)

    @Test("Programar y cancelar")
    func programarYCancelar() async throws {
        let programador = PreviewAlarmScheduler()
        try await programador.schedule(alarma)
        #expect(try await programador.scheduledAlarmIDs() == [alarma.id])
        try await programador.cancel(alarmID: alarma.id)
        #expect(try await programador.scheduledAlarmIDs().isEmpty)
    }

    @Test("Pedir permiso lo concede solo si no estaba decidido")
    func permiso() async throws {
        let sinDecidir = PreviewAlarmScheduler(authorization: .noDeterminado)
        #expect(try await sinDecidir.requestAuthorization() == .autorizado)

        let denegado = PreviewAlarmScheduler(authorization: .denegado)
        #expect(try await denegado.requestAuthorization() == .denegado)
    }

    @Test("El sonido vuelve tras un abandono y se calla al terminar el reto")
    func sonido() async {
        let programador = PreviewAlarmScheduler()
        #expect(await programador.isSounding == false)
        await programador.resumeCurrentAlarm()
        #expect(await programador.isSounding)
        await programador.silenceCurrentAlarm()
        #expect(await programador.isSounding == false)
    }
}

@Suite("Programador del sistema fuera de iOS")
struct SystemAlarmSchedulerOnHostTests {
    /// En el host no existe AlarmKit. Que lo diga en vez de aparentar que ha
    /// programado algo: quien monte la app tiene que usar
    /// `PreviewAlarmScheduler` fuera del dispositivo.
    @Test("Todo lo que necesita AlarmKit falla con un error que se entiende")
    func fallaClaro() async {
        let programador = SystemAlarmScheduler()
        let alarma = DomainAlarm(hour: 7, minute: 0, challenge: .pasos)

        #expect(await programador.authorizationState() == .noDeterminado)
        await #expect(throws: AlarmSchedulerError.alarmKitNoDisponible) {
            try await programador.schedule(alarma)
        }
        await #expect(throws: AlarmSchedulerError.alarmKitNoDisponible) {
            try await programador.scheduledAlarmIDs()
        }
        await #expect(throws: AlarmSchedulerError.alarmKitNoDisponible) {
            try await programador.requestAuthorization()
        }
    }
}

@Suite("Textos de permiso denegado")
struct AlarmAuthorizationCopyTests {
    @Test("Hay explicacion y ruta a Ajustes, no un callejon sin salida")
    func rutaDigna() {
        #expect(!AlarmAuthorizationCopy.titulo.isEmpty)
        #expect(!AlarmAuthorizationCopy.explicacion.isEmpty)
        #expect(!AlarmAuthorizationCopy.avisoEnLista.isEmpty)
        #if os(iOS)
        #expect(AlarmAuthorizationCopy.urlDeAjustes != nil)
        #endif
    }

    @Test("Cada error sabe explicarse en espanol")
    func erroresConMensaje() {
        let errores: [AlarmSchedulerError] = [
            .sinAutorizacion, .autorizacionPendiente, .alarmKitNoDisponible,
            .limiteDeAlarmasAlcanzado, .horaInvalida(hour: 25, minute: 0),
            .fallaDeAlarmKit(descripcion: "vaya"),
            .noSePudoConsultarElSistema(descripcion: "vaya"),
            .falloAlPedirPermiso(descripcion: "vaya")
        ]
        for error in errores {
            #expect(!error.mensaje.isEmpty)
        }

        // Y cada uno cuenta **lo suyo**: los tres de AlarmKit llegan con la
        // misma descripcion opaca (`code=0 "(null)"`) y antes compartian un
        // unico caso, asi que tropezar al consultar se le contaba al usuario
        // como que no se habia podido programar la alarma.
        let programar = AlarmSchedulerError.fallaDeAlarmKit(descripcion: "x").mensaje
        let consultar = AlarmSchedulerError.noSePudoConsultarElSistema(descripcion: "x").mensaje
        let permiso = AlarmSchedulerError.falloAlPedirPermiso(descripcion: "x").mensaje
        #expect(Set([programar, consultar, permiso]).count == 3)
    }
}
