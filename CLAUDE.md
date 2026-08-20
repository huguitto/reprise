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
2. **`Packages/AlarmCore/Sources/AlarmCore/Contracts.swift` es sagrado.** Ahi
   viven los protocolos y modelos contra los que compilan los demas. Si crees
   que hay que cambiar algo de ese fichero, **para y preguntalo**: los otros tres
   agentes estan compilando contra el ahora mismo.
3. **Nadie hace push a `main`.** Trabajas en tu rama, abres PR, lo revisa una
   persona. La rama esta protegida en GitHub, asi que ni aunque lo intentes.
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
- **AlarmKit exige un entitlement que Apple aprueba caso por caso.** Hasta que
  llegue, usa `PreviewAlarmScheduler` para todo.
- **En el simulador no hay CoreMotion.** Usa `SimulatedChallengeDetector`.

## Tests

Solo se exigen en `AlarmCore`, y ahi son obligatorios. Es la logica de rachas: un
fallo ahi borra la racha de alguien y no se puede deshacer. En el resto de
paquetes, tests solo donde aporten.
