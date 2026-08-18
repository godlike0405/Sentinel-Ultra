# Repair MCP-level OpenTelemetry tracing

Golf's OpenTelemetry traces currently lose the HTTP request as their parent and record rich MCP results as opaque object representations. This makes otherwise successful tool calls difficult to diagnose. Update the integration so each MCP operation participates in the HTTP request trace once, while preserving the behavior of projects that do not enable OpenTelemetry.

The following telemetry contracts are part of this change:

- `golf.telemetry` publicly exports `get_provider`, `OpenTelemetryMiddleware`, and `OTelContextCapturingMiddleware`. Each name must also appear in `golf.telemetry.__all__`.
- `get_provider()` returns the provider configured by telemetry initialization, or `None` before initialization.
- `OpenTelemetryMiddleware()` is a no-argument FastMCP middleware with `on_call_tool`, `on_read_resource`, `on_get_prompt`, and `on_message` hooks. When no provider is configured, every hook is transparent: it calls the next handler once, returns that handler's value, and creates no spans.
- With telemetry active, the hooks create these spans and attributes:

  | Operation | Span name | Required attributes |
  | --- | --- | --- |
  | MCP message | `mcp.request.<method>` with `/` rendered as `.` | `mcp.method`, `mcp.message.type`, `mcp.message.source` |
  | Tool call | `mcp.tool.<tool-name>.execute` | `mcp.component.type=tool`, `mcp.tool.name`, `mcp.method=tools/call` |
  | Resource read | `mcp.resource.read` | `mcp.component.type=resource`, `mcp.resource.uri`, `mcp.method=resources/read` |
  | Prompt generation | `mcp.prompt.<prompt-name>.generate` | `mcp.component.type=prompt`, `mcp.prompt.name`, `mcp.method=prompts/get` |

  These spans inherit the current OpenTelemetry context. Available FastMCP request/session/client/user/tenant identifiers are copied to `mcp.context.<identifier>` attributes on tool spans. The wrapped handler's return value is unchanged. If a handler raises, the span is marked as an error, the exception is recorded, and the original exception is re-raised.
- Detailed tracing records `mcp.tool.input` and `mcp.tool.output` as JSON text that preserves the input map or output map/list, plus `mcp.tool.result.type` containing the result's concrete class name. Result objects prefer non-null `structured_content`; otherwise their ordered content blocks are represented by their actual text rather than by an object `repr`. This applies both to FastMCP `ToolResult` values and to unrelated classes exposing the same `structured_content` or `content` fields. Existing tool success/error counters and duration recording must continue to run through the metrics collector when it is available.
- Payload capture is observational. Every recorded input or output remains valid JSON and is at most 1,000 characters; oversized or cyclic values may be summarized. A value that cannot be inspected or serialized must not change the handler's return value, exception, or span outcome.
- Each attempted tool call records one outcome counter and one non-negative duration when the metrics collector is operational. Downstream failures and cancellation use the `error` outcome. If the collector is absent or one of its methods fails, tracing still preserves the handler's original return value or exception.
- `OTelContextCapturingMiddleware` is ASGI middleware constructed from a downstream app. During an HTTP request it makes the current OpenTelemetry context available to the MCP message hook, then restores the previous value when the downstream call finishes or fails. Non-HTTP scopes pass through without installing an HTTP context.
- Cancellation is handled like other failed work by all four MCP hooks: the span is marked as an error, the cancellation is recorded, and the same cancellation is re-raised. Overlapping HTTP requests must keep distinct parents, and nested captures must restore the outer parent even when the inner request fails or is cancelled.
- An OpenTelemetry-enabled `golf build` registers exactly one `OpenTelemetryMiddleware` before custom MCP middleware. Generated tools, resources, and prompts retain their original component callables. A build with OpenTelemetry disabled registers no tracing middleware.
