import SwiftUI

/// Fachada del sistema de diseno de RepRise.
///
/// Sale de `docs/design/referencias/01-reloj-fisico-direccion-principal.png`:
/// reloj fisico blanco, superficies neumorficas, digitos de matriz de puntos,
/// base monocroma y UN SOLO color de acento. La referencia 02 aporta el uso
/// editorial de la tipografia y el numero gigante como protagonista. Las
/// referencias 03 y 04 estan descartadas y no se mezclan.
///
/// Por donde se entra:
///
/// - `Paleta`, `Tipografia`, `Espacio`, `Radio`, `Relieve` y `Hundido` son los
///   tokens. Nada de la app deberia escribir un color, un tamano ni una sombra
///   a pelo.
/// - `.relieve(...)` y `.hueco(...)` son las dos unicas formas de dar volumen.
///   La luz viene siempre de arriba a la izquierda.
/// - `TextoDeMatriz`, `EsferaDeReloj`, `DialDeApagado` y `AnilloDeProgreso` son
///   las piezas con caracter propio.
/// - `GaleriaDeDiseno` ensena todo lo anterior y las pantallas estaticas.
///
/// Dos reglas que van por encima de la estetica:
///
/// 1. `PantallaReto` se mira a las seis de la manana, a oscuras y con los ojos
///    a medio abrir. Ahi manda el contraste: usa `Paleta.retoFondo` y
///    `Paleta.retoTinta`, no `fondo` ni `texto`, y no lleva neumorfismo.
/// 2. El modo claro es el principal, pero el oscuro no es un anadido: es
///    literalmente cuando se usa la app. Todo tiene su pareja y toda vista
///    tiene `#Preview` en claro y en oscuro.
public enum DesignSystem {
    /// El unico color de acento de la app.
    public static let acento = Paleta.acento
}
