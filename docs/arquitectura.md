# Arquitectura

Siete piezas: seis paquetes Swift locales y un target de app. No es purismo, es
la condicion para que cuatro agentes trabajen a la vez sin pisarse.

```
App (target)  ← unico sitio donde se junta todo
 ├── AlarmCore        dominio puro, sin dependencias
 ├── Persistence      SwiftData            → AlarmCore
 ├── AlarmScheduler   AlarmKit             → AlarmCore
 ├── ChallengeKit     CoreMotion           → AlarmCore
 ├── RankingKit       Supabase             → AlarmCore
 └── DesignSystem     SwiftUI              → AlarmCore
```

`AlarmCore` no importa SwiftUI, ni CoreMotion, ni AlarmKit, ni red. Si alguna vez
lo necesita, ese codigo no pertenece a `AlarmCore`.

Los cinco paquetes de arriba **no se conocen entre si**. Solo se encuentran en el
target de la app, que es quien inyecta las implementaciones concretas en los
protocolos de `Contracts.swift`. Por eso cuatro agentes pueden avanzar en
paralelo sin coordinarse.

## Por que Tuist

El `.xcodeproj` es un unico fichero que Xcode reescribe entero en cada cambio y
que es imposible de fusionar a mano. Con cuatro agentes abriendo PRs, seria un
conflicto por PR. Con Tuist el proyecto se genera desde `Project.swift` y **no se
versiona**: el conflicto desaparece porque el fichero no existe en git.

Si tocas la estructura del proyecto, editas `Project.swift` y ejecutas
`tuist generate`. Nunca el `.xcodeproj`.

## Por que los paquetes declaran macOS

Para que `swift build` y `swift test` corran en el host, sin simulador y sin
Xcode. Los tests del dominio tardan milisegundos y el CI no necesita un runner de
macOS con simulador arrancado. El codigo solo-iOS va detras de
`#if canImport(CoreMotion)` o `#if canImport(AlarmKit)`.

## Offline primero

La alarma, el reto y la racha funcionan **sin red**, siempre. `RankingKit`
sincroniza cuando hay internet y encola cuando no. Nada en el camino critico de
despertarse puede esperar a un servidor.

## El rastro del reto empezado

`PendingChallengeRepository` escribe a disco antes de arrancar el reto. Si la app
se abre y encuentra un rastro sin cerrar, sabe que la sesion anterior murio a
mitad y penaliza. Es lo unico que impide que matar la app sea la forma trivial de
saltarse el despertador.
