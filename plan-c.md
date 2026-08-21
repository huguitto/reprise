# Plan C — Deteccion de los retos

**Worktree**: `../wt-sensores` · **Rama**: `feat/deteccion-retos`
**Paquete tuyo**: `ChallengeKit`

Tuya es la parte mas dificil del proyecto y la unica que no se puede resolver
razonando: hay que medir.

## El orden importa y no es negociable

1. **Primero, la herramienta de calibracion.** Una pantalla que grabe el flujo de
   `CMDeviceMotion` a un fichero mientras el usuario hace sentadillas de verdad, y
   que pueda reproducir esas grabaciones despues contra el detector.
2. **Despues, el contador de pasos**, que es el facil.
3. **Al final, el detector de sentadillas**, afinado contra las grabaciones.

**Por que en este orden**: sin grabaciones reales, elegir umbrales es adivinar, y
cada intento cuesta una sesion con el usuario haciendo sentadillas delante de ti.
Con grabaciones, iteras cien veces en un minuto y sin molestar a nadie. Ademas el
usuario prueba con cuenta gratuita de Apple, asi que puedes empezar ya: CoreMotion
no necesita ningun entitlement, solo la clave del Info.plist que ya esta puesta.

## Requisitos de los detectores

**Pasos (objetivo 20)**: `CMPedometer.startUpdates(from:)`, en vivo. HealthKit no
sirve, llega con minutos de retraso. El contador arranca **en el instante en que
empieza el reto**: los pasos que diera antes no cuentan.

**Sentadillas (objetivo 10, movil en la mano)**: la senal util es la aceleracion
vertical del usuario junto al cambio de altura relativa. Una sentadilla es **bajar
y volver a subir**, no un pico. Cuenta la repeticion **al completar la subida**.
Exige un recorrido minimo y un tiempo minimo por repeticion.

**Los dos**: `isStalled` a `true` tras 8 segundos sin movimiento valido. Esa es la
senal con la que la alarma vuelve a sonar cuando alguien abandona a mitad.

## Nivel de anti-trampas, dicho explicitamente

Que **agitar el movil sentado en la cama no cuele**. Nada mas. No persigas al
tramposo perfecto: es un pozo sin fondo y el usuario ya decidio que quien engana
al despertador se engana a si mismo. Prioriza no dar falsos negativos a alguien
que **si** esta haciendo el ejercicio: un detector que no cuenta una sentadilla
real a las 6 de la manana es mucho peor que uno que cuela un movimiento raro.

## Terminado — cerrado el 21 de agosto de 2026

Probado en el iPhone fisico, grabando con `CalibracionView` y reproduciendo las
grabaciones en el Mac contra `Reproductor`. Las grabaciones estan en
`Packages/ChallengeKit/Grabaciones/` y `swift test` las vuelve a pasar en cada
ejecucion.

| Criterio | Estado |
|---|---|
| 10 sentadillas reales cuentan exactamente 10 | **Cumplido** en las 2 sesiones grabadas (33 s y 43 s), 10 de 10 las dos |
| Agitar el movil sentado no llega a 10 | **Cumplido**: se queda en 3, y las 3 caen en los primeros 7 s |
| 5 sesiones distintas | **No cumplido**: se cerro con 2, por decision del dueno |
| Mano derecha y mano izquierda | **No probado**: solo mano derecha |
| Personas de estatura distinta | **No probado**: una sola persona |
| Los 20 pasos con `CMPedometer` | **No probado en dispositivo** |

Los parametros se quedan en `.porDefecto`: ya aciertan, y el barrido de 525
combinaciones no discrimina con solo 3 grabaciones —muchos juegos empatan a
puntuacion 0—, asi que no hay base para tocarlos.

Que implica cerrar aqui: el detector esta validado contra una mano, una persona
y dos sesiones. Si aparece alguien a quien no le cuenta sus sentadillas, la causa
mas probable es esa muestra corta, no el algoritmo. La herramienta para volver a
medir sigue entera en `ChallengeKit`, pero ya no cuelga de la app: hay que
recolgar `CalibracionView` desde el target para llegar a ella.

## Trampas que ya conocemos

- **En el simulador no hay CoreMotion.** Por eso existe
  `SimulatedChallengeDetector` y por eso `ChallengeDetectorFactory` elige solo.
  No rompas ese camino: es lo que permite al agente D trabajar sin dispositivo.
