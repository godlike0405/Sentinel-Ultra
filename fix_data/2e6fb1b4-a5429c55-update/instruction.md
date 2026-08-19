# Make Story navigation coordinate-safe

Story view sometimes opens or scrolls to the wrong chapter when a comment or renderer anchor refers to a diff line in certain diff contexts.

Update Story navigation so that these user-visible rules hold:

- Comment and renderer navigation must preserve whether a target refers to a whole file or a line and, for a line, whether it uses the old or new diff coordinate. That meaning must survive chapter selection and scrolling; a file-level target must not acquire a line side.
- Explicit old- and new-side coordinates must navigate only to the corresponding changed content. Callers that do not specify a side must remain backward-compatible.
- When adjacent hunks are shown as one visual block, navigation must open the chapter containing the original changed line, regardless of why the block was consolidated.
- In split and unified views, navigation to old-side context, deletions, additions, and new-side context must land on the correct visible line.
- File-scoped comments and renderer navigation activate the first Story chapter containing the file. Navigation to an explicit line coordinate that cannot be located must fail gracefully instead of opening an unrelated chapter.
- Comment-card navigation and the registered renderer must preserve these outcomes end to end.
- Story rendering and navigation must reflect the current diff after any scope, base, or commit change.
- Keep the existing browser renderer registration contract and non-Story behavior compatible.

Finally, make both the npm and Bun lockfiles select `markdown-it` 14.3.0 and `mermaid` 11.16.0. The bundled browser runtimes for those dependencies must match the officially published releases for those exact versions. The result must remain reproducible and must not require network access at runtime.

Do not modify existing test files.
