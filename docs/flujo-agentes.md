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

Cada agente tiene un briefing propio con su alcance, su definicion de terminado y
las trampas que ya conocemos. La tabla es solo el indice.

| Agente | Paquetes | Encargo | Plan |
|---|---|---|---|
| A — Rachas | `AlarmCore`, `Persistence` | Motor de rachas y vidas, con tests. Persistencia y el rastro de reto empezado. | [plan-a.md](../plan-a.md) |
| B — Alarma | `AlarmScheduler` | AlarmKit tras el protocolo, repeticion, tonos, sostener el sonido durante el reto. | [plan-b.md](../plan-b.md) |
| C — Sensores | `ChallengeKit` | Pasos y sentadillas. **Primero la herramienta de calibracion.** | [plan-c.md](../plan-c.md) |
| D — Diseno | `DesignSystem` | Sistema de diseno completo y pantallas estaticas. | [plan-d.md](../plan-d.md) |

## Los cuellos de botella, dichos por adelantado

- ~~**B depende del entitlement de AlarmKit.**~~ **No era verdad**, y se
  descubrio el 21/08/2026 solo porque a alguien se le ocurrio intentarlo: no hay
  entitlement que pedir, la alarma suena. Este cuello de botella se dio por
  cierto meses sin comprobarlo, y a B le costo trabajar a ciegas para nada.
- **B y C solo se validan en el iPhone fisico**, y hay uno. Ahi la paralelizacion
  se acaba y hay que turnarse con el usuario delante.
- **D no depende de nadie** y puede ir a fondo desde el minuto uno.

## Reglas de los PRs

- Nadie hace push a `main`. Rama, PR, revision humana, fusion.
- Un PR toca **un solo paquete**. Si necesitas tocar dos, probablemente estas
  cambiando un contrato: para y preguntalo.
- El CI compila y pasa los tests de `AlarmCore` en cada PR. Nada mas: no queremos
  un CI pesado en un proyecto de un mes.
