import Testing
import CoreGraphics
import Foundation
@testable import DesignSystem

// La esfera se toca, y lo que se toca hay que probarlo. Aqui no se prueba como
// se ve —eso se mira— sino la aritmetica que traduce un dedo en una hora: que
// bolita coge el toque y en que numero cae. Es la parte que se rompe sola al
// cambiar un radio y que en pantalla se manifiesta como "a veces se mueve la
// otra", que es lo peor de reproducir a mano.

/// Un toque puesto en coordenadas polares, como se piensan las agujas: vueltas
/// desde las doce y en el sentido del reloj, y radio en fracciones del diametro.
private func toque(vueltas: Double, radio: Double, diametro: CGFloat = 200) -> CGPoint {
    let angulo = vueltas * 2 * .pi
    let centro = Double(diametro) / 2
    return CGPoint(x: centro + Double(diametro) * radio * sin(angulo),
                   y: centro - Double(diametro) * radio * cos(angulo))
}

@Suite("Esfera: donde apunta el dedo")
struct AnguloDeLaEsferaTests {

    @Test("Las doce estan arriba y la vuelta va con las agujas")
    func origenYSentido() {
        #expect(Esferica.vueltas(hasta: toque(vueltas: 0, radio: 0.4), diametro: 200)
                .isApproximately(0))
        #expect(Esferica.vueltas(hasta: toque(vueltas: 0.25, radio: 0.4), diametro: 200)
                .isApproximately(0.25))
        #expect(Esferica.vueltas(hasta: toque(vueltas: 0.5, radio: 0.4), diametro: 200)
                .isApproximately(0.5))
        #expect(Esferica.vueltas(hasta: toque(vueltas: 0.75, radio: 0.4), diametro: 200)
                .isApproximately(0.75))
    }

    @Test("El radio no depende de lo grande que salga la esfera")
    func radioRelativo() {
        for diametro: CGFloat in [82, 200, 230, 260] {
            let punto = toque(vueltas: 0.3, radio: 0.415, diametro: diametro)
            #expect(Esferica.radio(hasta: punto, diametro: diametro).isApproximately(0.415))
        }
    }

    @Test("Los minutos dan la vuelta por el 59 sin pasar por el 60")
    func minutosQueDanLaVuelta() {
        #expect(Esferica.minuto(en: 0) == 0)
        #expect(Esferica.minuto(en: 0.25) == 15)
        #expect(Esferica.minuto(en: 0.5) == 30)
        #expect(Esferica.minuto(en: 59.6 / 60) == 0)
        #expect(Esferica.minuto(en: 0.999) == 0)
    }
}

@Suite("Esfera: que bolita coge el dedo")
struct AgarreDeLaEsferaTests {

    @Test("En los digitos del centro no se coge nada")
    func zonaMuerta() {
        for vueltas in stride(from: 0.0, to: 1.0, by: 0.1) {
            let punto = toque(vueltas: vueltas, radio: 0.2)
            #expect(Esferica.manecilla(paraToque: punto, diametro: 200, hora: 7, minuto: 5) == nil)
        }
        let centro = CGPoint(x: 100, y: 100)
        #expect(Esferica.manecilla(paraToque: centro, diametro: 200, hora: 7, minuto: 5) == nil)
    }

    @Test("El anillo de dentro es la hora y el de fuera los minutos")
    func anillos() {
        // Lejos de las dos bolitas, que estan a las 7 y en el 5: manda el anillo.
        let dentro = toque(vueltas: 0.5, radio: 0.30)
        let fuera = toque(vueltas: 0.5, radio: 0.45)
        #expect(Esferica.manecilla(paraToque: dentro, diametro: 200, hora: 7, minuto: 5) == .hora)
        #expect(Esferica.manecilla(paraToque: fuera, diametro: 200, hora: 7, minuto: 5) == .minuto)
    }

    @Test("Apuntar a una bolita la coge aunque el dedo caiga en el otro anillo")
    func cercaniaPorEncimaDelAnillo() {
        // La hora esta en el 3 y el minuto en el 0. El dedo cae justo fuera de
        // la frontera, pero encima de la bolita de la hora.
        let punto = toque(vueltas: 0.25, radio: 0.38)
        #expect(Esferica.manecilla(paraToque: punto, diametro: 200, hora: 3, minuto: 0) == .hora)
    }

