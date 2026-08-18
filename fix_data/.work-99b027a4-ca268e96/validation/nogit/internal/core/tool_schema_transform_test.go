package core

import (
	"encoding/json"
	"testing"
)

func TestShouldFlattenSchema_DepthBased(t *testing.T) {
	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"payload": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"file": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"path": map[string]any{"type": "string"},
						},
					},
				},
			},
		},
	}
	if !ShouldFlattenSchema(schema) {
		t.Fatalf("expected schema to require flattening by depth")
	}
}

func TestFlattenSchemaForModel_FlattensPropertiesAndRequired(t *testing.T) {
	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"payload": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"file": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"path": map[string]any{"type": "string"},
							"mode": map[string]any{"type": "string"},
						},
						"required": []string{"path"},
					},
				},
				"required": []string{"file"},
			},
			"force": map[string]any{"type": "boolean"},
		},
		"required":             []string{"payload"},
		"additionalProperties": false,
	}
	out := FlattenSchemaForModel(schema)
	props := out["properties"].(map[string]any)
	if _, ok := props["payload.file.path"]; !ok {
		t.Fatalf("missing flattened key payload.file.path")
	}
	if _, ok := props["payload.file.mode"]; !ok {
		t.Fatalf("missing flattened key payload.file.mode")
	}
	if _, ok := props["force"]; !ok {
		t.Fatalf("missing leaf key force")
	}
	req, ok := coerceStringSlice(out["required"])
	if !ok || len(req) != 1 || req[0] != "payload.file.path" {
		t.Fatalf("unexpected flattened required: %#v", out["required"])
	}
	if ap, _ := out["additionalProperties"].(bool); ap {
		t.Fatalf("expected additionalProperties=false to be preserved")
	}
}

func TestRenestFlatInputForSpec(t *testing.T) {
	spec := ToolSpec{
		Name: "write_file",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"payload": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"file": map[string]any{
							"type": "object",
							"properties": map[string]any{
								"path": map[string]any{"type": "string"},
							},
						},
					},
				},
			},
		},
	}
	raw := `{"payload.file.path":"README.md","payload.file.mode":"0644","force":true}`
	out, changed := RenestFlatInputForSpec(spec, raw)
	if !changed {
		t.Fatalf("expected changed=true")
	}
	var got map[string]any
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("invalid output json: %v", err)
	}
	payload, ok := got["payload"].(map[string]any)
	if !ok {
		t.Fatalf("expected nested payload object: %#v", got["payload"])
	}
	file, ok := payload["file"].(map[string]any)
	if !ok {
		t.Fatalf("expected nested payload.file object: %#v", payload["file"])
	}
	if file["path"] != "README.md" {
		t.Fatalf("unexpected payload.file.path: %#v", file["path"])
	}
	if file["mode"] != "0644" {
		t.Fatalf("unexpected payload.file.mode: %#v", file["mode"])
	}
	if got["force"] != true {
		t.Fatalf("unexpected force: %#v", got["force"])
	}
}
