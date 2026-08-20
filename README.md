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

## Estado

Fase 0: andamio, contratos entre modulos y motor de rachas con tests.

**Bloqueante abierto:** el entitlement de AlarmKit, que Apple aprueba caso por
caso, y sin el cual la alarma no puede sonar con la app cerrada.
