# Example — Shop

List shops, list items per shop, purchase.

## List shops

```gdscript
var result := await SaiServer.shop.list()  # limit, offset (optional)
if result.success:
    for s in result.data.shops:
        print("%s — %s (active=%s)" % [s.id, s.shop_key, s.is_active])
```

`result.data.shops` is `Array[ShopData]`. The raw server payload is preserved as `result.data.raw`.

## List items in a shop

```gdscript
var items_result := await SaiServer.shop.items(shop_id)
if items_result.success:
    for it in items_result.data.items:
        print("%s — %d %s" % [it.display_name, it.price, it.currency_item_def_id])
```

## Purchase

```gdscript
SaiServer.shop.purchase_success.connect(_on_buy_ok)
SaiServer.shop.purchase_failed.connect(_on_buy_err)
await SaiServer.shop.purchase(shop_id, shop_item_id, 1)  # quantity defaults to 1

func _on_buy_ok(record: PurchaseRecord) -> void:
    print("Bought %d x %s for %d %s" % [
        record.quantity,
        record.shop_item_id,
        record.total_price,
        record.currency_item_def_id,
    ])

func _on_buy_err(error: String) -> void:
    push_error("Purchase failed: %s" % error)
    # Common errors: insufficient_balance, item_out_of_stock, limit_reached
```

The 4th `purchase()` argument is an optional client-supplied `idempotency_key`. The SDK fills in a random one if you omit it; pass your own when you need a stable replay-safe key.

## History (reserved — not in upstream v0.2.40d)

```gdscript
# Returns {success: false, error: "purchase history endpoint is not implemented..."}
# until upstream ships the route. The signal pair history_loaded / history_failed
# is reserved so app code can wire it now.
await SaiServer.shop.history()
```

For a transient in-memory history today, listen to `purchase_success` and accumulate `PurchaseRecord`s locally.

## Local query helpers

```gdscript
# After a successful list() call, ShopData entries are cached.
var pvp := SaiServer.shop.get_shop_by_key("pvp_store")
var actives := SaiServer.shop.get_active_shops()
```
