import SwiftUI

/// TAREA DEL AGENTE D.
///
/// Sistema de diseno de RepRise, a partir de
/// `docs/design/referencias/01-reloj-fisico-direccion-principal.png`:
/// reloj fisico blanco, superficies neumorficas, digitos de matriz de puntos,
/// base monocroma y UN SOLO color de acento.
///
/// Dos reglas que van por encima de la estetica:
///
/// 1. La pantalla del reto se usa a las 6 de la manana, a oscuras y con los ojos
///    a medio abrir. Ahi el contraste manda sobre la sutileza: contador enorme,
///    legible de un vistazo, sin grises sobre grises.
/// 2. Modo claro es el principal, el oscuro tiene que existir y no ser un
///    afterthought — es literalmente cuando se usa la app.
public enum DesignSystem {
    public static let acento = Color.orange
}
