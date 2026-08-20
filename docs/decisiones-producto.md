# Decisiones de producto

Cerradas con el usuario el 20/08/2026. Lo que no esta aqui, no se construye.

Revisadas el 21/08/2026: cambia el reparto entre gratis y Pro. Ver
[Monetizacion](#monetizacion).

## Qué es

Un despertador que no se puede apagar sin levantarse de la cama.

## La alarma

- Suena con la app cerrada, rompiendo silencio y modos de concentracion. Esto
  obliga a **AlarmKit** y por tanto a **iOS 26 como minimo**.
- Varias alarmas configurables, con repeticion por dias de la semana. **Las dos
  cosas son de Pro**: en gratis hay una sola alarma activa y sin repeticion, es
  decir, de un solo uso.
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
- **2 vidas al mes con Pro**, no acumulables, repuestas al empezar cada mes.
  **El plan gratis no tiene vidas**: el primer fallo rompe la racha.
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

**Gratis**: 1 alarma activa y de un solo uso (sin dias de la semana), los dos
retos, racha, niveles, insignias basicas, ranking (tu posicion + top 100). **Sin
vidas**: el primer fallo rompe la racha.

**Pro** (~3,99 EUR/mes o 24,99 EUR/ano): alarmas ilimitadas, repeticion por dias
de la semana, las 2 vidas del mes, catalogo completo de tonos, estadisticas e
historico completo, filtros de ranking por pais, insignias y temas exclusivos,
subir la dificultad del reto (nunca bajarla).

**Las vidas pasan a ser de Pro (21/08/2026).** Hasta esa fecha la regla era "se
vende todo lo que rodea a la racha, nunca la racha misma" y las 2 vidas eran
gratis, con este argumento escrito: venderlas convierte el ranking en
pay-to-win. El usuario decidio cambiarlo sabiendo eso. Queda anotado aqui y no
borrado, porque el argumento sigue siendo cierto y la consecuencia es real: un
usuario de pago aguanta dos fallos al mes en el ranking y uno gratis, ninguno.

**Lo que sigue sin venderse**: vidas sueltas por compra puntual, y la racha
misma. Pagar da vidas para el mes en curso, nunca reconstruye una racha ya rota
ni sube el contador.

**Al dejar de pagar no se borra nada.** Las alarmas de mas se apagan y la
repeticion por dias deja de aplicarse, pero siguen guardadas tal cual: volver a
Pro lo devuelve todo sin reconfigurar. Las vidas que quedasen del mes se pierden
en el acto.

## Diseno

- Direccion: `docs/design/referencias/01-reloj-fisico-direccion-principal.png`.
  Reloj fisico blanco, neumorfico, digitos de matriz de puntos, base monocroma y
  un solo color de acento.
- **Solo modo oscuro.** El modo claro se elimino el 20/08/2026: el despertador
  se mira a las seis de la manana con la habitacion a oscuras, y un modo claro
  solo servia para deslumbrar al que acaba de abrir los ojos. No hay ajuste de
  tema en la app; la paleta es un solo juego de colores, no una pareja.
  *Contrapartida asumida: la referencia 01 es un reloj fisico blanco, asi que la
  app ya no imita su color, solo su material y sus digitos.*
- Espanol unicamente.
- Descartadas las referencias 03 y 04 (oscuro/neon) por genericas.

## Navegacion

Decidido el 20/08/2026, que no estaba y hacia falta para poder montar la app.

- **Tres secciones**, en una barra abajo: **Alarmas · Racha · Ranking**. La app
  entra siempre por Alarmas.
- **Ajustes y el muro de pago no son secciones**: se abren en hoja desde donde
  se piden, y por eso llevan una equis y no un boton de volver.
- **El reto no se visita.** No esta en la barra ni se alcanza a mano: aparece
  cuando suena la alarma. Ponerlo a un toque de distancia seria dar la forma de
  saltarselo.
- La barra es propia, no la del `TabView` del sistema: en iOS 26 esa es de
  vidrio y aqui todo es plastico mate con la luz fija arriba a la izquierda.

## Descartado explicitamente

Territorios geograficos tipo bandas *(idea original del usuario, eliminada por
complejidad de deteccion y de solapamiento entre vecinos)*, flexiones, Apple
Watch, accesibilidad y retos alternativos, antifraude, notificaciones sociales,
contenido generado por usuarios, ingles, ligas de amigos.

## Ficha de App Store

Clasificacion 12+. Nombre provisional **RepRise** — ojo, existen ya *RiseReps:
Workout Alarm* (iOS) y *RiseRep Alarm* (Android), mismas palabras al reves y mismo
nicho.
