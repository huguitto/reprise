# Como trabajamos con cuatro agentes en paralelo

## Worktrees

Cada agente tiene una copia real del repositorio con su propia rama. No comparten
directorio de trabajo, asi que no se pisan ficheros ni se interrumpen
compilaciones.

```
app-alarma/            main — aqui revisas e integras tu
../wt-rachas/          agente A → feat/motor-rachas
../wt-alarma/          agente B → feat/alarmkit
../wt-sensores/        agente C → feat/deteccion-retos
../wt-diseno/          agente D → feat/sistema-diseno
```

Cada worktree necesita su propio `tuist generate` la primera vez.

## Reparto

| Agente | Paquetes | Encargo |
|---|---|---|
| A — Rachas | `AlarmCore`, `Persistence` | Motor de rachas y vidas, con tests. Persistencia SwiftData y el rastro de reto empezado. |
| B — Alarma | `AlarmScheduler` | AlarmKit detras del protocolo, alarmas con repeticion, catalogo de tonos, sostener el sonido durante el reto. |
| C — Sensores | `ChallengeKit` | Contador de pasos y detector de sentadillas. **Primero la herramienta de calibracion**, despues el detector. |
| D — Diseno | `DesignSystem` | Sistema de diseno completo y pantallas estaticas. |

## Los cuellos de botella, dichos por adelantado

- **B depende del entitlement de AlarmKit.** Hasta que Apple responda, trabaja a
  ciegas contra `PreviewAlarmScheduler`.
- **B y C solo se validan en el iPhone fisico**, y hay uno. Ahi la paralelizacion
  se acaba y hay que turnarse con el usuario delante.
- **D no depende de nadie** y puede ir a fondo desde el minuto uno.

## Reglas de los PRs

- Nadie hace push a `main`. Rama, PR, revision humana, fusion.
- Un PR toca **un solo paquete**. Si necesitas tocar dos, probablemente estas
  cambiando un contrato: para y preguntalo.
- El CI compila y pasa los tests de `AlarmCore` en cada PR. Nada mas: no queremos
  un CI pesado en un proyecto de un mes.
