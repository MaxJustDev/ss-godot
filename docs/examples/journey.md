# Example — Journey (player events)

Telemetry / analytics event stream. Send arbitrary tagged events; backend stores for later querying.

## Emit single event

```gdscript
SaiServer.journey.emit_event("tutorial_step_completed", {
    "step": 3,
    "total_steps": 10,
    "seconds_in_step": 42.5,
})
```

## Emit batched

```gdscript
var events := [
    {"type": "ui_button_clicked", "payload": {"id": "play"}},
    {"type": "scene_loaded", "payload": {"name": "lobby"}},
]
SaiServer.journey.emit_batch(events)
```

## Recommended event types

The SDK doesn't enforce a vocabulary — agree with your team on a list. Common ones:

- `session_start` / `session_end`
- `level_completed` / `level_failed`
- `purchase_intent` / `purchase_completed`
- `tutorial_step_*`
- `feature_used` (with `feature: "..."` in payload)
- `error_reported` (with `error: "..."`, `stack: "..."`)

## Privacy

Don't put PII in event payloads. Server doesn't filter — what you send is what gets stored.