    // Las horas en punto y las y media ponen las dos bolitas en el mismo angulo.
    // Es el caso que hay que dejar clavado: con las dos superpuestas, el radio
    // sigue decidiendo y no hay forma de coger una creyendo coger la otra.
    @Test("Con las dos bolitas en el mismo angulo manda el radio",
          arguments: [(12, 0, 0.0), (6, 30, 0.5), (0, 0, 0.0), (3, 15, 0.25)])
    func bolitasJuntas(hora: Int, minuto: Int, vueltas: Double) {
        let enLaHora = toque(vueltas: vueltas, radio: 0.315)
        let enElMinuto = toque(vueltas: vueltas, radio: 0.415)
        #expect(Esferica.manecilla(paraToque: enLaHora, diametro: 200,
                                   hora: hora, minuto: minuto) == .hora)
        #expect(Esferica.manecilla(paraToque: enElMinuto, diametro: 200,
                                   hora: hora, minuto: minuto) == .minuto)

        // Justo en el punto medio empatan: se lo queda la hora, que es la de
        // dentro. Da igual cual de las dos sea mientras no cambie de un toque a
        // otro, y esto lo deja fijado.
        let enMedio = toque(vueltas: vueltas, radio: Esferica.frontera)
        #expect(Esferica.manecilla(paraToque: enMedio, diametro: 200,
                                   hora: hora, minuto: minuto) == .hora)
    }

    @Test("Tocar el borde mueve los minutos aunque las dos bolitas esten enfrente")
    func bordeLejosDeTodo() {
        // 12:00: las dos arriba. El dedo toca abajo del todo.
        let abajo = toque(vueltas: 0.5, radio: 0.48)
        #expect(Esferica.manecilla(paraToque: abajo, diametro: 200, hora: 12, minuto: 0) == .minuto)
    }
}

@Suite("Esfera: las veinticuatro horas en doce numeros")
struct HoraDeLaEsferaTests {

    @Test("El primer toque no cambia de mitad del dia")
    func elSaltoNoCambiaLaMitad() {
        // Estando a las 11 de la manana, tocar el 1 pone la 1 de la manana.
        #expect(Esferica.hora(en: 1.0 / 12, desde: 11, posicionPrevia: nil) == 1)
        // Y estando a las 23, la 1 de la tarde: la mitad se conserva.
        #expect(Esferica.hora(en: 1.0 / 12, desde: 23, posicionPrevia: nil) == 13)
    }

    @Test("Pasar por las doce hacia adelante cambia de mitad")
    func vueltaHaciaAdelante() {
        #expect(Esferica.hora(en: 0, desde: 11, posicionPrevia: 11) == 12)
        #expect(Esferica.hora(en: 0, desde: 23, posicionPrevia: 11) == 0)
    }

    @Test("Pasar por las doce hacia atras tambien")
    func vueltaHaciaAtras() {
        #expect(Esferica.hora(en: 11.0 / 12, desde: 12, posicionPrevia: 0) == 11)
        #expect(Esferica.hora(en: 11.0 / 12, desde: 0, posicionPrevia: 0) == 23)
    }

    @Test("Dos vueltas seguidas recorren el dia entero, hora por hora")
    func elDiaEnteroArrastrando() {
        var hora = 0
        var previa: Int? = nil
        var recorrido: [Int] = []
        for paso in 1...24 {
            hora = Esferica.hora(en: Double(paso % 12) / 12, desde: hora, posicionPrevia: previa)
            previa = resto(hora, entre: 12)
            recorrido.append(hora)
        }
        #expect(recorrido == Array(1...23) + [0])
    }

    @Test("Y al reves, hacia atras, pasa por las veinticuatro sin negativos")
    func elDiaEnteroDelReves() {
        // Arrancando de las 00:00 y tirando hacia atras: 23, 22... El primer
        // paso no cambia de mitad, asi que la ronda empieza en las 11 de la
        // manana; lo que importa es que las veinticuatro salgan una vez y solo
        // una, y que ninguna se vaya de rango.
        var hora = 0
        var previa: Int? = nil
        var recorrido: [Int] = []
        for paso in 1...24 {
            hora = Esferica.hora(en: Double((24 - paso) % 12) / 12, desde: hora, posicionPrevia: previa)
            previa = resto(hora, entre: 12)
            recorrido.append(hora)
        }
        #expect(recorrido.allSatisfy { (0...23).contains($0) })
        #expect(Set(recorrido).count == 24)
        #expect(recorrido.first == 11)
    }

    @Test("El resto nunca sale negativo")
    func restoSiempreEnRango() {
        #expect(resto(-1, entre: 24) == 23)
        #expect(resto(-1, entre: 60) == 59)
        #expect(resto(24, entre: 24) == 0)
        #expect(resto(13, entre: 12) == 1)
    }
}

private extension Double {
    func isApproximately(_ otro: Double, tolerancia: Double = 1e-9) -> Bool {
        abs(self - otro) < tolerancia
    }
}
