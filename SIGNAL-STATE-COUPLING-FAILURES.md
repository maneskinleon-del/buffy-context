# Fallo de acoplamiento señal-estado

> Taxonomía operativa — origen: ciclo C1/C2 del plan PII (2026-09-28/29).
> La lista de casos NO es cerrada: es la clase de doc que se escribe una vez
> y sirve para el resto del proyecto. Ante un fallo nuevo, la pregunta guía
> es: **¿qué dimensión del acoplamiento está rota?**

## Definición

**Fallo de acoplamiento señal-estado**: la señal de verificación existe pero
está desacoplada del estado que verifica. La documentación y la verificación
pueden ser correctas por separado y aun así fallar el pegamento entre ambas —
un contrato que promete (estados, health checks, dry-runs, CI) puede ser
fingido por la implementación que lo reporta.

No es "el test está mal" ni "el servicio está caído": es la **tercera cosa**
entre ambos — el mecanismo que se supone une señal y estado — la que falla.

## Las 5 instancias registradas

Cada caso ilustra una dimensión distinta del acoplamiento.

### 1. Trabajo — la señal dice "vivo", el estado dice "no puedo trabajar"

**Caso:** Ollama wedged 3+ días (2026-09-28). `GET /api/tags` respondía 200
con generación muerta y embeds largos en 9-10s. El síntoma visible (hook
bloqueado) apuntaba a "servicio caído"; el diagnóstico real era "servicio
vivo que no puede hacer su trabajo". Explica por qué reinicios previos no
resolvían: nadie preguntaba por capacidad, solo por liveness.

**Señal:** health check (liveness) · **Estado:** capacidad real de terminar
el trabajo en tiempo acotado.
**Fix:** probe de capacidad (`POST /api/embed` bge-m3) + gate de performance
con input largo (~5.7KB ≤6s) + techos `timeout` por comando (`e9ab468`).

### 2. Remoto — la señal dice "sincronizado", el estado dice "solo lo intenté"

**Caso:** `sync push` reportaba "✔ commiteado y pusheado" sin haber pusheado
nada (add/commit/push fallidos tragados). `.sync-state` registraba intención.

**Señal:** marca de sync · **Estado:** qué hay efectivamente en el remoto.
**Fix:** `state_set` después del push OK; push fallido ⇒ `pend_set` + exit 1
sin marcar; reintento automático; tests git-real assertionando el fallo
(`8d8a388`, contrato en `scripts/lib/buffy-memory-sync.sh:30`).

### 3. Tiempo — la señal dice "pasa hoy", el estado dice "no pasará mañana"

**Caso:** time-bomb del fixture TTL (`test-verify.sh`): `verified: 2026-08-07`
con `ttl_days: 30` venció el 2026-09-06 → 3 checks fallaban por puro paso del
tiempo. Ninguna auditoría lo detecta sin correr el test **en la fecha exacta**.
"El test pasa" y "el test pasará mañana" no son la misma afirmación.

**Señal:** test verde hoy · **Estado:** test verde bajo la condición que
simula (TTL vigente).
**Fix:** fecha dinámica (`datetime.date.today()`) — el fixture siempre
simula la condición que pretende (`e9ab468`).

### 4. Entorno — la señal dice "pasa aquí", el estado dice "depende de la máquina"

**Caso:** `sin fuentes → inferred` fallaba solo donde `uv` está instalado
(el resolver lo detectaba real-time). Dependencia del entorno disfrazada de
test determinista; en CI (sin uv) pasaba siempre.

**Señal:** test pasa en esta máquina · **Estado:** el comportamiento bajo
test es independiente del entorno.
**Fix:** `--no-live` (aislar la jerarquía del sistema real — `e9ab468`).

### 5. Ejecución — la señal dice "existe", el estado dice "no corre"

**Caso:** hook pre-commit versionado en el repo pero ausente de `.git/hooks/`.
La mitad del contrato "el hook corre la suite antes del commit" era
aspiracional: commits históricos nunca fueron gateados.

**Señal:** el mecanismo está escrito · **Estado:** el mecanismo se ejecuta.
**Fix:** instalar + verificar con corrida real (`e9ab468`).

## Corolario operativo

- Toda verificación debe terminar en **tiempo acotado** y assertionar el
  HECHO, no la intención. Un skip es honesto solo si documenta qué condición
  no se cumplió (contrato, no silencio).
- Ante un fallo nuevo de esta clase, nombrar primero la **dimensión** (¿trabajo,
  remoto, tiempo, entorno, ejecución?) y después buscar el desacople concreto.

## Meta-propiedad: el sistema se aplica a sí mismo

Registrado como propiedad del sistema, no como anécdota — dos incidentes del
mismo ciclo en que **la verificación cazó a quien la diseñaba**:

1. Handoff del operador con la premisa "tree limpio" — el receptor la verificó
   antes de razonar (convención de trazabilidad, caso 7 en `LOAD_CONTEXT.md`).
2. El guard de PII atrapando su propia nota de anuncio (el CHANGELOG que
   citaba la literal del patrón redactado) y auto-matcheándose al commitearse
   (resuelto con auto-exclusión de pathspec, `01f33e7`).

La convención `[orig]/[verificado]` + tests ejecutables + guards que se
auto-excluyen hacen trabajo que el diseño original no anticipó explícitamente.
Es la diferencia entre "tenemos un proceso" y "el proceso funciona contra
nosotros": **el sistema se aplica a sí mismo sin ceremonia extra.**
