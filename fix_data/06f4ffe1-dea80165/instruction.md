# Make honeyfs session views memory-efficient

Cowrie consumes too much memory when many short-lived SSH or Telnet sessions are active. Most of these sessions only inspect a few files, yet their filesystem overhead grows with the complete honeyfs. Bring that overhead down while preserving the filesystem view users already see.

Each session must behave as an independent view of the honeyfs. A session captures the `[honeypot] contents_path` in effect when it is created and keeps a stable snapshot of the regular files and metadata found there. Later edits, replacements, or removals in the host directory must not change that session, while a later session sees the operator files available when its own view is created. Applying an operator contents directory to an existing session must likewise affect only that session. Entries that are not actual regular files within that directory must not expose host data through the virtual filesystem.

Regular files supplied through an operator contents directory must appear at their corresponding virtual paths even when those paths are absent from the bundled honeyfs; create any virtual parent directories needed to expose them. Applying a different contents directory to an existing view reconciles the replacement with the session rather than resetting the view. Session-created, replaced, moved, removed, or metadata-modified paths take precedence over conflicting operator files. Untouched operator-only paths from the earlier directory disappear, untouched bundled files omitted by the replacement return to their bundled contents, and new operator paths appear wherever the session has not claimed that path. Repeating this process must not resurrect a session deletion or discard a session-owned move. Other sessions keep their original snapshots and changes.

That view must remain coherent when files are changed. In particular, renaming an operator-backed file moves both the virtual entry and the bytes it exposes to the destination path in that session. The old path disappears, while concurrent and later sessions retain their own configured file, contents, and path. The same isolation rule applies to file and directory creation or removal and to permission, ownership, timestamp, and size changes, whether invoked through the filesystem object, shell commands, or SFTP.

Use this measurable memory target: after creating one session to warm configuration and filesystem data, retain 12 more sessions that perform no writes. Their additional traced Python heap must be less than the on-disk size of `src/cowrie/data/fs.pickle` in each of these cases:

- the bundled filesystem is used;
- all 12 sessions use the same operator contents directory;
- all 12 sessions use the same operator contents directory containing a regular file of at least 500 KiB;
- each of the 12 sessions is created with a different operator contents directory, and every session continues to return the files from its own directory.
- each different operator contents directory also introduces regular files beneath virtual parent directories absent from the bundled honeyfs; every session sees only its own added paths.

The same one-pickle memory budget applies to 12 retained sessions that each use a different operator contents directory and make a small, independent set of changes: create a regular file, change permissions on an existing operator-backed file, and move an existing file between directories. Every retained session must continue to expose its own operator-provided bytes and only its own created, changed, and moved entries.

Filesystem operations must also agree across the public interfaces:

- Shell `mv` and SFTP rename replace an existing destination rather than creating duplicate entries. Cross-directory moves remove the old name and create the requested destination name.
- Rename replacement observes filesystem type safety: a non-directory cannot replace a directory, a directory cannot replace a non-directory or a non-empty directory, and a directory cannot be moved beneath itself. Replacing an empty directory with a directory is allowed. A rejected rename raises `OSError` and leaves both source and destination subtrees unchanged through the filesystem, shell, and SFTP interfaces.
- Renaming or removing a missing path raises `OSError`.
- An empty path names the root, and repeated `/` separators are ignored.
- A terminal symlink is followed by default; `follow_symlinks=False` returns the link entry. Intermediate directory symlinks are followed, broken symlinks resolve as missing, and descent through a regular file also resolves as missing.
- Directory-contents lookup returns child entries for a directory and stored bytes for a regular file. It follows a symlink to a directory and raises `FileNotFound` for a missing path or descent through a file.

Keep the existing public shell and SFTP APIs intact. Use whichever internal representation satisfies these memory and session-view requirements.
