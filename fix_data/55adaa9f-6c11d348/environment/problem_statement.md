# Add semantic runtime transforms for Specta types

Specta can describe Rust data in TypeScript, but decoded JSON still contains wire-format values. Large Rust integers need to become JavaScript `BigInt` values, date-like values need to become `Date` objects, and byte buffers need to become `Uint8Array` instances. Add a new `specta-tags` workspace crate that can analyze a Specta type graph and generate the runtime support needed to perform those conversions.

The crate should use Rust 2024 and expose two related APIs. Its root API is a reusable semantic analysis and runtime-generation layer. `Analyzer` must support the built-in named types below, caller-supplied module/name matchers through `with_named_type`, and opt-in treatment of `List<u8>` as bytes through `with_list_u8_is_bytes`. `Analyzer::analyze` returns a public `TransformSpec` and must traverse primitives, named and generic references, nullable values, lists, tuples, objects, maps, enums, and recursive graphs without looping. The public semantic types are `SemanticKind`, `TransformSpec`, `EnumVariantTransformSpec`, and `EnumVariantTransformKind`.

`TransformSpec::to_json` is a compact wire format. Identity, bigint, date, and bytes use `0`, `1`, `2`, and `3`. Composite values use `[4, inner]` for nullable, `[5, inner]` for lists, `[6, items]` for tuples, `[7, fields]` for objects, `[8, inner]` for maps, and `[9, variants]` for enums. Each object field is `[name, spec]`; each enum variant is `[name, kind, spec]`, where unit, named, and unnamed variants use kind codes `0`, `1`, and `2`.

`RuntimeRequirements::from_specs` must collect only the helpers required by its input specs. `render_runtime(RuntimeTarget, &requirements)` returns an empty string when nothing is required and otherwise emits a minimal JavaScript or TypeScript runtime: JavaScript output must not contain TypeScript syntax, while TypeScript output includes its transform-spec types. `with_result_helper(true)` adds promise-result conversion for both success and error payloads even when no general transform was requested. The generated runtime is defensive about malformed values. Reserve `__TS_transform`, `__TS_transformEnum`, and `__TS_transformResult` through the public `RUNTIME_RESERVED_NAMES` constant.

The second API is `v2::TransformPlan`. `TransformPlan::analyze(DataType, &Types)` owns the root datatype and builds a direct JavaScript transformation plan. `plan.map(input)` accepts any caller-supplied input expression and returns the expression that transforms it. It must cover nested structs, generic and named references, nullable values, lists, tuples, maps, recursive graphs, and externally, internally, and adjacently tagged enums. Tagged enums may branch on their declared discriminator or variant property. Untagged enums have no trustworthy discriminator, so they remain unchanged.

The direct v2 expressions are deliberately trusting: they assume the decoded value already has the declared shape. They may use `== null` for nullable values and discriminator conditions for tagged enums, but must not emit runtime type/shape validation. In particular, v2 output must never contain `typeof `, `Array.isArray(`, `Number.isInteger(`, `try {`, or ` catch `. Apply leaf conversions directly:

- `i64`, `u64`, `i128`, and `u128` become `BigInt(input)`.
- Date-like named types become `new Date(input)`.
- Byte-like named types become `Uint8Array.from(input)`.

Date matching covers `std::time::SystemTime`, `toml::value::Datetime`, `chrono::{NaiveDateTime, NaiveDate, Date, DateTime}`, `time::{PrimitiveDateTime, OffsetDateTime, Date}`, `jiff::{Timestamp, Zoned}`, `jiff::civil::{Date, DateTime}`, and `bson::DateTime`. Byte matching covers `bytes::{Bytes, BytesMut}`. Both module path and type name must match; an unrelated type with the same short name remains unchanged.

For a transformed object, preserve unmodified fields by spreading the original value and override only fields whose plans are non-identity. Use JSON string-literal keys in the object literal and bracket notation with JSON-encoded keys for every field access. Lists map their elements, tuples transform their indexed positions, maps transform their values while retaining keys, and nullable values preserve `null` and `undefined`. If an entire type graph is identity-only, `map` must return the exact input expression unchanged.

Add `specta`, `specta-serde`, `serde`, and `serde_json` as crate dependencies. The crate's development setup must support derived Specta types plus the `chrono` and `bytes` types used to exercise the public behavior.
