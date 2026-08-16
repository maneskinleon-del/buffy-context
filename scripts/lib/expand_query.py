#!/usr/bin/env python3
# expand_query.py — Expansión de query (rama X, Paso 10 H1).
# ─────────────────────────────────────────────────────────────────────────────
# Fuente: scripts/tests/evals/run-expansion-PC.sh (Paso 10, variante H1-DICT-MIN).
# El runner del Paso 10 midió que la rama X (re-consultas léxicas con términos
# de un diccionario ES→EN genérico) CERRABA el candidate gap del EVAL (Q03
# `gh pr create` entra al pool vía `push`/`create`; 5/6 agujas con H1, 6/6 con
# H2). En 2026-08-12 la selección (RRF) fallaba y por eso no se adoptó; HOY la
# selección es M3 (buffy-selector.sh) y el cuello de botella ya no existe.
#
# Este módulo porta ÚNICAMENTE la señal realista de la serie: DICT_H1 (reglas
# genéricas ES→EN). NUNCA se porta H2 (oráculo por query) — regla de la serie.
#
# Uso (CLI):
#   python3 expand_query.py --query "quiero pushear el commit y crear el pr"
#                           [--json] [--dict-hash] [--hash]
#   Salida default: un término por línea (orden de aparición, dedup).
#   --json  → JSON: {"terms": [...], "dict_hash": "..."}
#   --dict-hash → imprime solo el hash del diccionario (drift-detector).
#   --hash  → imprime solo el hash de los términos calculados (trazabilidad).
#   Exit: 0 OK · 2 error de uso.
#
# Determinista: mismo query + mismo DICT_H1 → mismos términos.

import argparse
import hashlib
import json
import re
import sys
import unicodedata

# ── stopwords ES (idénticas al runner del Paso 10 — no inventar una nueva) ──
STOPWORDS_ES = set("""a al algo aunque asi aun cada casi como con cual cuando cuanta cuantas cuanto
cuantos de del demasiado donde el ella ellas ellos en entre esa esas ese esos esta estas
este estos fue haber hasta haya hay he hizo la las le les lo los mas me mi mis mucho muchos
mucha muchas muy nada nadie ni no nosotros nosotras nuestra nuestras nuestro nuestros o otra
otras otro otros para pero poca pocas poco pocos por porque que quien quienes quiero quiere
se sea ser si sin solo sino sobre su sus tal tambien tampoco tan tanto tanta te tiene tienes
todo todos toda todas tu tus un una uno unas usted y ya""".split())


# ── DICT_H1 (congelado del runner del Paso 10, línea 138 — hash b0406a33…) ──
# Reglas de traducción ES→técnico GENÉRICAS aplicadas a los tokens
# significativos de la query. No contiene comandos/símbolos exactos
# (eso sería H2/oráculo — prohibido por la serie).
DICT_H1 = {  # palabra_es (deaccent, lowercase) → términos de expansión
    "crear": ["create", "make", "new", "add"],
    "pushear": ["push"],
    "commit": ["commit"],
    "pull": ["pull", "pull request"],
    "request": ["request", "pull request"],
    "conecta": ["connect", "adb connect"],
    "conectar": ["connect", "adb connect"],
    "conecte": ["connect", "adb connect"],
    "aparece": ["list", "show", "device", "adb devices"],
    "aparecer": ["list", "show", "device", "adb devices"],
    "permisos": ["permission", "grant", "pm grant"],
    "permiso": ["permission", "grant", "pm grant"],
    "concedo": ["grant", "pm grant"],
    "shizuku": ["shizuku", "rish"],
    "app": ["application", "package"],
    "aplicacion": ["application", "package"],
    "pantalla": ["screen", "display"],
    "apaga": ["off", "disable", "dpms"],
    "apagar": ["off", "disable", "dpms"],
    "minutos": [],
    "componente": ["component"],
    "serial": ["serial", "devices", "device"],
    "celular": ["phone", "device", "adb"],
    "anda": ["slow", "performance"],
    "lento": ["slow", "performance"],
    "hacer": [],
    "hook": ["hook", "hooks", "state"],
    "hooks": ["hook", "hooks", "state"],
    "puedo": [],
    "terminal": ["terminal"],
    "opaca": ["transparent", "opacity"],
    "transparente": ["transparent", "opacity"],
    "opaco": ["transparent", "opacity"],
    "ve": ["view", "show"],
    "vea": ["view", "show"],
    "rendimiento": ["performance", "governor"],
    "optimizar": ["optimize", "performance", "governor"],
    "calienta": ["thermal", "temperature"],
    "caliente": ["thermal", "temperature"],
    "juego": ["game", "free fire"],
    "juega": ["game", "free fire"],
    "script": ["script", "sh"],
    "abre": ["launch", "open", "start"],
    "abrir": ["launch", "open", "start"],
    "revisa": ["check", "log", "status"],
    "revisar": ["check", "log", "status"],
    "quiere": [],
    "quiero": [],
    "leer": ["read", "get", "serial"],
    "necesita": [],
    "necesito": [],
    "sin": [],
    "root": ["root"],
    "raiz": ["root"],
    "react": ["react", "component", "hooks"],
    "free": ["free fire"],
    "fire": ["free fire"],
    "pr": ["pull request", "pr"],
    "le": [],
    "por": [],
    "despues": [],
    "estado": ["state", "hooks"],
    "unos": [],
    "sola": [],
    "tcpip": ["tcpip", "adb tcpip"],
    "telefono": ["phone", "device", "adb"],
    "de": [],
}


