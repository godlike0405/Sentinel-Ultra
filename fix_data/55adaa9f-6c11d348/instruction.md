# Add semantic runtime transforms for Specta types

Specta describes Rust data accurately in TypeScript, but JSON-decoded values still have their wire representation. Add a `specta-tags` workspace crate that analyzes Specta type graphs and provides the JavaScript or TypeScript needed to reconstruct semantic runtime values. The crate must recognize signed and unsigned 64- and 128-bit integers (`i64`, `u64`, `i128`, and `u128`) as `BigInt`, configured date types as `Date`, and configured byte types as `Uint8Array`; other primitive types remain unchanged.

The root API and `specta_tags::v2` API below are compatibility surfaces. Their names, signatures, enum variants, and serialized protocol are required; internal modules and implementation strategy are not.

```rust
use std::borrow::Cow;
use specta::{Types, datatype::{DataType, GenericReference}};

pub enum SemanticKind { Date, Bytes }
pub enum RuntimeTarget { TypeScript, JavaScript }
pub struct Analyzer { /* opaque configuration */ }
pub struct RuntimeRequirements { /* opaque requirement set */ }

impl Analyzer {
    pub fn with_builtins() -> Self;
    pub fn with_named_type(
        self,
        module_path: impl Into<Cow<'static, str>>,
        name: impl Into<Cow<'static, str>>,
        kind: SemanticKind,
    ) -> Self;
    pub fn with_list_u8_is_bytes(self, enabled: bool) -> Self;
    pub fn analyze(
        &self,
        dt: &DataType,
        types: &Types,
        generics: &[(GenericReference, DataType)],
    ) -> TransformSpec;
}

pub enum TransformSpec {
    Identity,
    BigInt,
    Date,
    Bytes,
    Nullable(Box<TransformSpec>),
    List(Box<TransformSpec>),
    Tuple(Vec<TransformSpec>),
    Object(Vec<(String, TransformSpec)>),
    Map(Box<TransformSpec>),
    Enum(Vec<EnumVariantTransformSpec>),
}
pub struct EnumVariantTransformSpec {
    pub name: String,
    pub kind: EnumVariantTransformKind,
    pub spec: TransformSpec,
}
pub enum EnumVariantTransformKind { Unit, Named, Unnamed }
impl TransformSpec { pub fn to_json(&self) -> String; }

impl RuntimeRequirements {
    pub fn from_specs<'a>(specs: impl IntoIterator<Item = &'a TransformSpec>) -> Self;
    pub fn with_result_helper(self, enabled: bool) -> Self;
}
pub fn render_runtime(
    target: RuntimeTarget,
    requirements: &RuntimeRequirements,
) -> Cow<'static, str>;
pub const RUNTIME_RESERVED_NAMES: &[&str];

impl specta_tags::v2::TransformPlan {
    pub fn analyze(dt: DataType, types: &Types) -> Self;
    pub fn map<'a>(&self, input: &'a str) -> Cow<'a, str>;
}
```

`Analyzer` and `RuntimeRequirements` also implement `Default`. `Analyzer::with_builtins()` enables the standard mappings listed below. `with_named_type` adds a mapping selected by both the complete module path and type name, and `with_list_u8_is_bytes` controls whether `List<u8>` is treated as bytes. Analysis must handle primitive, named, generic, nullable, list, tuple, object, map, enum, and recursive type graphs without recursing forever.

`TransformSpec::to_json` is a compact public protocol. Identity, bigint, date, and bytes are encoded as `0`, `1`, `2`, and `3`. Nullable, list, tuple, object, map, and enum specs are encoded as `[4, inner]`, `[5, inner]`, `[6, items]`, `[7, fields]`, `[8, inner]`, and `[9, variants]`. Object entries are `[name, spec]`. Enum entries are `[name, kind, spec]`, with kind codes `0`, `1`, and `2` for unit, named, and unnamed variants.

`RuntimeRequirements::from_specs` determines which conversion cases the generated runtime contains. With no requirements, `render_runtime` returns an empty string; conversions not requested by the requirements remain inactive. JavaScript output must execute directly in Node.js. TypeScript output must compile under strict TypeScript targeting ES2020 and perform the same conversions.

For an active leaf conversion, decimal integer strings and integer JavaScript numbers become `BigInt`; strings accepted as valid by JavaScript's `Date` constructor become `Date`; and arrays containing only integer octets from 0 through 255 become `Uint8Array`. Values of the wrong runtime kind, invalid integer or date strings, and byte arrays containing non-integers or out-of-range values are returned unchanged instead of throwing. Containers supplied with the wrong array/object kind are likewise unchanged. Valid nested values are transformed recursively while unrelated object fields and map keys are preserved.

Generated helpers are top-level declarations in the returned source, not module exports. Their public call forms are `__TS_transform(value, spec)`, `__TS_transformEnum(value, variants)`, and `__TS_transformResult(resultPromise, okSpec, errorSpec)`. The enum helper is emitted when an enum transform is required. `with_result_helper(true)` emits the result helper, including when no other conversion was requested; it accepts a promise resolving to either `{ status: "ok", data: T }` or `{ status: "error", error: E }`, transforms `data` or `error` with the corresponding spec, and preserves the envelope. `RUNTIME_RESERVED_NAMES` exposes those three identifiers in the same order.

`v2::TransformPlan::analyze` always uses the built-in mapping table below. It builds a reusable plan, and `map` returns a JavaScript expression using the caller-supplied input expression. For valid values conforming to the analyzed Specta wire shape, it applies the same leaf conversions through nested structs, generic and named references, nullable values, lists, tuples, maps, and externally, internally, and adjacently tagged enums. This surface intentionally emits trusting expressions: the malformed-value fallback guarantees of `render_runtime` do not apply to `v2::map`. Analysis of a recursive graph must terminate; fields reached before a cyclic back-reference are transformed, while the back-reference itself is left unchanged. Untagged enums remain unchanged because their variants have no discriminator. An identity-only graph returns the caller's exact input expression.

The built-in date mappings are `std::time::SystemTime`, `toml::value::Datetime`, `chrono::{NaiveDateTime, NaiveDate, Date, DateTime}`, `time::{PrimitiveDateTime, OffsetDateTime, Date}`, `jiff::{Timestamp, Zoned}`, `jiff::civil::{Date, DateTime}`, and `bson::DateTime`. The built-in byte mappings are `bytes::{Bytes, BytesMut}`. A matching short type name in any other module must not activate a built-in mapping.

Integrate `specta-tags` as a workspace member. Its development dependencies must support Specta derives and the `chrono` and `bytes` types needed to exercise both APIs.
