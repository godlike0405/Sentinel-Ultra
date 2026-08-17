SLEEF needs fast numerical regression coverage that remains useful in builds without an arbitrary-precision reference library. Add a `tester3` family that allows deterministic validation of library results across builds while preserving the behavior of the existing testers.

Every enabled vector extension for which this tester is supported must have a corresponding `tester3<extension>` executable registered with CTest and linked to `libsleef`. An x86 build must expose these tests:

- `tester3purec_scalar`
- `tester3purecfma_scalar`
- `tester3sse2`
- `tester3sse4`
- `tester3avx`
- `tester3avx2128`
- `tester3avx2`
- `tester3avx512f`
- `tester3avx512fnofma`

Cross-configuring the project must expose `tester3purec_scalar` and `tester3purecfma_scalar` for ARM32; `tester3advsimd`, `tester3advsimdnofma`, `tester3sve`, and `tester3svenofma` for AArch64; and `tester3vsx` and `tester3vsxnofma` for PPC64.

For every native extension the host can execute, the new tests must detect deterministic drift in both single- and double-precision `asin` and `acos` throughout their full valid input domain, independently for the existing 3.5-ULP and 1.0-ULP accuracy tiers. Each combination of operation, precision, and accuracy tier must make at least 1,000 in-domain calls whose inputs include both signs, values below `-0.9`, values above `0.9`, values between `-0.1` and `0.1`, and at least 24 of 32 equal-width intervals across `[-1, 1]`. Every such `tester3` CTest must compare current results with expectations that are available offline and fixed independently of that invocation. Its verdict must therefore remain unchanged if the host's ambient reference-math results change while `libsleef` does not. An unchanged build must pass repeatedly, while deliberately altering any one operation, precision, or accuracy tier in `libsleef` must make every affected scalar, FMA, and vector CTest fail. The expectation encoding and comparison strategy are implementation choices rather than part of the external contract.

Each host-runnable tester must support a reproducible expectation-snapshot lifecycle. Invoking it without a snapshot must emit a complete snapshot to standard output, and supplying one snapshot as its sole argument must validate against it. Snapshot output must be byte-for-byte stable across repeated invocations. A read-only snapshot produced by a target must validate that target without being modified. Distinct deterministic result families may have distinct offline expectations. Validation must consume the complete snapshot and fail with a nonzero status for incomplete or corrupted data, non-whitespace trailing content, or extra command-line arguments.

When the host cannot execute an extension's required instruction set, that extension's registered `tester3` CTest is not required to perform the saved-result comparison or domain sweep, but it must finish successfully without crashing.

The portable scalar and scalar FMA tests must build, remain registered with CTest, and pass both in the normal shared-library configuration and when `libsleef` is built statically in a configuration without MPFR, GMP, or OpenSSL. Their executables must not acquire runtime dependencies on those libraries in the dependency-free static configuration, and both configurations must accept unchanged library results.

The portable scalar tester must run without runtime dependencies on MPFR or GMP.

Complete the existing deterministic inverse-trigonometric function family: wherever the generated public SLEEF ABI provides a deterministic `asin` or `asinf` variant, it must also provide the matching `acos` or `acosf` counterpart with the same precision, vector width, accuracy, extension, and calling conventions. Do not regress the existing `tester`, `tester2`, GNU ABI compatibility targets, or other library entry points.
