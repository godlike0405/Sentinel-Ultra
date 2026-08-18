package core

import (
	"encoding/json"
	"sort"
	"strings"
)

// ShouldFlattenSchema reports whether a tool schema is deep/wide enough to
// benefit from flattened argument keys for model-side tool calling.
func ShouldFlattenSchema(parameters map[string]any) bool {
	leafCount, maxDepth := schemaStats(parameters, 1)
	return leafCount > 10 || maxDepth > 2
}

// FlattenSchemaForModel flattens nested object properties into dotted keys
// (for example: payload.path) to reduce nested JSON generation errors.
func FlattenSchemaForModel(parameters map[string]any) map[string]any {
	if parameters == nil {
		return nil
	}
	if !ShouldFlattenSchema(parameters) {
		return deepCopyMap(parameters)
	}
	propsAny, _ := parameters["properties"].(map[string]any)
	flatProps := map[string]any{}
	required := []string{}
	seenReq := map[string]bool{}
	rootReqSet := requiredSet(parameters["required"])

	var walk func(prefix string, prop map[string]any, forceRequired bool)
	walk = func(prefix string, prop map[string]any, forceRequired bool) {
		tp, _ := prop["type"].(string)
		childProps, hasProps := prop["properties"].(map[string]any)
		if tp == "object" && hasProps && len(childProps) > 0 {
			childReqSet := requiredSet(prop["required"])
			for key, childAny := range childProps {
				child, ok := childAny.(map[string]any)
				if !ok {
					continue
				}
				name := key
				if prefix != "" {
					name = prefix + "." + key
				}
				walk(name, child, forceRequired && childReqSet[key])
			}
			return
		}
		flatProps[prefix] = deepCopyMap(prop)
		if forceRequired && !seenReq[prefix] {
			seenReq[prefix] = true
			required = append(required, prefix)
		}
	}

	for key, childAny := range propsAny {
		child, ok := childAny.(map[string]any)
		if !ok {
			continue
		}
		walk(key, child, rootReqSet[key])
	}
	sort.Strings(required)

	out := map[string]any{
		"type":                 "object",
		"properties":           flatProps,
		"additionalProperties": parameters["additionalProperties"],
	}
	if len(required) > 0 {
		out["required"] = required
	}
	if _, ok := out["additionalProperties"]; !ok {
		out["additionalProperties"] = true
	}
	return out
}

// RenestFlatInputForSpec turns dotted keys back into nested objects when the
// tool schema is flattened for model interaction.
func RenestFlatInputForSpec(spec ToolSpec, raw string) (string, bool) {
	if strings.TrimSpace(raw) == "" || !ShouldFlattenSchema(spec.Parameters) {
		return raw, false
	}
	var in map[string]any
	if err := json.Unmarshal([]byte(raw), &in); err != nil {
		return raw, false
	}
	if len(in) == 0 {
		return raw, false
	}
	out := map[string]any{}
	changed := false
	for k, v := range in {
		if !strings.Contains(k, ".") {
			out[k] = v
			continue
		}
		parts := strings.Split(k, ".")
		if len(parts) < 2 {
			out[k] = v
			continue
		}
		changed = true
		cur := out
		conflict := false
		for i := 0; i < len(parts)-1; i++ {
			p := parts[i]
			next, ok := cur[p]
			if !ok {
				m := map[string]any{}
				cur[p] = m
				cur = m
				continue
			}
			m, ok := next.(map[string]any)
			if !ok {
				conflict = true
				break
			}
			cur = m
		}
		if conflict {
			changed = false
			out[k] = v
			continue
		}
		cur[parts[len(parts)-1]] = v
	}
	if !changed {
		return raw, false
	}
	b, err := json.Marshal(out)
	if err != nil {
		return raw, false
	}
	return string(b), true
}

func schemaStats(schema map[string]any, depth int) (leafCount int, maxDepth int) {
	if schema == nil {
		return 0, depth
	}
	maxDepth = depth
	propsAny, _ := schema["properties"].(map[string]any)
	if len(propsAny) == 0 {
		return 0, maxDepth
	}
	for _, v := range propsAny {
		prop, ok := v.(map[string]any)
		if !ok {
			leafCount++
			continue
		}
		tp, _ := prop["type"].(string)
		childProps, hasProps := prop["properties"].(map[string]any)
		if tp == "object" && hasProps && len(childProps) > 0 {
			l, d := schemaStats(prop, depth+1)
			leafCount += l
			if d > maxDepth {
				maxDepth = d
			}
			continue
		}
		leafCount++
	}
	return leafCount, maxDepth
}

func requiredSet(v any) map[string]bool {
	out := map[string]bool{}
	req, ok := coerceStringSlice(v)
	if !ok {
		return out
	}
	for _, r := range req {
		out[r] = true
	}
	return out
}

func deepCopyMap(in map[string]any) map[string]any {
	if in == nil {
		return nil
	}
	out := make(map[string]any, len(in))
	for k, v := range in {
		switch tv := v.(type) {
		case map[string]any:
			out[k] = deepCopyMap(tv)
		case []any:
			cp := make([]any, len(tv))
			for i := range tv {
				if m, ok := tv[i].(map[string]any); ok {
					cp[i] = deepCopyMap(m)
				} else {
					cp[i] = tv[i]
				}
			}
			out[k] = cp
		default:
			out[k] = v
		}
	}
	return out
}
