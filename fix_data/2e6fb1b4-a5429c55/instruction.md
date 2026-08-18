# Make Story navigation coordinate-safe

Story view sometimes opens or scrolls to the wrong chapter when a comment or renderer anchor refers to a diff line. The problem is most visible after deletions shift the new-side numbering, when nearby hunks are displayed as one visual block, and when switching between split and unified diff modes.

Update Story navigation so that these user-visible rules hold:

- Line anchors retain their old/new side and comment scope from creation through chapter selection and scrolling. `anchorFromComment` must continue returning the established line-anchor fields and also carry `side` and `scope`; a file-scoped anchor has no invented side.
- An explicitly old-side coordinate is matched only in the old coordinate space, and an explicitly new-side coordinate is matched only in the new coordinate space. Existing side-less callers remain compatible by preferring a new-side match and then trying the old side.
- Combining adjacent hunks for display must not lose which original hunk owns each changed line. Context synthesized between two hunks belongs to the preceding original hunk. This ownership must survive both automatic small-gap expansion and comment-driven gap expansion.
- Unified view scrolls old-side context to the single context row rendered for the new side, while deleted rows keep their old-side identity. Split view keeps distinct old-side rows. Additions and new-side context continue using the rendered new-side row.
- File-scoped comments and file anchors activate the first Story chapter containing that file instead of routing through a fabricated line number. An explicit-side line that has no matching hunk must not jump to a file-level fallback; the legacy side-less path may retain that fallback.
- Comment-card navigation and the registered renderer must preserve these rules end to end, including the final DOM row selected for scrolling.
- A scope, base, or commit reload must discard cached Story file clones before replacement file data is loaded, even when file contents hash to the same value.
- Keep the existing browser renderer registration contract and non-Story behavior compatible.

The browser integration uses these Story helper names as its compatibility surface: `storyRawHunks`, `storyRawHunksWithTrailingContext`, `storyRawHunkForLine`, `storyDisplayAnchorForLine`, `storyPageForFile`, `storyPageForLine`, `storyActivatePageForFile`, and `storyActivatePageForLine`.

Finally, keep the npm and Bun lockfiles aligned on the selected Markdown and diagram dependency versions, and regenerate the embedded runtimes so `web/markdown-it.min.js` and `web/mermaid.min.js` are byte-for-byte the corresponding artifacts. The result must remain reproducible and must not require network access at runtime.

Do not modify existing test files.
