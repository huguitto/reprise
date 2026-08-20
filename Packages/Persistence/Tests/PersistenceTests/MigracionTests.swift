import Testing
import Foundation
import SwiftData
import AlarmCore
@testable import Persistence

@Suite("Migraciones")
struct MigracionTests {

    @Test("El esquema en disco es la version 1")
    func versionDeclarada() {
        #expect(Persistence.version == Schema.Version(1, 0, 0))
    }

    @Test("El plan conoce todas las versiones que puede haber instaladas")
    func elPlanNoOlvidaVersiones() {
        let versiones = PlanDeMigracion.schemas.map { $0.versionIdentifier }
        #expect(versiones.contains(EsquemaV1.versionIdentifier),
                "quitar una version del plan deja sin migrar a quien la tenga instalada")
        #expect(versiones.count == PlanDeMigracion.stages.count + 1,
                "cada salto entre dos versiones necesita su etapa: si no cuadra, hay un salto sin migracion")
    }

    @Test("El esquema declara los cuatro modelos")
    func modelosDeclarados() {
        #expect(EsquemaV1.models.count == 4, "un modelo fuera del esquema es una tabla que no se migra")
    }

    // MARK: - La trampa de las vidas

    @Test("Un mes de reposicion perdido se repara con el ultimo dia contado")
    func reparaConElUltimoDiaContado() throws {
        let contexto = try contextoDePrueba()
        contexto.insert(EsquemaV1.EstadoRachaGuardado(
            rachaActual: 40, mejorRacha: 40, diasCompletadosTotales: 40, vidasRestantes: 0,
            mesDeReposicionDeVidas: nil, ultimoDiaContado: dia(19).ordinal
        ))

        let reparados = try PlanDeMigracion.reparaMesDeReposicionDeVidas(contexto)

        #expect(reparados == 1)
        #expect(try estado(en: contexto)?.mesDeReposicionDeVidas == dia(19).yearMonth)
    }

    @Test("Si tambien se perdio el ultimo dia, se repara con el registro mas reciente")
    func reparaConElHistorial() throws {
        let contexto = try contextoDePrueba()
        contexto.insert(EsquemaV1.EstadoRachaGuardado(
            rachaActual: 40, mejorRacha: 40, diasCompletadosTotales: 40, vidasRestantes: 0,
            mesDeReposicionDeVidas: nil, ultimoDiaContado: nil
        ))
        for d in [dia(1, mes: 6), dia(19), dia(3, mes: 7)] {
            contexto.insert(EsquemaV1.RegistroDiaGuardado(
                diaOrdinal: d.ordinal, alarmID: nil, reto: nil, resultado: "completado",
                motivoFallo: nil, duracion: nil
            ))
        }

        try PlanDeMigracion.reparaMesDeReposicionDeVidas(contexto)

        #expect(try estado(en: contexto)?.mesDeReposicionDeVidas == dia(19).yearMonth,
                "el mas reciente es el de agosto, no el ultimo insertado")
    }

    @Test("A un usuario nuevo de verdad no se le inventa un mes")
    func usuarioNuevoSeQuedaEnNil() throws {
        let contexto = try contextoDePrueba()
        contexto.insert(EsquemaV1.EstadoRachaGuardado(
            rachaActual: 0, mejorRacha: 0, diasCompletadosTotales: 0, vidasRestantes: 2,
            mesDeReposicionDeVidas: nil, ultimoDiaContado: nil
        ))

        let reparados = try PlanDeMigracion.reparaMesDeReposicionDeVidas(contexto)

        #expect(reparados == 0)
        #expect(try estado(en: contexto)?.mesDeReposicionDeVidas == nil,
                "aqui el nil es correcto: nunca se le han repuesto las vidas")
    }

    @Test("La reparacion no pisa un mes que ya estaba bien")
    func noPisaLoQueYaEstaba() throws {
        let contexto = try contextoDePrueba()
        contexto.insert(EsquemaV1.EstadoRachaGuardado(
            rachaActual: 40, mejorRacha: 40, diasCompletadosTotales: 40, vidasRestantes: 1,
            mesDeReposicionDeVidas: dia(1, mes: 3).yearMonth, ultimoDiaContado: dia(19).ordinal
        ))

        let reparados = try PlanDeMigracion.reparaMesDeReposicionDeVidas(contexto)

        #expect(reparados == 0)
        #expect(try estado(en: contexto)?.mesDeReposicionDeVidas == dia(1, mes: 3).yearMonth)
    }

    // MARK: - La misma trampa, en la escritura del dia a dia

    @Test("Guardar no puede borrar el mes de reposicion ya fijado")
    func guardarNoBorraElMes() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        try await almacen.save(StreakState(current: 40, best: 40, livesRemaining: 0,
                                           livesRefilledYearMonth: dia(1).yearMonth,
                                           lastCountedDay: dia(19), diasCompletadosTotales: 40))

        // Un estado con el mes a nil llegando por error a la escritura. Si el
        // nil se escribiera, al siguiente arranque se le reponen las vidas.
        try await almacen.save(StreakState(current: 40, best: 40, livesRemaining: 0,
                                           livesRefilledYearMonth: nil,
                                           lastCountedDay: dia(19), diasCompletadosTotales: 40))

        #expect(try await almacen.load().livesRefilledYearMonth == dia(1).yearMonth)
    }

    @Test("Un usuario existente no recupera vidas al abrir la app dentro del mismo mes")
    func noSeReponenVidasDeBalde() async throws {
        let temporal = AlmacenTemporal()
        let alarmID = UUID()

        // Ya gasto sus dos vidas de agosto.
        do {
            let almacen = try temporal.abrir()
            try await almacen.save(StreakState(current: 40, best: 40, livesRemaining: 0,
                                               livesRefilledYearMonth: dia(1).yearMonth,
                                               lastCountedDay: dia(19), diasCompletadosTotales: 40))
        }

        // Cierra la app, la abre y resuelve otro dia de agosto.
        let segundoArranque = try temporal.abrir()
        let resolutor = ResolutorDeDia(almacen: segundoArranque, plan: { .pro })
        let r = try await resolutor.resolver(.fallado(.ignorada), dia: dia(20), alarmID: alarmID, challenge: .pasos)

        #expect(r.estado.livesRemaining == 0, "agosto ya estaba repuesto: no toca otra vez")
        #expect(r.registro.outcome == .fallado(.ignorada), "y sin vida, el fallo duele")
        #expect(r.estado.current == 0)
    }

    @Test("Al cambiar de mes si se reponen las vidas, una sola vez")
    func alMesSiguienteSeReponen() async throws {
        let almacen = try Persistence.almacen(enMemoria: true)
        try await almacen.save(StreakState(current: 40, best: 40, livesRemaining: 0,
                                           livesRefilledYearMonth: dia(1).yearMonth,
                                           lastCountedDay: dia(31), diasCompletadosTotales: 40))
        let resolutor = ResolutorDeDia(almacen: almacen, plan: { .pro })

        let septiembre = try await resolutor.resolver(.fallado(.abandono), dia: dia(1, mes: 9),
                                                      alarmID: nil, challenge: .pasos)
        #expect(septiembre.estado.livesRemaining == 1, "repuestas a 2 y gastada una")
        #expect(septiembre.registro.outcome == .salvadoPorVida(.abandono))

        let mismoMes = try await resolutor.resolver(.fallado(.abandono), dia: dia(2, mes: 9),
                                                    alarmID: nil, challenge: .pasos)
        #expect(mismoMes.estado.livesRemaining == 0, "no se reponen dos veces en el mismo mes")
    }

    // MARK: - Ayudas

    private func contextoDePrueba() throws -> ModelContext {
        ModelContext(try Persistence.contenedor(enMemoria: true))
    }

    private func estado(en contexto: ModelContext) throws -> EsquemaV1.EstadoRachaGuardado? {
        try contexto.fetch(FetchDescriptor<EsquemaV1.EstadoRachaGuardado>()).first
    }
}

@Suite("Dias en disco")
struct DiaOrdinalTests {

    @Test("Un dia guardado como ordinal se lee igual")
    func idaYVuelta() {
        for d in [dia(1, mes: 1, ano: 2026), dia(31, mes: 12, ano: 2026), dia(29, mes: 2, ano: 2028), dia(9, mes: 9)] {
            #expect(Day(ordinal: d.ordinal) == d)
        }
    }

    @Test("El orden de los ordinales es el orden de los dias")
    func elOrdenSeConserva() {
        // De esto depende que el rango de `records(from:to:)` sea un rango de
        // enteros. Si el orden no coincidiera, el historial saldria descuadrado.
        let dias = [dia(31, mes: 12, ano: 2025), dia(1, mes: 1, ano: 2026),
                    dia(9, mes: 2), dia(10, mes: 2), dia(1, mes: 3)]
        for (a, b) in zip(dias, dias.dropFirst()) {
            #expect(a < b)
            #expect(a.ordinal < b.ordinal)
        }
    }
}
