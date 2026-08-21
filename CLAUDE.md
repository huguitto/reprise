# RepRise

Despertador para iOS cuyo boton de apagar solo funciona si te levantas: 20 pasos
o 10 sentadillas. Rachas, vidas y ranking mundial y por paises.

Todo el codigo, los comentarios y los textos de la app van **en espanol**.

## Tu encargo

Cada agente tiene su briefing. Leelo entero antes de escribir nada:

| Agente | Paquetes | Tu plan |
|---|---|---|
| A — Rachas | `AlarmCore`, `Persistence` | **[plan-a.md](plan-a.md)** |
| B — Alarma | `AlarmScheduler` | **[plan-b.md](plan-b.md)** |
| C — Sensores | `ChallengeKit` | **[plan-c.md](plan-c.md)** |
| D — Diseno | `DesignSystem` | **[plan-d.md](plan-d.md)** |

## Reglas de trabajo (obligatorias para agentes)

1. **Cada agente trabaja solo dentro de su paquete.** Si tu tarea es
   `ChallengeKit`, no tocas ficheros de `DesignSystem` ni de `AlarmCore`.
2. **Los ficheros compartidos no se tocan sin permiso.** Son los listados en
   `.githooks/ficheros-compartidos.txt`: `Contracts.swift`, donde viven los
   protocolos y modelos contra los que compilan los demas, y `Project.swift`.
   Si crees que hay que cambiar algo ahi, **para y preguntalo**: los otros tres
   agentes estan compilando contra ellos ahora mismo.

   Hay dos barreras y no son decorativas: un hook `pre-commit` te para al hacer
   el commit, y el check de CI **Contratos compartidos** tumba el PR. Para
   levantarlas hace falta que una persona le ponga al PR la etiqueta
   `cambio-de-contrato`. Saltarte el hook con `--no-verify` no te sirve de nada:
   el CI te para igual.
3. **Nadie hace push a `main`.** Trabajas en tu rama, abres PR, lo revisa una
   persona. Hay un hook en `.githooks/pre-push` que lo bloquea. **No lo saltes
   con `--no-verify`**: el repo es privado y GitHub no puede imponerlo por su
   cuenta, asi que aqui la regla depende de que la respetes.
4. **Si algo no se puede probar sin el iPhone fisico, dilo en el PR** en vez de
   dar por bueno lo que no has visto funcionar. Solo hay un dispositivo y hay que
   turnarse.
5. **No inventes alcance.** Lo que no esta en `docs/decisiones-producto.md` no se
   construye. Hay una lista explicita de cosas descartadas: respetala.

## Comandos

```bash
tuist generate            # regenera el .xcodeproj (nunca lo edites a mano)
cd Packages/AlarmCore && swift test    # tests del dominio, sin simulador
```

Los paquetes declaran `macOS` ademas de `iOS` a proposito, para que
`swift build` y `swift test` corran en el host sin simulador. El codigo que
depende de frameworks solo-iOS va detras de `#if canImport(...)`.

## Trampas ya descubiertas

- **`AlarmKit.Alarm` choca con nuestro `AlarmCore.Alarm`.** Dentro de
  `AlarmScheduler`, usa el alias `DomainAlarm`.
- **AlarmKit NO exige ningun entitlement especial.** Aqui puso durante meses lo
  contrario, y era falso: nadie lo habia comprobado. Suena con la cuenta de
  desarrollador gratuita y con `NSAlarmKitUsageDescription` en el Info.plist.
  La app monta `SystemAlarmScheduler`. `PreviewAlarmScheduler` sigue estando,
  pero para los `#Preview` y los tests, no como sustituto.
- **`AlarmManager.schedule` no sabe actualizar.** Programar sobre un `id` que ya
  esta puesto **falla**: `Error Domain=com.apple.AlarmKit.Alarm Code=0 "(null)"`,
  sin una palabra mas. Hay que cancelar antes. Aqui se dio por hecho lo
  contrario durante meses —"programar encima es idempotente"— y era el issue
  #36: como el modelo reprograma todo lo encendido en cada sincronizacion,
  fallaba a partir de la segunda de la sesion, el usuario veia "el sistema no ha
  podido programar la alarma" y la alarma sonaba igual, porque seguia puesta de
  la primera vez. `SystemAlarmScheduler` lo resuelve con una huella de lo que
  pidio la ultima vez (`HuellaDeProgramacion.swift`): si nada ha cambiado no
  toca el sistema, y si ha cambiado cancela antes de poner.
