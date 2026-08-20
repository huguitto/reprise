# Plan A — Rachas y persistencia

**Worktree**: `../wt-rachas` · **Rama**: `feat/motor-rachas`
**Paquetes tuyos**: `AlarmCore`, `Persistence`

Lee antes: [decisiones-producto.md](docs/decisiones-producto.md) y
[arquitectura.md](docs/arquitectura.md).

## Lo que ya existe

`AlarmCore` esta construido: modelos de dominio, `StreakEngine` y 13 tests en
verde. **No lo reescribas.** Puedes anadir, no rehacer.

## Lo que tienes que hacer

1. **`Persistence` con SwiftData.** Implementa `AlarmRepository`,
   `StreakRepository`, `DayRecordRepository` y `PendingChallengeRepository`.
2. **Migraciones explicitas desde la version 1.** No las dejes para despues: en
   cuanto haya un usuario con una racha de 40 dias, una migracion mal hecha se la
   borra y no hay vuelta atras.
3. **Un servicio que resuelva el dia**: recibe el resultado del reto, llama a
   `StreakEngine` y persiste estado y registro **de forma atomica**. Si se guarda
   el registro pero no el estado (o al reves), la racha queda corrupta.
4. **Deteccion del reto huerfano al arrancar.** Si al abrir la app hay un
   `PendingChallenge` sin cerrar, la sesion anterior murio a mitad: resuelve ese
   dia como `.fallado(.appTerminada)`. Es lo unico que impide que matar la app
   sea la forma trivial de saltarse el despertador.
5. **Niveles e insignias**, como reglas puras en `AlarmCore` con sus tests.

## Terminado cuando

- `cd Packages/AlarmCore && swift test` en verde, con tests nuevos para lo tuyo.
- Cerrar la app y reabrirla conserva alarmas, racha y vidas.
- Matar el proceso a mitad de un reto y reabrir penaliza el dia.

## Trampas que ya conocemos

- **`livesRefilledYearMonth` a `nil` repone vidas siempre.** Es correcto para un
  usuario nuevo, pero significa que ese campo **no puede quedarse a `nil` al
  migrar**: un usuario existente recuperaria vidas cada vez que abre la app.
- La idempotencia por dia ya esta resuelta en el motor. No la dupliques.
- **`Date` no entra en el dominio.** La conversion a `Day` ocurre una sola vez, en
  el borde, con el calendario del dispositivo.

## Lo que NO haces

Interfaz, red, sensores. Si necesitas cambiar `Contracts.swift`, para y pregunta: hay un hook y un
check de CI que te lo impiden, y estan ahi por algo.
