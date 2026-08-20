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

## Terminado cuando

- En 5 sesiones distintas, 10 sentadillas reales cuentan exactamente 10.
- Agitar el movil sentado no llega a 10.
- El detector funciona con el movil en la mano derecha, en la izquierda y con
  personas de estatura distinta.

## Trampas que ya conocemos

- **En el simulador no hay CoreMotion.** Por eso existe
  `SimulatedChallengeDetector` y por eso `ChallengeDetectorFactory` elige solo.
  No rompas ese camino: es lo que permite al agente D trabajar sin dispositivo.
