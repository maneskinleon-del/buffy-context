#!/usr/bin/env python3
"""validate_json_schema.py — validador mínimo de JSON Schema (subset draft-07).

Infraestructura de tests (I-2): el repo no tiene `jsonschema` instalado y no se
añaden dependencias. Soporta SOLO los keywords que usa
scripts/lib/project_state_linter.schema.json:

    type · const · enum · required · properties · additionalProperties ·
    items · minimum · pattern · if/then/else

Cualquier otro keyword se ignora documentadamente (este archivo no pretende ser
un validador genérico).

Uso:
    python3 validate_json_schema.py <schema.json> <instance.json>
Exit: 0 válida · 1 inválida (motivos en stderr) · 2 uso/lectura
"""
import json
import re
import sys


def type_ok(expected, value):
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "null":
        return value is None
    return True


def validate(schema, value, path="$"):
    errors = []
    if not isinstance(schema, dict):
        return errors
    if "type" in schema and not type_ok(schema["type"], value):
        return [f"{path}: tipo {type(value).__name__} ≠ {schema['type']}"]
    if "const" in schema and value != schema["const"]:
        errors.append(f"{path}: {value!r} ≠ const {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: {value!r} ∉ enum {schema['enum']!r}")
    if "minimum" in schema and isinstance(value, (int, float)) \
            and not isinstance(value, bool) and value < schema["minimum"]:
        errors.append(f"{path}: {value} < minimum {schema['minimum']}")
    if "pattern" in schema and isinstance(value, str) \
            and re.search(schema["pattern"], value) is None:
        errors.append(f"{path}: {value!r} no matchea /{schema['pattern']}/")
    if isinstance(value, dict):
        for req in schema.get("required", []):
            if req not in value:
                errors.append(f"{path}: falta clave requerida {req!r}")
        props = schema.get("properties", {})
        for key, sub in props.items():
            if key in value:
                errors.extend(validate(sub, value[key], f"{path}.{key}"))
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in props:
                    errors.append(f"{path}: clave adicional no permitida {key!r}")
        if "if" in schema:
            cond_ok = not validate(schema["if"], value, path)
            branch = schema.get("then") if cond_ok else schema.get("else")
            if branch:
                errors.extend(validate(branch, value, path))
    if isinstance(value, list) and "items" in schema:
        for i, element in enumerate(value):
            errors.extend(validate(schema["items"], element, f"{path}[{i}]"))
    return errors


def main():
    if len(sys.argv) != 3:
        sys.stderr.write("uso: validate_json_schema.py <schema.json> <instance.json>\n")
        return 2
    try:
        with open(sys.argv[1], encoding="utf-8") as fh:
            schema = json.load(fh)
        with open(sys.argv[2], encoding="utf-8") as fh:
            instance = json.load(fh)
    except Exception as exc:
        sys.stderr.write(f"lectura falló: {exc}\n")
        return 2
    errors = validate(schema, instance)
    if errors:
        for err in errors:
            sys.stderr.write(err + "\n")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