def dict_hash():
    """Hash del diccionario (drift-detector, como el runner del Paso 10).
    NOTA: el runner calculaba el hash sobre {h1, h2_extra}; este módulo solo
    porta H1 (regla de la serie: H2 es oráculo, nunca se adopta), así que el
    hash aquí es sobre {"h1": DICT_H1} y difiere del del runner (b0406a33…)."""
    return hashlib.sha1(
        json.dumps({"h1": DICT_H1}, sort_keys=True, ensure_ascii=False).encode()
    ).hexdigest()[:16]


def deaccent(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s)
                   if unicodedata.category(c) != 'Mn')


def tokenize_significant(raw):
    """Tokens significativos de la query — idéntico al runner del Paso 10:
    deaccent → lowercase → alnum → ≥3 chars → stopwords ES → máx 8."""
    norm = deaccent(raw).lower()
    norm = re.sub(r'[^a-z0-9 ]', ' ', norm)
    norm = re.sub(r'\s+', ' ', norm).strip()
    toks = []
    for tok in norm.split():
        if len(tok) < 3 or tok in STOPWORDS_ES:
            continue
        toks.append(tok)
        if len(toks) >= 8:
            break
    return toks


def expansion_terms(query):
    """Términos de la rama X para la query — H1 (reglas genéricas), NUNCA H2.
    Misma semántica que expansion_terms(qid, query) del runner con dict=h1:
    por cada token significativo, los términos de DICT_H1, en orden de
    aparición, dedup (primer visto)."""
    terms = []
    seen = set()
    for tok in tokenize_significant(query):
        for t in DICT_H1.get(tok, []):
            if t and t not in seen:
                seen.add(t)
                terms.append(t)
    return terms


def terms_hash(terms):
    return hashlib.sha1(json.dumps(terms, sort_keys=True,
                                   ensure_ascii=False).encode()).hexdigest()[:16]


def main(argv):
    ap = argparse.ArgumentParser(description="Expansión de query (rama X, H1)")
    ap.add_argument("--query", required=True, help="consulta del usuario")
    ap.add_argument("--json", action="store_true",
                    help="salida JSON {terms, dict_hash, terms_hash}")
    ap.add_argument("--dict-hash", action="store_true",
                    help="imprime solo el hash del diccionario y sale")
    ap.add_argument("--hash", action="store_true",
                    help="imprime solo el hash de los términos y sale")
    args = ap.parse_args(argv)

    if args.dict_hash:
        print(dict_hash())
        return 0

    terms = expansion_terms(args.query)
    if args.hash:
        print(terms_hash(terms))
        return 0

    if args.json:
        print(json.dumps({"terms": terms, "dict_hash": dict_hash(),
                          "terms_hash": terms_hash(terms)}, ensure_ascii=False))
    else:
        for t in terms:
            print(t)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
