`seqcli ingest` can leave low-volume input buffered indefinitely when events are piped through STDIN. For example, a long-running `tail -F` pipeline may produce only a few events at a time, so waiting for a full batch makes recent logs appear to be lost.

Update streaming ingestion so events already accepted are delivered promptly when the input becomes temporarily quiet. This must work for both the default plain-text mode and `--json`/CLEF input.

Expected behavior:

- A temporary lull flushes the events accumulated so far but does not end ingestion. If more input arrives later, it must also be read and shipped.
- Actual end-of-input flushes any remaining events and then completes normally.
- No ingestion request is made when there are no events ready to send, including during repeated idle periods.
- Ingestion requests contain no more than 100 events.
- A completely successful run returns zero.
- Any non-success response from the server makes the command return non-zero. The diagnostic output includes the response status and, when supplied by the server, its error message.
- When no usable extraction pattern is supplied, each physical plain-text input line becomes a separate event and its line terminator is excluded from the message text.
- The existing extraction-pattern syntax exposes indentation-aware multiline capture under the public matcher name `trailingindent`. With this matcher, indented continuation lines are grouped with the preceding non-indented line, while an indented line cannot begin a new multiline frame.
- Malformed or orphaned input continues to produce a useful error identifying the offending content, subject to the command's existing invalid-data handling option.
