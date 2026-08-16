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

The new tests must detect deterministic drift in both single- and double-precision `asin` and `acos` over their valid input domain. Every registered native `tester3` CTest must compare current results with expectations that are available offline and fixed independently of that invocation. An unchanged build must pass repeatedly, while deliberately altered library results must make every affected scalar, FMA, and vector CTest fail. The expectation format, storage location, and comparison strategy are implementation choices rather than part of the external contract.

The portable scalar tester must run without runtime dependencies on MPFR or GMP.

Extend the deterministic inverse-trigonometric API so that `acos` and `acosf` counterparts are available alongside deterministic `asin` and `asinf` across the same supported vector extensions and ABI conventions. Do not regress the existing `tester`, `tester2`, GNU ABI compatibility targets, or other library entry points.
