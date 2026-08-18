# Make Story navigation coordinate-safe

Story view sometimes opens or scrolls to the wrong chapter when a comment or renderer anchor refers to a diff line. The problem is most visible after deletions shift the new-side numbering, when nearby hunks are displayed as one visual block, and when switching between split and unified diff modes.

Update Story navigation so that these user-visible rules hold:

- Line anchors retain their old/new side and comment scope from creation through chapter selection and scrolling. `anchorFromComment` must continue returning the established line-anchor fields and also carry `side` and `scope`; a file-scoped anchor has no invented side.
- An explicitly old-side coordinate is matched only in the old coordinate space, and an explicitly new-side coordinate is matched only in the new coordinate space. Existing side-less callers remain compatible by preferring a new-side match and then trying the old side.
- When adjacent hunks are shown as one visual block, navigation must still open the chapter containing the original changed line. Context displayed between those hunks is attributed to the preceding change. This must hold for both automatic small-gap expansion and gaps expanded to reveal comments.
- Unified view scrolls old-side context to the single context row rendered for the new side, while deleted rows keep their old-side identity. Split view keeps distinct old-side rows. Additions and new-side context continue using the rendered new-side row.
- File-scoped comments and file anchors activate the first Story chapter containing that file instead of routing through a fabricated line number. An explicit-side line that has no matching hunk must not jump to a file-level fallback; the legacy side-less path may retain that fallback.
- Comment-card navigation and the registered renderer must preserve these rules end to end, including the final DOM row selected for scrolling.
- After a scope, base, or commit change, Story rendering and navigation must use the newly loaded diff data even when the file content hash is unchanged.
- Keep the existing browser renderer registration contract and non-Story behavior compatible.

Finally, make both the npm and Bun lockfiles select `markdown-it` 14.3.0 and `mermaid` 11.16.0. Regenerate `web/markdown-it.min.js` and `web/mermaid.min.js` so each is byte-for-byte the published distribution artifact for that exact version. The result must remain reproducible and must not require network access at runtime.

Do not modify existing test files.
