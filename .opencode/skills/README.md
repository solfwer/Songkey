# Skills del proyecto

Instrucciones especializadas para agentes de IA (OpenCode). Cada carpeta tiene un
`SKILL.md` que el agente carga cuando la tarea coincide con su descripcin.

Ubicacin: `.opencode/skills/<nombre>/SKILL.md`

## Origen

| Repositorio | Skills instaladas |
|---|---|
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | 25 skills de ingeniera (ver abajo) |
| [emilkowalski/skills](https://github.com/emilkowalski/skills) | 6 skills de diseo/mvil (el resto es de animacin web/React, no aplica a Flutter) |
| [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) | `security-audit` |
| [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) | `graphify` (anlisis del codebase como grafo) |
| [hgta23/findskills](https://github.com/hgta23/findskills) | `findskills` (buscador de skills) |

## De addyosmani (25)

`api-and-interface-design`, `browser-testing-with-devtools`, `ci-cd-and-automation`,
`code-review-and-quality`, `code-simplification`, `constraint-driven-development`,
`context-engineering`, `debugging-and-error-recovery`, `deprecation-and-migration`,
`documentation-and-adrs`, `doubt-driven-development`, `frontend-ui-engineering`,
`git-workflow-and-versioning`, `idea-refine`, `incremental-implementation`,
`interview-me`, `observability-and-instrumentation`, `performance-optimization`,
`planning-and-task-breakdown`, `security-and-hardening`, `shipping-and-launch`,
`source-driven-development`, `spec-driven-development`, `test-driven-development`,
`using-agent-skills`

## De emilkowalski (6)

`mobile-native`, `apple-design`, `emil-design-eng`, `prototype`, `break-ui`,
`write-swift`

> No se instalaron `animate`, `animate-expo`, `animation-performance`,
> `animation-vocabulary`, `find-animation-opportunities`, `improve-animations`,
> `review-animations`, `ask-sonner` ni `pick-ui-library`: son de animacin
> web/React y no aplican a Flutter. Si en algn momento haces la versin web,
> se pueden aadir.

## Cmo se usan

El agente ve la lista de skills disponibles y carga la que corresponde con la
tarea. Tambin puedes pedirla por nombre: *"us la skill de code-review"*.

Para aadir ms skills: crea `.opencode/skills/<nombre>/SKILL.md` con frontmatter:

```
---
name: nombre-de-la-skill
description: Para qu sirve y cundo usarla
---
```
