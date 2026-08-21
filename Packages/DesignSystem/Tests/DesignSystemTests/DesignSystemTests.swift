import Testing
import AlarmCore
@testable import DesignSystem

// En DesignSystem los tests solo se ponen donde aportan, que aqui son tres
// sitios: la tabla de la fuente de puntos, el resumen de dias y la geometria de
// la esfera (esa esta en EsferaDeRelojTests).
//
// La fuente es una tabla de cadenas escritas a mano. Una fila con un caracter
// de menos no rompe la compilacion: desplaza medio glifo y sale un digito
// torcido que solo se ve mirando la pantalla. Y el resumen de dias tiene los
// casos con nombre propio ("De lunes a viernes"), que es justo donde se cuela
// un error de conjuntos.

@Suite("Fuente de puntos")
struct FuenteDePuntosTests {

    @Test("Todos los glifos tienen 13 filas del mismo ancho", arguments: Array(FuenteDePuntos.glifos.keys))
    func rejillaIntacta(caracter: Character) {
        let glifo = FuenteDePuntos.glifos[caracter]!
        #expect(glifo.filas.count == FuenteDePuntos.filas,
                "El glifo '\(caracter)' tiene \(glifo.filas.count) filas")
        #expect(glifo.filas.allSatisfy { $0.count == glifo.ancho },
                "El glifo '\(caracter)' tiene filas de anchos distintos")
    }

    @Test("Los glifos solo llevan puntos encendidos o apagados")
    func sinCaracteresRaros() {
        for (caracter, glifo) in FuenteDePuntos.glifos {
            let sucias = glifo.filas.filter { !$0.allSatisfy { $0 == "#" || $0 == "." } }
            #expect(sucias.isEmpty, "El glifo '\(caracter)' tiene caracteres que no son # ni .")
        }
    }

    @Test("Las diez cifras estan y ninguna sale en blanco")
    func cifrasCompletas() {
        for cifra in "0123456789" {
            let glifo = FuenteDePuntos.glifos[cifra]
            #expect(glifo != nil, "Falta la cifra '\(cifra)'")
            #expect(!(glifo?.encendidas.isEmpty ?? true), "La cifra '\(cifra)' esta vacia")
        }
    }

    @Test("Componer suma los anchos y las separaciones")
    func anchoCompuesto() {
        let ancho0 = FuenteDePuntos.glifos["0"]!.ancho
        let ancho7 = FuenteDePuntos.glifos["7"]!.ancho
        let compuesto = FuenteDePuntos.componer("07")
        #expect(compuesto.columnas == ancho0 + FuenteDePuntos.separacionEntreGlifos + ancho7)
    }

    @Test("Un caracter desconocido no revienta ni pinta nada")
    func caracterDesconocido() {
        let compuesto = FuenteDePuntos.componer("Z")
        #expect(compuesto.encendidas.isEmpty)
    }

    @Test("Encendidas y apagadas cubren la rejilla entera, sin solaparse")
    func rejillaCompleta() {
        let compuesto = FuenteDePuntos.componer("15")
        let ancho1 = FuenteDePuntos.glifos["1"]!.ancho
        let ancho5 = FuenteDePuntos.glifos["5"]!.ancho
        let celdas = (ancho1 + ancho5) * FuenteDePuntos.filas
        #expect(compuesto.encendidas.count + compuesto.apagadas.count == celdas)
        #expect(Set(compuesto.encendidas).isDisjoint(with: Set(compuesto.apagadas)))
    }
}

@Suite("Resumen de dias")
struct ResumenDeDiasTests {

    @Test("Sin dias es una alarma de un solo uso")
    func vacio() {
        #expect(Set<Weekday>().resumen == "Una sola vez")
    }

    @Test("Los siete dias tienen nombre propio")
    func semanaEntera() {
        #expect(Set(Weekday.allCases).resumen == "Todos los días")
    }

    @Test("De lunes a viernes tiene nombre propio")
    func laborables() {
        let dias: Set<Weekday> = [.lunes, .martes, .miercoles, .jueves, .viernes]
        #expect(dias.resumen == "De lunes a viernes")
    }

    @Test("El fin de semana tiene nombre propio")
    func finDeSemana() {
        #expect(Set<Weekday>([.sabado, .domingo]).resumen == "Fines de semana")
    }

    @Test("El resto se lista por iniciales y en orden, con el lunes primero")
    func sueltos() {
        #expect(Set<Weekday>([.viernes, .lunes, .miercoles]).resumen == "L · X · V")
    }

    @Test("Miercoles es X, que la M ya es de martes")
    func inicialesSinChocar() {
        let iniciales = Weekday.allCases.map(\.inicial)
        #expect(iniciales == ["L", "M", "X", "J", "V", "S", "D"])
        #expect(Set(iniciales).count == iniciales.count)
    }
}

// MARK: - El calendario de la racha

@Suite("Calendario de la racha")
struct CalendarioDeLaRachaTests {

    private func registro(_ dia: Day, _ desenlace: DayOutcome = .completado) -> DayRecord {
        DayRecord(day: dia, alarmID: nil, challenge: .pasos, outcome: desenlace)
    }

    @Test("Con registros de dos meses solo se pintan los del mes que se ensena")
    func dosMesesNoChocan() {
        // Antes esto era un `Dictionary(uniqueKeysWithValues:)` sobre el numero
        // de dia suelto: el 3 de julio y el 3 de agosto compartian clave y la
        // app se caia en seco al entrar en la pantalla. Y le llegan dos meses en
        // cuanto se enchufa `records(from:to:)`, que devuelve un rango.
        let registros = [
            registro(Day(year: 2026, month: 7, day: 3), .fallado(.ignorada)),
            registro(Day(year: 2026, month: 8, day: 3)),
            registro(Day(year: 2026, month: 8, day: 4), .salvadoPorVida(.abandono))
        ]

        let porDia = desenlacesPorDia(registros, mes: Day(year: 2026, month: 8, day: 20))

        #expect(porDia.count == 2)
        #expect(porDia[3] == .completado, "el 3 de agosto, no el de julio")
        #expect(porDia[4] == .salvadoPorVida(.abandono))
    }

    @Test("El mismo dia del mismo mes repetido no revienta")
    func diaRepetido() {
        let dia = Day(year: 2026, month: 8, day: 3)
        let porDia = desenlacesPorDia(
            [registro(dia, .fallado(.abandono)), registro(dia)],
            mes: dia
        )
        #expect(porDia[3] == .completado, "gana el ultimo, y sobre todo no se cae")
    }

    @Test("Un mes de agosto se llama agosto, y uno de enero no")
    func elMesNoEstaEscritoAMano() {
        // Estaba clavado a "Agosto" y en septiembre seguia diciendo agosto.
        #expect(PantallaRacha.nombreDelMes(Day(year: 2026, month: 8, day: 20)).lowercased() == "agosto")
        #expect(PantallaRacha.nombreDelMes(Day(year: 2027, month: 1, day: 4)).lowercased() == "enero")
    }
}
