# Decisiones de producto

Cerradas con el usuario el 20/08/2026. Lo que no esta aqui, no se construye.

## Qué es

Un despertador que no se puede apagar sin levantarse de la cama.

## La alarma

- Suena con la app cerrada, rompiendo silencio y modos de concentracion. Esto
  obliga a **AlarmKit** y por tanto a **iOS 26 como minimo**.
- Varias alarmas configurables, con repeticion por dias de la semana.
- **No hay snooze.**
- Tonos: el sonido de alarma por defecto del sistema mas un catalogo propio en el
  bundle (maximo 30 s cada uno). iOS no da acceso a los tonos del usuario.

## El reto

- Dos retos: **20 pasos** o **10 sentadillas** con el movil en la mano. El
  usuario elige cual al crear la alarma.
- Dificultad **fija**. No se configura ni escala con la racha.
- Feedback durante el reto: **solo el contador en pantalla**.
- **La alarma no se calla hasta completar el reto entero.** Si se abandona a
  mitad, vuelve a sonar.

### El flujo real, con la limitacion de iOS

1. Suena la alarma en la interfaz de sistema de AlarmKit.
2. El usuario pulsa el boton secundario, que abre la app.
3. La app toma el control del sonido y arranca los sensores.
4. Completa el reto -> silencio y racha sumada.

El paso 2 es inevitable: con la app cerrada no se ejecuta nuestro codigo y no hay
sensores. El boton "Stop" del sistema tampoco se puede ocultar.

## Rachas

- Cuenta como dia conseguido: levantarse a la hora fijada y completar el reto.
- **2 vidas al mes**, no acumulables, repuestas al empezar cada mes.
- Una vida **congela** la racha: la mantiene, no la incrementa.
- Se pierde la racha por: pulsar Stop sin hacer el reto, abandonar a mitad, matar
  la app o reiniciar el movil durante el reto, o ignorar la alarma.
- Ademas de la racha: niveles e insignias.

## Ranking

- Mundial y por paises.
- Temporada mensual, con el record historico aparte. *(Asumido por Claude ante la
  falta de respuesta; pendiente de confirmacion del usuario.)*
- **Sin antifraude.** Decision explicita: cambiar la hora del movil para inflar la
  racha se queda sin castigo. Cita del usuario: "la app es para ayudar en la
  disciplina de levantarse temprano, si no lo hace es su problema".

## Cuentas

- La alarma funciona **sin registro**. La cuenta solo sirve para el ranking.
- Supabase Auth: Apple, Google y email. Sin Clerk.

## Monetizacion

Regla: se vende todo lo que rodea a la racha, nunca la racha misma.

**Gratis**: 1 alarma activa, los dos retos, racha, niveles, insignias basicas,
las 2 vidas del mes, ranking (tu posicion + top 100).

**Pro** (~3,99 EUR/mes o 24,99 EUR/ano): alarmas ilimitadas, catalogo completo de
tonos, estadisticas e historico completo, filtros de ranking por pais, insignias
y temas exclusivos, subir la dificultad del reto (nunca bajarla).

**No se venden vidas extra.** Convertiria el ranking en pay-to-win.

## Diseno

- Direccion: `docs/design/referencias/01-reloj-fisico-direccion-principal.png`.
  Reloj fisico blanco, neumorfico, digitos de matriz de puntos, base monocroma y
  un solo color de acento.
- Modo claro principal, modo oscuro obligatorio.
- Espanol unicamente.
- Descartadas las referencias 03 y 04 (oscuro/neon) por genericas.

## Descartado explicitamente

Territorios geograficos tipo bandas *(idea original del usuario, eliminada por
complejidad de deteccion y de solapamiento entre vecinos)*, flexiones, Apple
Watch, accesibilidad y retos alternativos, antifraude, notificaciones sociales,
contenido generado por usuarios, ingles, ligas de amigos.

## Ficha de App Store

Clasificacion 12+. Nombre provisional **RepRise** — ojo, existen ya *RiseReps:
Workout Alarm* (iOS) y *RiseRep Alarm* (Android), mismas palabras al reves y mismo
nicho.
