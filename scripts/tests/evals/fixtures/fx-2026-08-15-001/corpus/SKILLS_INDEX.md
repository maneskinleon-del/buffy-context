# SKILLS_INDEX

> Catálogo de los 43 skills instalados en `~/.agents/skills/`. Es el "marketplace"
> propio de Buffy: cada skill cubre un dominio y se activa según el caso. Complementa
> la ausencia de sistema de plugins en FreeBuff — estas skills son portátiles entre
> cualquier cliente (FreeBuff, OpenCode, etc.) porque viven en el home del usuario.

> Origen de las descripciones: `SKILL.md` de cada skill + system prompt. Si un skill
> cambia, actualizar su entrada aquí.

---

## Android / ADB / Mobile (12)
| Skill | Propósito | Disparador |
|---|---|---|
| `android-adb` | Control de dispositivo vía ADB crudo (discovery, launch, tap/swipe, screenshot, ui dump) | tareas ADB directas |
| `android-agent` | Agente Android dedicado: detecta proyecto, verifica ADB, carga Knowledge/Android, activa skills | proyecto Android detectado |
| `android-clean-architecture` | Clean Architecture para Android/KMP (módulos, UseCases, Repos) | estructurar proyecto Android |
| `android-game-opt` | Optimización de rendimiento para juegos en Android | tuning de juegos |
| `android-native-dev` | Dev nativa Android (Material 3, Kotlin/Compose) | UI nativa Android |
| `android-project-setup` | Setup completo: compilar, instalar APK, permisos Shizuku/overlay | compilar/instalar app en teléfono |
| `hyperos-hardening` | Hardening/privacidad Xiaomi HyperOS (debloat, analytics) | limpiar HyperOS |
| `shizuku-rikka` | Shizuku + rish: escalación de privilegios sin root | permisos sistema sin root |
| `scrcpy-freefire` | scrcpy + GG Mouse Pro para Free Fire en Linux | jugar Free Fire desde PC |
| `xiaomi-adb-tricks` | Comandos ADB Xiaomi con root | tweaks Xiaomi |
| `mobile-android-design` | Material Design 3 + Compose patterns | diseño UI Android |
| `image-analyzer` | Análisis de screenshots Android para detectar/conceder permisos | diálogos de permisos en pantalla |

## Frontend / Web (7)
| Skill | Propósito | Disparador |
|---|---|---|
| `tailwind-design-system` | Design systems con Tailwind v4 + tokens | componentes/Tailwind |
| `vercel-react-best-practices` | React/Next.js perf (Vercel) | código React/Next |
| `vite` | Vite build/plugins/SSR, migración Rolldown | proyecto Vite |
| `vitest` | Tests con Vitest (Jest-compatible) | escribir tests |
| `typescript-advanced-types` | Tipos avanzados TS (generics, conditional, mapped) | lógica de tipos compleja |
| `playwright-cli` | Automatización de browser con Playwright | tests E2E/web |
| `form-filler` | Rellenado de formularios web (Puppeteer, multi-idioma) | formularios web |

## Workflow / Productividad (7)
| Skill | Propósito | Disparador |
|---|---|---|
| `capture` | Volcar ideas caóticas en sistema estructurado | brain dump |
| `deep-work` | Planificación de día de deep work (time-blocking) | planificar bloques |
| `weekly-review` | Review semanal (GTD: get clear/current/creative) | cierre de semana |
| `handoff` | Compactar conversación en doc de handoff | pasar trabajo a otro agente |
| `file-organizer` | Organizar archivos/carpetas, duplicados | ordenar filesystem |
| `fable-goal` | Convertir descripción en prompt `/goal` para sesión fresca | generar prompt de build |
| `changelog-generator` | Generar changelog desde commits | release notes |

## Thinking / Strategy (6)
| Skill | Propósito | Disparador |
|---|---|---|
| `idea-a-spec` | Idea vaga → spec de ingeniería ejecutable (loop verificado) | pedido sin pasos |
| `roast` | Panel de 5 ángulos que presiona/valida una idea | validar idea antes de build |
| `reflect` | Pausa estratégica, zoom out, reevaluar dirección | atascado / sesgo |
| `senior-architect` | Decisiones de arquitectura / ADRs / diagramas | diseñar arquitectura |
| `clarificar-entrega` | Gate de destino (web/escritorio/etc) antes de diseñar | pedido de look/estilo sin destino |
| `grill-with-docs` | Grill de plan contra CONTEXT.md/ADRs del proyecto | stress-test de plan |

## Research / Validation (6)
| Skill | Propósito | Disparador |
|---|---|---|
| `context7` | Docs actualizadas de librerías (sin alucinar API) | API de librería |
| `cross_validation_v4` | Validar info contrastando fuentes primarias/secundarias | verificar hecho |
| `exploratory_validation_v4` | Orquestador de validación exploratoria | diagnóstico exploratorio |
| `filter_heuristics_v4` | Filtrar fuentes por relevancia/vigencia/autoridad | filtrar fuentes |
| `search_criteria_v4` | Generar queries de búsqueda semánticas/sintácticas | búsqueda técnica |
| `integration_templates_v4` | Adaptar código de fuentes al proyecto base | integrar snippet externo |

## Coding rigor (3)
| Skill | Propósito | Disparador |
|---|---|---|
| `zero-hallucination-coder` | Loop Discuss→Map→Decompose→Execute→Verify (sin API inventada) | tarea compleja/alto riesgo |
| `pr-review-expert` | Review de PRs (seguridad, calidad, diff) | revisar PR |
| `git-guardrails-claude-code` | Hooks que bloquean git peligroso (push/reset/clean) | proteger git |

## Meta / Agent (2)
| Skill | Propósito | Disparador |
|---|---|---|
| `modo-autonomo` | Ejecutar sin preguntar lo que se puede investigar | evitar preguntar al usuario |
| `skill-creator` | Crear nuevas skills (workflow/plantilla) | crear skill |

---

## Notas
- Total real: **43 skills** (el README de buffy-context dice "23" — drift documental pendiente de corregir).
- Activación: la mayoría se cargan bajo demanda según el dominio de la tarea.
- Para crear uno nuevo: ver skill `skill-creator`.
