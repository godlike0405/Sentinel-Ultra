# Wait for usable blob content

Some Azure Functions integration tests read output blobs as soon as storage reports them available. The returned payload may not yet contain the content the test expects, which can cause intermittent failures.

Update `WaitForBlobAndGetStringAsync` so callers that care about content can define when a downloaded string is ready to return.

Requirements:

- Existing callers must remain source-compatible and retain their current behavior when they do not supply a content condition.
- Callers must be able to supply a content condition, and the helper must return only content that meets it.
- Preserve the established timeout and polling behavior.
- Handle transient storage failures gracefully.
- Preserve useful timeout diagnostics.

Keep this behavior centralized in the shared blob-waiting support.
