# Plan B — Alarma

**Worktree**: `../wt-alarma` · **Rama**: `feat/alarmkit`
**Paquete tuyo**: `AlarmScheduler`

Lee antes: [decisiones-producto.md](docs/decisiones-producto.md), sobre todo la
seccion "El flujo real, con la limitacion de iOS".

## Tu situacion de partida es incomoda: asumela

> **Corregido el 21/08/2026.** Lo de abajo era falso y costo caro: nadie habia
> intentado usar AlarmKit. No hace falta ningun entitlement. Se probo contra el
> iPhone y **sono**. Ya no hay que trabajar a ciegas.

~~El entitlement de AlarmKit lo aprueba Apple caso por caso y **todavia no lo
tenemos**. Hasta que llegue no puedes probar nada de verdad.~~ Trabaja contra el
protocolo `AlarmScheduling` y deja `PreviewAlarmScheduler` funcionando para que
los otros tres agentes puedan seguir.

## Lo que tienes que hacer

1. **Autorizacion**: comprobar estado, pedir permiso, y una ruta digna cuando el
   usuario dice que no (la app sin permiso de alarmas no sirve para nada, hay que
   explicarlo, no fallar en silencio).
2. **Programar y cancelar alarmas** con repeticion por dias de la semana, y
   alarmas de un solo uso.
3. **Catalogo de tonos**: el sonido por defecto del sistema mas los ficheros del
   bundle. Maximo 30 segundos cada uno, limite duro de AlarmKit.
4. **Boton secundario** en la alerta del sistema que abre la app para hacer el
   reto.
5. **Sostener el sonido durante el reto.** Cuando la app esta en primer plano, el
   audio lo lleva ella con su propia `AVAudioSession`: la alarma **no se calla
   hasta completar el reto entero**, y `resumeCurrentAlarm()` la hace volver a
   sonar si el usuario abandona a mitad.

## Terminado cuando (en el iPhone fisico, no en simulador)

- La alarma suena con la app **cerrada**, rompiendo silencio y modo de
  concentracion.
- El boton secundario abre la app y arranca el reto.
- El sonido se mantiene hasta completar el reto y vuelve tras un abandono.

## Trampas que ya conocemos

- **`AlarmKit.Alarm` choca con nuestro `AlarmCore.Alarm`.** Dentro de tu paquete,
  `Alarm` a secas no compila: usa el alias `DomainAlarm`.
- **El boton "Stop" de la interfaz del sistema no se puede ocultar.** No pierdas
  tiempo intentandolo: el diseno ya lo asume, quien lo pulse sin hacer el reto
  pierde la racha.
- **iOS no da acceso a los tonos del usuario.** Ni los de fabrica ni los suyos.

## Lo que NO haces

La logica de rachas (es del agente A) ni la deteccion de ejercicio (agente C).
