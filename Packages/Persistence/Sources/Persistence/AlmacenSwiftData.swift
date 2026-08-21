import Foundation
import SwiftData
import AlarmCore

/// El almacen de verdad, sobre SwiftData.
///
/// Implementa los cuatro repositorios de `Contracts.swift` y ademas
/// `AlmacenDeRachas`, que es el que exige escribir el dia de una pieza.
///
/// Es un actor (`@ModelActor`) porque `ModelContext` no se puede compartir entre
/// hilos. Todo el acceso a disco de la app pasa por aqui y queda serializado.
@ModelActor
public actor AlmacenSwiftData {

    /// Ejecuta `cuerpo` y baja a disco **una sola vez**, al final.
    ///
    /// Aqui esta la atomicidad que pide `AlmacenDeRachas`: los cambios se van
    /// acumulando en el contexto sin tocar el fichero, y el unico `save()` los
    /// escribe todos juntos. Si algo revienta a mitad, `rollback()` tira lo
    /// acumulado y el disco se queda exactamente como estaba.
    ///
    /// Sin esto, guardar el estado y el registro serian dos escrituras: caerse
    /// entre las dos deja la racha contando un dia que no esta en el historial,
    /// o al reves. Las dos formas corrompen la racha y ninguna se puede deshacer.
    func enTransaccion<T>(_ cuerpo: () throws -> T) throws -> T {
        do {
            let salida = try cuerpo()
            try modelContext.save()
            return salida
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Solo para pruebas: escribe algo y revienta dentro de la misma
    /// transaccion, para poder comprobar contra SwiftData de verdad que el
    /// `rollback` deja el disco como estaba. No hay forma de provocar un fallo
    /// de `save()` desde fuera, y la garantia es demasiado importante para
    /// darla por buena solo leyendo el codigo.
    func ensayoDeTransaccionQueFalla(_ alarma: Alarm, error: any Error) throws {
        try enTransaccion {
            modelContext.insert(EsquemaV1.AlarmaGuardada(alarma))
            throw error
        }
    }

    // MARK: - Filas

    private func filaDeAlarma(id: UUID) throws -> EsquemaV1.AlarmaGuardada? {
        var descriptor = FetchDescriptor<EsquemaV1.AlarmaGuardada>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func filaDeEstado() throws -> EsquemaV1.EstadoRachaGuardado? {
        var descriptor = FetchDescriptor<EsquemaV1.EstadoRachaGuardado>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func filaDeRegistro(dia: Int) throws -> EsquemaV1.RegistroDiaGuardado? {
        var descriptor = FetchDescriptor<EsquemaV1.RegistroDiaGuardado>(predicate: #Predicate { $0.diaOrdinal == dia })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func filaDePendiente() throws -> EsquemaV1.RetoPendienteGuardado? {
        var descriptor = FetchDescriptor<EsquemaV1.RetoPendienteGuardado>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Escrituras sueltas
    //
    // Ninguna guarda por su cuenta: se llaman desde dentro de `enTransaccion`,
    // que es quien decide cuando se baja a disco. Si alguna hiciera `save()`
    // aqui dentro, la escritura del dia dejaria de ser atomica.

    private func escribirEstado(_ estado: StreakState) throws {
        if let fila = try filaDeEstado() {
            fila.actualizar(desde: estado)
        } else {
            modelContext.insert(EsquemaV1.EstadoRachaGuardado(estado))
        }
    }

    private func escribirRegistro(_ registro: DayRecord) throws {
        if let fila = try filaDeRegistro(dia: registro.day.ordinal) {
            fila.actualizar(desde: registro)
        } else {
            modelContext.insert(EsquemaV1.RegistroDiaGuardado(registro))
        }
    }

    private func borrarPendiente() throws {
        if let fila = try filaDePendiente() {
            modelContext.delete(fila)
        }
    }
}

// MARK: - Alarmas

extension AlmacenSwiftData: AlarmRepository {

    public func all() throws -> [Alarm] {
        let descriptor = FetchDescriptor<EsquemaV1.AlarmaGuardada>(
            sortBy: [SortDescriptor(\.hora), SortDescriptor(\.minuto)]
        )
        return try modelContext.fetch(descriptor).map(\.aDominio)
    }

    public func save(_ alarm: Alarm) throws {
        try enTransaccion {
            if let fila = try filaDeAlarma(id: alarm.id) {
                fila.actualizar(desde: alarm)
            } else {
                modelContext.insert(EsquemaV1.AlarmaGuardada(alarm))
            }
        }
    }

    public func delete(id: Alarm.ID) throws {
        try enTransaccion {
            if let fila = try filaDeAlarma(id: id) {
                modelContext.delete(fila)
            }
        }
    }
}

// MARK: - Estado de la racha

extension AlmacenSwiftData: StreakRepository {

    /// Sin fila guardada, el estado es el de un usuario nuevo. Ese `nil` en el
    /// mes de reposicion es correcto aqui: significa "todavia no se le han
    /// repuesto las vidas nunca", y se las repone el primer dia que resuelva.
    public func load() throws -> StreakState {
        try filaDeEstado()?.aDominio ?? StreakState()
    }

    public func save(_ state: StreakState) throws {
        try enTransaccion { try escribirEstado(state) }
    }
}

// MARK: - Registro diario

extension AlmacenSwiftData: DayRecordRepository {

    public func records(from: Day, to: Day) throws -> [DayRecord] {
        let desde = from.ordinal
        let hasta = to.ordinal
        let descriptor = FetchDescriptor<EsquemaV1.RegistroDiaGuardado>(
            predicate: #Predicate { $0.diaOrdinal >= desde && $0.diaOrdinal <= hasta },
            sortBy: [SortDescriptor(\.diaOrdinal)]
        )
        return try modelContext.fetch(descriptor).compactMap(\.aDominio)
    }

    public func save(_ record: DayRecord) throws {
        try enTransaccion { try escribirRegistro(record) }
    }
}

// MARK: - Rastro del reto empezado

extension AlmacenSwiftData: PendingChallengeRepository {

    public func current() throws -> PendingChallenge? {
        try filaDePendiente()?.aDominio
    }

    /// Deja el rastro en disco. Se llama **antes** de arrancar el reto, y solo
    /// vale si cuando vuelve ya esta escrito: el caso que cubre es que maten la
    /// app en el segundo siguiente.
    ///
    /// - Important: al arrancar la app hay que llamar antes a
    ///   `ResolutorDeDia.resolverRetoHuerfano()`. Solo puede haber un rastro, asi
    ///   que empezar un reto nuevo pisa el que hubiera; si quedaba uno sin
    ///   resolver de la sesion anterior, pisarlo es perdonar el dia que habia que
    ///   penalizar. No se lanza error aqui a proposito: dejar de arrancar el reto
    ///   significa que la alarma no se puede callar, y eso es peor.
    public func begin(_ pending: PendingChallenge) throws {
        try enTransaccion {
            if let fila = try filaDePendiente() {
                fila.actualizar(desde: pending)
            } else {
                modelContext.insert(EsquemaV1.RetoPendienteGuardado(pending))
            }
        }
    }

    public func clear() throws {
        try enTransaccion { try borrarPendiente() }
    }
}

// MARK: - El dia entero, de una pieza

extension AlmacenSwiftData: AlmacenDeRachas {

    public func rachaActual() throws -> StreakState { try load() }

    public func retoPendiente() throws -> PendingChallenge? { try current() }

    /// Estado, registro y cierre del rastro, en un unico `save()`.
    ///
    /// Con `registro` a `nil` el dia ya estaba contado: se guarda el estado (que
    /// no ha cambiado) y se cierra el rastro, pero **no se toca el historial**.
    /// Escribir ahi lo que trae un dia ya resuelto pisaria lo guardado, y el
    /// caso real —dos alarmas el mismo dia, la primera hecha y la segunda con la
    /// app muerta a mitad— acababa pintando un fallo en un dia completado.
    public func confirmarDia(estado: StreakState, registro: DayRecord?) throws {
        try enTransaccion {
            try escribirEstado(estado)
            if let registro { try escribirRegistro(registro) }
            try borrarPendiente()
        }
    }
}
