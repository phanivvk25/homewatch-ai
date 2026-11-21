"""Tests for downconvert.py. Run: python3 -m unittest discover -s tools/openapi"""
import pathlib
import unittest

import yaml

from downconvert import ConversionError, downconvert

ROOT = pathlib.Path(__file__).resolve().parents[2]


def base(schemas: dict, **extra) -> dict:
    doc = {
        "openapi": "3.1.0",
        "info": {"title": "t", "version": "1", "summary": "s", "license": {"name": "x", "identifier": "MIT"}},
        "paths": {},
        "components": {"schemas": schemas},
    }
    doc.update(extra)
    return doc


class DownconvertTest(unittest.TestCase):
    def test_type_array_with_null_becomes_nullable(self):
        out = downconvert(base({"A": {"type": ["string", "null"], "maxLength": 3}}))
        self.assertEqual(out["components"]["schemas"]["A"], {"type": "string", "nullable": True, "maxLength": 3})

    def test_multi_type_without_null_is_rejected(self):
        with self.assertRaises(ConversionError):
            downconvert(base({"A": {"type": ["string", "integer"]}}))

    def test_oneof_ref_or_null_becomes_typed_nullable_allof(self):
        out = downconvert(base({
            "B": {"type": "object"},
            "A": {"type": "object", "properties": {
                "b": {"oneOf": [{"$ref": "#/components/schemas/B"}, {"type": "null"}]}}},
        }))
        self.assertEqual(out["components"]["schemas"]["A"]["properties"]["b"],
                         {"allOf": [{"$ref": "#/components/schemas/B"}], "nullable": True, "type": "object"})

    def test_const_examples_and_encodings(self):
        out = downconvert(base({"A": {"type": "object", "properties": {
            "c": {"type": "string", "const": "DELETE"},
            "e": {"type": "string", "examples": ["x", "y"]},
            "b": {"type": "string", "contentEncoding": "base64"},
            "z": {"type": "string", "contentMediaType": "application/zip"},
        }}}))
        p = out["components"]["schemas"]["A"]["properties"]
        self.assertEqual(p["c"], {"type": "string", "enum": ["DELETE"]})
        self.assertEqual(p["e"], {"type": "string", "example": "x"})
        self.assertEqual(p["b"], {"type": "string", "format": "byte"})
        self.assertEqual(p["z"], {"type": "string", "format": "binary"})

    def test_info_and_mutual_tls_are_stripped(self):
        doc = base({}, security=[{"mtls": []}])
        doc["components"]["securitySchemes"] = {"mtls": {"type": "mutualTLS"}, "oidc": {"type": "openIdConnect",
                                                                                     "openIdConnectUrl": "https://x"}}
        doc["paths"] = {"/a": {"get": {"security": [{"mtls": []}, {"oidc": []}], "responses": {}}}}
        out = downconvert(doc)
        self.assertEqual(out["openapi"], "3.0.3")
        self.assertNotIn("summary", out["info"])
        self.assertNotIn("identifier", out["info"]["license"])
        self.assertEqual(list(out["components"]["securitySchemes"]), ["oidc"])
        self.assertEqual(out["paths"]["/a"]["get"]["security"], [{"oidc": []}])
        self.assertEqual(out["security"], [])

    def test_rejects_non_31_input(self):
        with self.assertRaises(ConversionError):
            downconvert({"openapi": "3.0.3"})

    def test_real_specs_convert_without_31_constructs(self):
        for name in ("agent", "cloud"):
            src = yaml.safe_load((ROOT / "api" / f"{name}.openapi.yaml").read_text(encoding="utf-8"))
            out = downconvert(src)
            text = yaml.safe_dump(out)
            self.assertNotIn("'null'", text, name)
            self.assertNotIn("const:", text, name)
            self.assertNotIn("contentEncoding", text, name)
            self.assertNotIn("mutualTLS", text, name)


if __name__ == "__main__":
    unittest.main()
