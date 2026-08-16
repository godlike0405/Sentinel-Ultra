# Preserve per-parameter-set help metadata

PlatyPS currently flattens a PowerShell parameter's help metadata into one position, requiredness value, and pipeline-input value. That representation loses information whenever the parameter behaves differently across parameter sets, and the loss carries through Markdown generation, Markdown import, and YAML export.

Update the command-help schema and round-trip behavior so that parameter metadata remains accurate for every parameter set.

## Required behavior

- A parameter exposed on a `CommandHelp` object must retain its `Name`, `Type`, `Description`, `Aliases`, and boolean `Globbing` value. Its `ParameterSets` property must be a collection of structured entries rather than a list of names.
- Every parameter-set entry must expose:
  - `Name`
  - `Position`
  - `IsRequired`
  - `ValueByPipeline`
  - `ValueByPipelineByPropertyName`
  - `ValueFromRemainingArguments`
- A parameter may have different values for those fields in three or more parameter sets. Keep every association independent; do not collapse entries, duplicate them, or transfer flags between sets when help is imported, exported, and imported again.
- When a parameter applies to every parameter set, normalize it to the established all-sets display convention used by existing PlatyPS documents.
- `New-MarkdownHelp` output must be directly consumable by `Import-MarkdownCommandHelp` without requiring callers to supply metadata manually. A generated-and-imported command must preserve all syntax entries, its source module name, its declared default parameter set (with exactly one syntax entry marked as default when the command declares one), and parameter aliases.
- When one `New-MarkdownHelp` invocation generates several commands, each output file must receive metadata for its own command and module. Caller-supplied metadata is merged independently into every output without mutating the caller's hashtable or allowing generated identity fields from one command to leak into another.
- A `CommandHelp` value returned by `Import-MarkdownCommandHelp` must be accepted by `Export-MarkdownCommandHelp` and remain stable through subsequent Markdown export/import cycles.
- Preserve parameter descriptions through the Markdown round trip when they come from comment-based `.PARAMETER` help or a `HelpMessage`. An undocumented parameter uses the existing `{{ Fill <ParameterName> Description }}` placeholder.
- Write wildcard support as the boolean Markdown metadata field `Globbing`; for a parameter decorated with `SupportsWildcards`, the emitted line is `Globbing: true`. Newly generated help must not also emit the deprecated wildcard-support metadata format.
- Keep the Markdown reader compatible with existing documents that use the older flat parameter metadata block. Migrating such a document through import, structured Markdown export, and re-import must preserve set-specific requiredness, position, and pipeline modes, and the new output must not fall back to deprecated flat fields.

## YAML contract

The parameter collection written by `Export-YamlCommandHelp` must use the new schema. Each exported parameter is a map containing the parameter-level fields and a nested `parameterSets` sequence. Entries in that sequence use the camel-case forms of the six parameter-set fields above. The old top-level `position` and `pipelineInput` fields must not be emitted for parameters using the new schema. YAML produced by the exporter must remain readable through the existing path-based `Import-YamlCommandHelp` API. That API retains its generic-map return shape; the returned map must expose the nested parameter-set flags and the `globbing` value.

Existing command selection, output-folder handling, caller-supplied metadata, `NoMetadata`, and the standard Markdown section layout must continue to behave as before. Unknown commands must still produce an error.
