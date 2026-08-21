import SwiftUI
import AlarmCore

/// Las dos paginas de leer de la app: las reglas de la racha y las condiciones.
///
/// Hasta el 21/08/2026 las dos eran filas de Ajustes con su galon de "sigue por
/// aqui" y no seguian a ningun sitio. La de la racha hacia mas falta que
/// ninguna otra: **es la unica pantalla donde estan escritas las reglas por las
/// que se pierde**, y perder una racha de doscientos dias sin saber por que es
/// la peor cosa que puede hacer esta app.
///
/// Los textos no adornan: salen de `docs/decisiones-producto.md` y de lo que el
/// codigo hace de verdad hoy. Donde algo todavia no existe —la cuenta, el
/// cobro— se dice que no existe en vez de escribir la clausula que tendra el
/// dia que exista.

// MARK: - Andamiaje comun

/// Un apartado de texto: rotulo, y debajo el cuerpo dentro de un bloque.
private struct Apartado<Contenido: View>: View {
    let rotulo: String
    @ViewBuilder let contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: Espacio.medio) {
            Text(rotulo).estiloRotulo()
                .padding(.horizontal, Espacio.margen + Espacio.mini)
            VStack(alignment: .leading, spacing: Espacio.medio) {
                contenido
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Espacio.normal)
            .relieve(.bajo, radio: Radio.medio)
            .padding(.horizontal, Espacio.margen)
        }
    }
}

/// Una linea con su simbolo delante. Para listas de reglas, que se leen mucho
/// mejor asi que en un parrafo corrido.
private struct Regla: View {
    let icono: String
    let texto: String
    var acentuada = false

    var body: some View {
        HStack(alignment: .top, spacing: Espacio.medio) {
            Image(systemName: icono)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(acentuada ? Paleta.acento : Paleta.textoSuave)
                .frame(width: 22)
            Text(texto)
                .font(Tipografia.cuerpo)
                .foregroundStyle(Paleta.texto)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Parrafo: View {
    let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto)
            .font(Tipografia.cuerpo)
            .foregroundStyle(Paleta.textoSuave)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HojaDeTexto<Contenido: View>: View {
    let titulo: String
    let subtitulo: String?
    @ViewBuilder let contenido: Contenido

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Espacio.amplio) {
                Cabecera(titulo, subtitulo: subtitulo) {
                    Button { cerrar() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.redondo)
                        .accessibilityLabel(Text("Cerrar"))
                }
                contenido
            }
            .padding(.vertical, Espacio.amplio)
        }
        .fondoDePantalla()
    }
}

// MARK: - Como funciona la racha

/// Las reglas de la racha, enteras y sin letra pequena.
public struct PantallaComoFuncionaLaRacha: View {
    public init() {}

    public var body: some View {
        HojaDeTexto(titulo: "La racha", subtitulo: "cómo funciona") {
            Apartado(rotulo: "Un día cuenta cuando") {
                Regla(icono: "checkmark.circle.fill",
                      texto: "Suena tu alarma, abres la app desde el aviso y terminas el reto: \(ChallengeType.pasos.nombre) o \(ChallengeType.sentadillas.nombre).",
                      acentuada: true)
                Parrafo("No hay otra forma. La alarma no se calla hasta que el reto esté hecho, y el reto no se puede saltar.")
            }

            Apartado(rotulo: "La racha se rompe si") {
                Regla(icono: "xmark.circle", texto: "Ignoras la alarma y no la llegas a apagar.")
                Regla(icono: "xmark.circle", texto: "Pulsas el botón de parar del aviso del sistema sin hacer el reto.")
                Regla(icono: "xmark.circle", texto: "Dejas el reto a medias.")
                Regla(icono: "xmark.circle", texto: "Cierras la app o reinicias el móvil mientras lo haces.")
                Parrafo("Ese último es el que sorprende: mientras cuentas, la app está midiendo. Si desaparece a mitad, el día se da por fallado.")
            }

            Apartado(rotulo: "Las vidas") {
                Regla(icono: "heart.fill", texto: "Con Pro tienes 2 vidas cada mes.", acentuada: true)
                Regla(icono: "heart", texto: "Una vida congela la racha el día que fallas: la mantiene, no la sube.")
                Regla(icono: "calendar", texto: "No se acumulan: al empezar el mes vuelves a tener 2, ni más ni menos.")
                Parrafo("Con la versión gratis no hay vidas: el primer fallo rompe la racha.")
            }

            Apartado(rotulo: "Lo que no se compra") {
                Parrafo("Pagar da vidas para el mes en curso. No reconstruye una racha ya rota ni sube el contador: eso solo se gana levantándose.")
            }

            Apartado(rotulo: "La hora del móvil") {
                Parrafo("No comprobamos si la has cambiado. Puedes engañar a la racha en dos toques y no pasará nada. Esto es para ayudarte a levantarte temprano; si te engañas, el problema no es de la app.")
            }
        }
    }
}

