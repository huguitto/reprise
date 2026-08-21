# AlarmScheduler

La alarma: programarla, que suene con la app cerrada y que no se calle hasta
que el reto este hecho.

## Que hay aqui

| Pieza | Para que |
|---|---|
| `SystemAlarmScheduler` | La implementacion real sobre AlarmKit. **Es la que monta la app, y suena.** |
| `PreviewAlarmScheduler` | En memoria, sin AlarmKit. Para `#Preview`, tests y simulador. |
| `AlarmFirePlan` | Hora y dias ya validados, sin tipos de AlarmKit. Es lo que se puede probar en el host. |
| `ToneCatalog` | El catalogo de tonos y su respaldo cuando algo falta. |
| `OpenChallengeIntent` | Lo que hace el boton secundario de la alerta: abrir la app con el reto. |
| `ChallengeInbox` | El recado que ese boton deja para la app. |
| `ChallengeSound` | El sonido en bucle mientras dura el reto, ya en manos de la app. |
| `AlarmAuthorizationCopy` | Los textos de la ruta de permiso denegado. |

## Como se monta en la app

**1. Elegir programador.** En el dispositivo, el de verdad:

```swift
let programador: any AlarmScheduling = SystemAlarmScheduler()
```

El de preview sigue siendo el que quieres en los `#Preview`, en los tests y en
el simulador, donde AlarmKit no tiene con que sonar. No es un sustituto a la
espera de nada: es la otra mitad del protocolo.

**2. Registrar el App Intent.** AppIntents no descubre por su cuenta los intents
que viven en un paquete. En el target de la app hace falta una declaracion, o el
boton secundario de la alerta no hara nada:

```swift
import AppIntents
import AlarmScheduler

struct RepRiseAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [AlarmSchedulerAppIntents.self] }
}
```

**3. Recoger el recado al arrancar.** Cuando la app abre por el boton secundario,
la alarma que sono esta en el buzon:

```swift
if let peticion = ChallengeInbox.consume() {
    // 1. PendingChallengeRepository.begin(...)  — el rastro en disco, antes de nada
    // 2. abrir la pantalla del reto peticion.challenge
    // 3. await programador.resumeCurrentAlarm()  — la app toma el relevo del sonido
}
```

**4. El sonido.** `resumeCurrentAlarm()` apaga la alerta del sistema y arranca el
sonido de la app en bucle. Se llama al abrir la pantalla del reto y otra vez cada
vez que el reto se abandona a mitad (`ChallengeProgress.isStalled`).
`silenceCurrentAlarm()` **solo** cuando el reto esta completo: es la regla de
producto, no un detalle de implementacion.

**5. Permiso denegado.** `AlarmAuthorizationCopy` trae titulo, explicacion y la
URL de Ajustes. Sin ese permiso no hay despertador y hay que decirlo, no dejar
una lista de alarmas que nunca van a sonar.

## Anadir un tono

Dos pasos, y ninguno toca codigo de otro paquete:

1. Deja el fichero en `App/Resources` (maximo **30 segundos**, limite duro de
   AlarmKit: lo que pase de ahi se corta).
2. Anade su `Tone` a `ToneCatalog.delBundle`.

Si el fichero no llega al bundle o el id no existe, la alarma suena con el
sonido del sistema. Un problema de catalogo puede dejarte sin tu tono; nunca sin
despertador.

`ToneCatalog.problemas(en:)` revisa el catalogo contra un bundle —ficheros que
faltan, tonos que pasan de 30 s— y esta pensado para un test en dispositivo en
cuanto haya audio de verdad.

## Lo probado en el iPhone, y lo que sigue sin verse

**21/08/2026, iPhone 15 Pro Max.** Aqui ponia que nada de `SystemAlarmScheduler`
se habia visto funcionar porque faltaba un entitlement que Apple aprueba caso por
caso. Era falso: no existe tal entitlement. La app, firmada con la cuenta de
desarrollador **gratuita**, se instalo, pidio el permiso de alarmas por
`AlarmManager.requestAuthorization()`, se programo una alarma y **sono**. Los
entitlements firmados son tres y ninguno es de AlarmKit; lo unico necesario es
`NSAlarmKitUsageDescription`, que ya estaba en el Info.plist.

Lo que ese ensayo **no** cubrio, y sigue sin verse funcionar:

- El boton secundario de la alerta abriendo el reto (`OpenChallengeIntent` →
  `ChallengeInbox`). Esta escrito y registrado, no observado.
- El sonido en bucle que sostiene la app durante el reto (`ChallengeSound`) y
  que no se calla hasta completarlo.
- Los tonos del bundle: solo se ha oido el sonido por defecto del sistema.
- Las repeticiones por dias de la semana a lo largo de varios dias.
