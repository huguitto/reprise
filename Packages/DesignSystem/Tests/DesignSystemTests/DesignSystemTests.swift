import Testing
import AlarmCore
@testable import DesignSystem

// En DesignSystem los tests solo se ponen donde aportan, que aqui son dos
// sitios: la tabla de la fuente de puntos y el resumen de dias.
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
