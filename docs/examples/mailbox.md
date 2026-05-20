# Example — Mailbox

Server-pushed messages with optional reward attachments.

## List unread

```gdscript
var result := await SaiServer.mailbox.list(20, 0)  # limit, offset
if result.success:
    for msg in result.data.messages:
        # `read_at` is "" (empty) while unread, ISO-8601 once read.
        if msg.read_at.is_empty():
            print("[new] %s" % msg.subject)
```

## Mark read / unread

```gdscript
await SaiServer.mailbox.mark_read(message_id)
await SaiServer.mailbox.mark_unread(message_id)
```

## Claim reward attachments

```gdscript
SaiServer.mailbox.claim_success.connect(_on_rewards)
SaiServer.mailbox.claim(message_id)

# Signal signature: claim_success(message_id: String, rewards: Array[ClaimReward])
func _on_rewards(_message_id: String, rewards: Array) -> void:
    for r in rewards:
        print("Got %d x %s" % [r.quantity, r.definition_id])
```

## Unclaim (server-side rollback if your client crashed mid-flow)

```gdscript
await SaiServer.mailbox.unclaim(message_id)
```

## Delete

```gdscript
await SaiServer.mailbox.delete(message_id)
```

## Render UI from message list

```gdscript
for msg in result.data.messages:
    var item := MAIL_ITEM_SCENE.instantiate()
    item.set_subject(msg.subject)
    item.set_body(msg.body)
    item.set_unread(msg.read_at.is_empty())
    item.set_has_rewards(not msg.attachments.is_empty())
    list_container.add_child(item)
```
