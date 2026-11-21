#!/usr/bin/env python3
"""Derive an OpenAPI 3.0.3 document from our OpenAPI 3.1 source of truth.

Why: the Go server generator (oapi-codegen) does not support OpenAPI 3.1 yet. The 3.1 files in /api remain
the contract. The 3.0 output is a build artifact (never committed, never edited by hand).

Handles exactly the 3.1 constructs our specs use, and fails loudly on anything else:
  * type: [T, 'null']                 -> type: T, nullable: true
  * oneOf/anyOf: [X, {type: 'null'}]  -> allOf: [X], nullable: true   (or X + nullable for inline schemas)
  * const: v                          -> enum: [v]
  * examples: [a, ...] (in schemas)   -> example: a
  * contentEncoding: base64           -> format: byte
  * contentMediaType: ...             -> format: binary
  * info.license.identifier, info.summary   -> removed
  * securitySchemes of type mutualTLS -> removed (transport-level in 3.0), together with references to them

Usage: downconvert.py <in.openapi.yaml> <out.oas30.yaml>
"""
from __future__ import annotations

import copy
import sys
from typing import Any

import yaml

SCHEMA_CONTAINER_KEYS = {"schema", "items", "additionalProperties", "not"}
SCHEMA_MAP_KEYS = {"properties", "schemas"}
SCHEMA_LIST_KEYS = {"allOf", "oneOf", "anyOf"}


class ConversionError(Exception):
    pass


def is_null_schema(s: Any) -> bool:
    return isinstance(s, dict) and s.get("type") == "null" and len(s) == 1


def convert_schema(s: Any, path: str) -> Any:
    if not isinstance(s, dict):
        return s
    s = dict(s)

    t = s.get("type")
    if isinstance(t, list):
        non_null = [x for x in t if x != "null"]
        if len(non_null) != 1:
            raise ConversionError(f"{path}: multi-type {t} cannot be expressed in 3.0")
        s["type"] = non_null[0]
        if "null" in t:
            s["nullable"] = True
    elif t == "null":
        raise ConversionError(f"{path}: standalone null schema")

    for key in ("oneOf", "anyOf"):
        if key in s:
            variants = s[key]
            nulls = [v for v in variants if is_null_schema(v)]
            rest = [v for v in variants if not is_null_schema(v)]
            if nulls:
                del s[key]
                if len(rest) == 1:
                    inner = convert_schema(rest[0], f"{path}/{key}/0")
                    if "$ref" in inner:
                        s["allOf"] = [inner]
                    else:
                        s.update(inner)
                    s["nullable"] = True
                else:
                    s[key] = [convert_schema(v, f"{path}/{key}/{i}") for i, v in enumerate(rest)]
                    s["nullable"] = True

    if "const" in s:
        s["enum"] = [s.pop("const")]
    if "examples" in s and isinstance(s["examples"], list):
        ex = s.pop("examples")
        if ex:
            s["example"] = ex[0]
    if s.pop("contentEncoding", None) == "base64":
        s.setdefault("format", "byte")
    if s.pop("contentMediaType", None) is not None:
        s.setdefault("format", "binary")

    for k in list(s.keys()):
        v = s[k]
        if k in SCHEMA_CONTAINER_KEYS and isinstance(v, dict):
            s[k] = convert_schema(v, f"{path}/{k}")
        elif k in SCHEMA_MAP_KEYS and isinstance(v, dict):
            s[k] = {pk: convert_schema(pv, f"{path}/{k}/{pk}") for pk, pv in v.items()}
        elif k in SCHEMA_LIST_KEYS and isinstance(v, list):
            s[k] = [convert_schema(x, f"{path}/{k}/{i}") for i, x in enumerate(v)]
    return s


def walk(node: Any, path: str) -> Any:
    """Find every place a schema can appear and convert it."""
    if isinstance(node, dict):
        out = {}
        for k, v in node.items():
            p = f"{path}/{k}"
            if k == "schema" and isinstance(v, dict):
                out[k] = convert_schema(v, p)
            elif k == "schemas" and path.endswith("/components") and isinstance(v, dict):
                out[k] = {n: convert_schema(sv, f"{p}/{n}") for n, sv in v.items()}
            else:
                out[k] = walk(v, p)
        return out
    if isinstance(node, list):
        return [walk(v, f"{path}[{i}]") for i, v in enumerate(node)]
    return node


def strip_security(doc: dict) -> None:
    schemes = doc.get("components", {}).get("securitySchemes", {})
    removed = {n for n, s in schemes.items() if s.get("type") == "mutualTLS"}
    for n in removed:
        del schemes[n]

    def clean(reqs: list | None) -> list | None:
        if reqs is None:
            return None
        cleaned = [{k: v for k, v in r.items() if k not in removed} for r in reqs]
        return [r for r in cleaned if r] or ([] if reqs else reqs)

    if "security" in doc:
        doc["security"] = clean(doc["security"])
    for item in doc.get("paths", {}).values():
        for method, op in item.items():
            if isinstance(op, dict) and "security" in op:
                op["security"] = clean(op["security"])


def fill_nullable_ref_types(doc: dict) -> None:
    """OAS 3.0.3 requires `type` next to `nullable`. Copy it from the referenced component for allOf-wrapped refs."""
    components = doc.get("components", {}).get("schemas", {})

    def resolve_type(ref: str) -> str:
        prefix = "#/components/schemas/"
        if not ref.startswith(prefix) or ref[len(prefix):] not in components:
            raise ConversionError(f"cannot resolve {ref}")
        target = components[ref[len(prefix):]]
        if "type" in target:
            return target["type"]
        if "allOf" in target:
            return "object"
        raise ConversionError(f"{ref} has no type; cannot mark nullable in 3.0")

    def visit(node: Any) -> None:
        if isinstance(node, dict):
            if node.get("nullable") and "type" not in node:
                refs = [x["$ref"] for x in node.get("allOf", []) if isinstance(x, dict) and "$ref" in x]
                if len(refs) != 1:
                    raise ConversionError(f"nullable schema without type: {node}")
                node["type"] = resolve_type(refs[0])
            for v in node.values():
                visit(v)
        elif isinstance(node, list):
            for v in node:
                visit(v)

    visit(doc)


def downconvert(src: dict) -> dict:
    if not str(src.get("openapi", "")).startswith("3.1"):
        raise ConversionError("input is not OpenAPI 3.1")
    doc = copy.deepcopy(src)
    doc["openapi"] = "3.0.3"
    doc.get("info", {}).pop("summary", None)
    doc.get("info", {}).get("license", {}).pop("identifier", None)
    strip_security(doc)
    doc = walk(doc, "#")
    fill_nullable_ref_types(doc)
    doc.pop("webhooks", None)
    doc.pop("jsonSchemaDialect", None)
    return doc


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as f:
        src = yaml.safe_load(f)
    try:
        out = downconvert(src)
    except ConversionError as e:
        print(f"downconvert: {e}", file=sys.stderr)
        return 1
    with open(argv[2], "w", encoding="utf-8") as f:
        f.write("# GENERATED from " + argv[1] + " by tools/openapi/downconvert.py. DO NOT EDIT.\n")
        yaml.safe_dump(out, f, sort_keys=False, allow_unicode=True, width=120)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
