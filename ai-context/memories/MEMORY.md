Dispositivo: Termux en Mi 10 (Android/HyperOS) — usar pkg para instalar, rutas en /data/data/com.termux/files/...
§
Shizuku/rish: NO tocar ~/bin/rish* ni la autenticacion sin pedir.
§
Regla repo: no editar contenido de ~/buffy-context sin pedir antes (repo thumb nail).
§
la memoria curada ahora VIAJA vía buffy-memory.sh sync
§
clasp 3.3.0 instalado en Termux (wrapper en $PREFIX/bin/clasp por shebang /usr/bin/env inexistente); auth en ~/.clasprc.json (mangonz970@gmail.com). Proyectos Apps Script clonados en ~/gscript-audit/ (auditados 2026-08-10). organiza_gmail_V3 (1yqqZX...) recibió fixes P0: snapshot por query in:inbox -label, rateLimited corta corrida, removeMainTriggers conserva triggers diarios. Etiquetas v2 borradas via trigger temporal.
§
Memoria curada sincronizada PC<<>>telefono vía buffy-memory.sh sync (repo ai-context/memories, estado per-host, guard de drift)
§
"cerrar dia" = agente escribe contexto + buffy-close-day.sh (sync memoria + SNAPSHOT + doctor + commit/push)