// MARK: - Privacidad y condiciones

/// Lo que la app hace con tus datos, que hoy es casi nada, y en que condiciones
/// se usa.
///
/// Se escribe en presente y solo de lo que existe: no hay cuenta, no hay red y
/// no hay cobro. El dia que entren Supabase y StoreKit esta pantalla cambia.
public struct PantallaCondiciones: View {
    public init() {}

    public var body: some View {
        HojaDeTexto(titulo: "Privacidad", subtitulo: "y condiciones") {
            Apartado(rotulo: "Tus datos") {
                Regla(icono: "iphone", texto: "Todo se queda en el móvil: alarmas, racha, historial y ajustes.", acentuada: true)
                Regla(icono: "wifi.slash", texto: "La app no envía nada a ningún servidor. Hoy funciona entera sin conexión.")
                Regla(icono: "person.crop.circle.badge.xmark", texto: "No hay cuenta, no pedimos tu correo y no sabemos quién eres.")
                Regla(icono: "eye.slash", texto: "Sin analítica, sin publicidad y sin rastreadores de terceros.")
            }

            Apartado(rotulo: "El movimiento") {
                Parrafo("Para contar los pasos y las sentadillas la app lee los sensores del móvil, y solo mientras dura el reto. Esas medidas no se guardan ni salen del aparato: lo único que queda es si el día contó o no.")
                Parrafo("Si le quitas el permiso de movimiento, el reto no se puede medir y la alarma se deja apagar. Preferimos eso a dejarte encerrado con ella sonando.")
            }

            Apartado(rotulo: "El ranking") {
                Parrafo("Cuando exista de verdad hará falta una cuenta, y entonces sí saldrá de tu móvil el nombre que elijas y tu racha. Todavía no está: lo que se ve en la pantalla de ranking son datos de ejemplo.")
            }

            Apartado(rotulo: "La suscripción") {
                Parrafo("RepRise Pro todavía no se cobra. El cobro se hará por App Store, con las condiciones de Apple, y se podrá cancelar desde los ajustes del móvil. Mientras no exista, activarlo aquí no te cuesta nada.")
                Parrafo("Al dejar de pagar no se borra nada: las alarmas de más se apagan y la repetición por días deja de aplicarse, pero siguen guardadas. Volver a Pro lo devuelve todo tal cual.")
            }

            Apartado(rotulo: "Lo que no prometemos") {
                Parrafo("Un despertador puede fallar: el móvil se puede quedar sin batería, apagado o con un fallo del sistema. No respondemos de lo que te pierdas por no despertarte. Si el día importa de verdad, pon una segunda alarma.")
            }

            Apartado(rotulo: "Escribirnos") {
                Parrafo("Cualquier duda sobre esto, a \(PantallaAjustes.buzon).")
            }
        }
    }
}

#Preview("Cómo funciona la racha") {
    PantallaComoFuncionaLaRacha().preferredColorScheme(.dark)
}

#Preview("Privacidad y condiciones") {
    PantallaCondiciones().preferredColorScheme(.dark)
}
