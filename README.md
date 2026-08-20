# RepRise

Despertador para iOS que solo se apaga si te levantas: **20 pasos** o
**10 sentadillas**. Con rachas, vidas mensuales y ranking mundial y por paises.

## Empezar

```bash
brew install tuist
tuist generate
```

## Documentacion

- [Decisiones de producto](docs/decisiones-producto.md) — qué se construye y qué no
- [Arquitectura](docs/arquitectura.md) — los siete modulos y por que
- [Flujo de agentes](docs/flujo-agentes.md) — worktrees y reparto del trabajo
- [CLAUDE.md](CLAUDE.md) — reglas para quien programa aqui

## Planes de trabajo

Un plan por agente. Se le dice "tu trabajo esta en plan-x.md" y ya tiene todo:
alcance, definicion de terminado y las trampas conocidas.

| | Encargo | Worktree |
|---|---|---|
| [plan-a.md](plan-a.md) | Rachas y persistencia | `../wt-rachas` |
| [plan-b.md](plan-b.md) | Alarma con AlarmKit | `../wt-alarma` |
| [plan-c.md](plan-c.md) | Deteccion de pasos y sentadillas | `../wt-sensores` |
| [plan-d.md](plan-d.md) | Sistema de diseno | `../wt-diseno` |

## Estado

Fase 0: andamio, contratos entre modulos y motor de rachas con tests.

**Bloqueante abierto:** el entitlement de AlarmKit, que Apple aprueba caso por
caso, y sin el cual la alarma no puede sonar con la app cerrada.
