import Foundation
import Testing
import AlarmCore
@testable import AlarmScheduler

// La huella es lo que decide si hay que volver a tocar el sistema. Si se le
// escapa un campo, editar ese campo deja la alarma sonando con lo viejo: a la
// hora que no era, con el reto que no era, o con el tono que no era. Y si
// cambia cuando no debe, se cancela y se vuelve a poner por nada, abriendo un
// instante sin alarma cada vez que se sincroniza.

@Suite("Huella de programacion")
struct HuellaDeProgramacionTests {

    private func alarma(
        hour: Int = 7,
        minute: Int = 30,
        weekdays: Set<Weekday> = [],
        challenge: ChallengeType = .pasos,
        toneID: String = Tone.defaultID,
        label: String = "",
        isEnabled: Bool = true
    ) -> Alarm {
        Alarm(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
            hour: hour, minute: minute, weekdays: weekdays, challenge: challenge,
            toneID: toneID, label: label, isEnabled: isEnabled
        )
    }

    @Test("La misma alarma da la misma huella")
    func estable() {
        #expect(alarma().huellaDeProgramacion == alarma().huellaDeProgramacion)
    }

    @Test("Cambia con todo lo que cambia lo que hace el sistema")
    func cambiaConLoQueImporta() {
        let base = alarma().huellaDeProgramacion
        #expect(alarma(hour: 8).huellaDeProgramacion != base)
        #expect(alarma(minute: 31).huellaDeProgramacion != base)
        #expect(alarma(weekdays: [.lunes]).huellaDeProgramacion != base)
        #expect(alarma(challenge: .sentadillas).huellaDeProgramacion != base)
        #expect(alarma(toneID: "otro").huellaDeProgramacion != base)
        #expect(alarma(label: "Gimnasio").huellaDeProgramacion != base)
    }

    @Test("No cambia con lo que no llega al sistema")
    func noCambiaConLoQueNoImporta() {
        let base = alarma().huellaDeProgramacion
        // Una alarma apagada no se programa: se cancela. Nunca llega a haber
        // huella de una apagada, asi que `isEnabled` no pinta nada aqui.
        #expect(alarma(isEnabled: false).huellaDeProgramacion == base)
        // Y la fecha de creacion solo ordena la lista.
        var otraFecha = alarma()
        otraFecha.creadaEn = Date(timeIntervalSince1970: 999_999)
        #expect(otraFecha.huellaDeProgramacion == base)
    }

    @Test("El orden en que se guardaron los dias no cuenta")
    func losDiasVanOrdenados() {
        #expect(
            alarma(weekdays: [.viernes, .lunes]).huellaDeProgramacion
                == alarma(weekdays: [.lunes, .viernes]).huellaDeProgramacion
        )
    }

    @Test("Una etiqueta con separadores no puede fingir ser otra alarma")
    func laEtiquetaNoSeCuela() {
        // La etiqueta es texto libre del usuario y va en la misma cadena que
        // todo lo demas. Sin la longitud delante, estas dos coincidian y editar
        // una alarma para dejarla asi no reprogramaba nada.
        #expect(
            alarma(label: "a|b").huellaDeProgramacion
                != alarma(toneID: "b", label: "a").huellaDeProgramacion
        )
        #expect(
            alarma(label: "7:30|").huellaDeProgramacion
                != alarma(label: "").huellaDeProgramacion
        )
    }

    @Test("Un salto de linea en la etiqueta tampoco rompe nada")
    func etiquetaConSaltos() {
        let conSalto = alarma(label: "arriba\nabajo").huellaDeProgramacion
        #expect(conSalto != alarma(label: "arriba abajo").huellaDeProgramacion)
    }
}

@Suite("Registro de huellas")
struct RegistroDeHuellasTests {

    private func registro() -> RegistroDeHuellas {
        RegistroDeHuellas(defaults: UserDefaults(suiteName: "reprise.tests.\(UUID())")!)
    }

    @Test("Lo guardado se recupera, y de una alarma que no esta no hay nada")
    func guardarYLeer() {
        let registro = registro()
        let id = UUID()
        #expect(registro.huella(de: id) == nil)
        registro.record("7:30||pasos|sistema|0|", for: id)
        #expect(registro.huella(de: id) == "7:30||pasos|sistema|0|")
        #expect(registro.huella(de: UUID()) == nil)
    }

    @Test("Olvidar una no se lleva las demas")
    func olvidar() {
        let registro = registro()
        let una = UUID(), otra = UUID()
        registro.record("A", for: una)
        registro.record("B", for: otra)

        registro.forget(alarmID: una)

        #expect(registro.huella(de: una) == nil)
        #expect(registro.huella(de: otra) == "B")
    }

    @Test("La limpieza tira las huellas de alarmas que ya no estan puestas")
    func limpieza() {
        let registro = registro()
        let viva = UUID(), muerta = UUID()
        registro.record("A", for: viva)
        registro.record("B", for: muerta)

        registro.prune(keeping: [viva])

        #expect(registro.huella(de: viva) == "A")
        #expect(registro.huella(de: muerta) == nil)
    }
}
