import Foundation

/// Los digitos de matriz de puntos de la referencia.
///
/// No es la matriz gorda de un despertador de los ochenta: los trazos son de
/// **un punto de ancho**, asi que las cifras salen huecas y con las esquinas
/// cortadas en diagonal. Es lo que hace que la esfera parezca grabada en vez
/// de impresa. El cero lleva barra, como en la referencia.
///
/// Rejilla de 13 filas. El ancho lo pone cada glifo.
struct Glifo: Sendable {
    let filas: [String]

    var ancho: Int { filas.first?.count ?? 0 }

    /// Celdas encendidas, en (columna, fila).
    var encendidas: [Punto] {
        filas.enumerated().flatMap { fila, patron in
            patron.enumerated().compactMap { columna, caracter in
                caracter == "#" ? Punto(columna: columna, fila: fila) : nil
            }
        }
    }
}

struct Punto: Hashable, Sendable {
    let columna: Int
    let fila: Int
}

enum FuenteDePuntos {
    /// Filas de la rejilla. Todos los glifos miden lo mismo de alto.
    static let filas = 13
    /// Separacion entre glifos, en columnas.
    static let separacionEntreGlifos = 2

    static let glifos: [Character: Glifo] = [
        "0": Glifo(filas: [
            "..#####..",
            ".#.....#.",
            "#.......#",
            "#......##",
            "#.....#.#",
            "#....#..#",
            "#...#...#",
            "#..#....#",
            "#.#.....#",
            "##......#",
            "#.......#",
            ".#.....#.",
            "..#####.."
        ]),
        "1": Glifo(filas: [
            "....#....",
            "..#.#....",
            "....#....",
            "....#....",
            "....#....",
            "....#....",
            "....#....",
            "....#....",
            "....#....",
            "....#....",
            "....#....",
            "....#....",
            ".#######."
        ]),
        "2": Glifo(filas: [
            "..#####..",
            ".#.....#.",
            "#.......#",
            "#.......#",
            "........#",
            ".......#.",
            "......#..",
            ".....#...",
            "....#....",
            "...#.....",
            "..#......",
            ".#.......",
            "#########"
        ]),
        "3": Glifo(filas: [
            "..#####..",
            ".#.....#.",
            "#.......#",
            "........#",
            ".......#.",
            "...#####.",
            ".......#.",
            "........#",
            "#.......#",
            "#.......#",
            "#.......#",
            ".#.....#.",
            "..#####.."
        ]),
        "4": Glifo(filas: [
            "......##.",
            ".....#.#.",
            "....#..#.",
            "...#...#.",
            "..#....#.",
            ".#.....#.",
            "#......#.",
            "#########",
            ".......#.",
            ".......#.",
            ".......#.",
            ".......#.",
            ".......#."
        ]),
        "5": Glifo(filas: [
            "#########",
            "#........",
            "#........",
            "#........",
            "#........",
            "#.######.",
            "##.....#.",
            "........#",
            "........#",
            "#.......#",
            "#.......#",
            ".#.....#.",
            "..#####.."
        ]),
        "6": Glifo(filas: [
            "....###..",
            "..##...#.",
            ".#.......",
            "#........",
            "#........",
            "#.######.",
            "##.....#.",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            ".#.....#.",
            "..#####.."
        ]),
        "7": Glifo(filas: [
            "#########",
            "#......#.",
            "......#..",
            ".....#...",
            "....#....",
            "...#.....",
            "..#......",
            "..#......",
            "..#......",
            "..#......",
            "..#......",
            "..#......",
            "..#......"
        ]),
        "8": Glifo(filas: [
            "..#####..",
            ".#.....#.",
            "#.......#",
            "#.......#",
            ".#.....#.",
            "..#####..",
            ".#.....#.",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            ".#.....#.",
            "..#####.."
        ]),
        "9": Glifo(filas: [
            "..#####..",
            ".#.....#.",
            "#.......#",
            "#.......#",
            "#.......#",
            ".#.....#.",
            "..#####.#",
            "........#",
            "........#",
            "#.......#",
            "#.......#",
            ".#.....#.",
            "..#####.."
        ]),
        ":": Glifo(filas: [
            "...",
            "...",
            "...",
            ".#.",
            ".#.",
            "...",
            "...",
            "...",
            ".#.",
            ".#.",
            "...",
            "...",
            "..."
        ]),
        "/": Glifo(filas: [
            ".......#.",
            ".......#.",
            "......#..",
            "......#..",
            ".....#...",
            ".....#...",
            "....#....",
            "...#.....",
            "...#.....",
            "..#......",
            "..#......",
            ".#.......",
            ".#......."
        ]),
        "-": Glifo(filas: [
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            ".#######.",
            ".........",
            ".........",
            ".........",
            ".........",
            ".........",
            "........."
        ]),
        ".": Glifo(filas: [
            "...", "...", "...", "...", "...", "...", "...",
            "...", "...", "...", "...", "...", ".#."
        ]),
        " ": Glifo(filas: [
            ".....", ".....", ".....", ".....", ".....", ".....", ".....",
            ".....", ".....", ".....", ".....", ".....", "....."
        ])
    ]

    /// Traduce un texto a celdas de la rejilla.
    ///
    /// Devuelve tambien las apagadas porque la pantalla del reto las dibuja:
    /// ver el hueco de lo que falta ayuda a leer la cifra de un vistazo.
    static func componer(_ texto: String) -> (columnas: Int, encendidas: [Punto], apagadas: [Punto]) {
        var columna = 0
        var encendidas: [Punto] = []
        var apagadas: [Punto] = []

        for caracter in texto {
            let glifo = glifos[caracter] ?? glifos[" "]!
            let deEsteGlifo = Set(glifo.encendidas)
            for punto in deEsteGlifo {
                encendidas.append(Punto(columna: punto.columna + columna, fila: punto.fila))
            }
            for fila in 0..<filas {
                for c in 0..<glifo.ancho where !deEsteGlifo.contains(Punto(columna: c, fila: fila)) {
                    apagadas.append(Punto(columna: c + columna, fila: fila))
                }
            }
            columna += glifo.ancho + separacionEntreGlifos
        }

        return (max(0, columna - separacionEntreGlifos), encendidas, apagadas)
    }
}