- **`CMPedometer` no sirve para contar veinte pasos en directo.** Es una API de
  fitness diario: su cabecera entrega los datos *"on a best effort basis"*,
  confirma que estas caminando antes de contar, descarta las rachas cortas y
  entrega a tandas de varios segundos. Andando por una habitacion, con giros y
  medio dormido, contaba **un tercio**: veinte en pantalla tras sesenta de
  verdad (issue #35). No era aritmetica nuestra —el dato es acumulado y se
  sumaba entero— y por eso el primer arreglo (PR #38, quitar un tope de cadencia
  que nunca llegaba a morder) no cambio nada. `StepDetector` cuenta ahora con
  `AlgoritmoPasos` sobre `CMDeviceMotion` a 50 Hz, igual que las sentadillas, y
  deja el podometro solo de red por debajo (`FusionDePasos`).
- **Un solo `NaN` congelaba el contador para siempre.** Los filtros son IIR: con
  una muestra corrupta el sesgo se queda en NaN, toda comparacion contra NaN es
  `false` y no se vuelve a abrir un pico jamas. Medido: tras un NaN, cuarenta
  pasos de verdad contaban cero, con la alarma sonando y sin salida. Los dos
  algoritmos —pasos y sentadillas— tiran ahora la muestra que no sea finita.
- **El paso alto de las sentadillas no vale para los pasos.** `tauSesgo` nacio en
  1,5 s copiado del otro reto, y ahi corta en 0,1 Hz: el vaiven del movil girando
  en la mano pasa entero, mueve la linea base **y** infla el umbral adaptativo.
  Con una deriva de 1 m/s^2, quien anda flojo no terminaba el reto nunca. En
  0,4 s no se queda encerrado nadie. Una sentadilla va a 0,2-0,7 Hz y un paso a
  2 Hz: no se puede compartir el filtro.
- **Andar con el movil en la mano es una senal debilisima, y la trampa es diez
  veces mas fuerte.** Medido el 21/08/2026 con grabaciones de verdad, ya
  filtrado: andando, el pico no pasa de **1,8** m/s^2; agitando el movil sentado
  llega a **18,9**. Y las dos cosas van a la **misma frecuencia**, 1,30 Hz, asi
  que por ritmo no hay quien las separe: es la fuerza y solo la fuerza
  (`ParametrosPaso.techoDePico`, en 6, con margen por los dos lados).
  El error que esto corrigio merece recordarse: antes de tener los ficheros, el
  techo se defendia de una "pisada fuerte" de 12-20 m/s^2 que parecia obvia, y
  para no romperla se habia añadido un parametro entero al algoritmo. Esa pisada
  **no existe** con el telefono en la mano. Sin medir, uno se defiende de
  fantasmas y le abre la puerta a lo real.
  Lo que no se frena, y conviene no engañarse: **mecer el movil suave y sostenido
  al ritmo de una zancada sin inclinarlo cuela**, porque en esta senal eso no se
  parece a andar, es andar. Esta escrito como test.
- **La fuerza no bastaba: el que separa de verdad es el giro del movil.** El
  techo de fuerza frena la sacudida bruta y deja pasar la suave. Hugo lo vio en
  el telefono: de pie, quieto, moviendo solo la muneca, el contador subia. Esa
  grabacion contaba **16 pasos en 12 segundos**, con picos de 1-3 m/s^2, o sea
  dentro de lo que anda una persona: ningun umbral de fuerza los parte. Lo que
  los parte es cuanto **pivota** el telefono, medido como el giro del vector
  `gravity`: andando lo lleva un cuerpo y va a 3-57 deg/s; en una mano, 52-173.
  Con `ParametrosPaso.techoDeGiro` en 60 las tres trampas caen de 4, 7 y 16 a 0,
  2 y 1 y las caminatas **no pierden ni un paso**. De paso murio el
  discriminador que estas notas daban por bueno, el **ritmo**: medido, la trampa
  sale mas regular que la caminata. Falta por grabar andar con el brazo
  colgando, que hace pivotar mucho mas el movil; si eso mordiera, el suelo lo
  pone `CMPedometer` por debajo, que no lo deja en cero.
- **Una herramienta de medir que enseña el numero equivocado es peor que
  ninguna.** La vista de calibracion enseñaba el contador de *sentadillas*
  cuando el tipo era trampa, asi que la grabacion de la muneca marcaba "1" en
  pantalla mientras el de pasos iba por 16: convencia de que no habia fallo.
  Ahora enseña los dos, y el contador en vivo recibe la gravedad para que diga
  lo mismo que la reproduccion en frio.
- **En el simulador no hay CoreMotion.** Usa `SimulatedChallengeDetector`.

## Tests

Solo se exigen en `AlarmCore`, y ahi son obligatorios. Es la logica de rachas: un
fallo ahi borra la racha de alguien y no se puede deshacer. En el resto de
paquetes, tests solo donde aporten.
