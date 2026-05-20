# API Reference

Comprehensive reference for the ss-godot SDK v0.1.0. Generated from GDScript declarations.

All async methods return the standard envelope:

```gdscript
{
    "success": bool,    # HTTP 2xx and no parse error
    "status": int,      # HTTP status code (0 if request never left)
    "error": String,    # empty when success == true
    "data": Variant,    # parsed payload (often re-wrapped as typed Resource / Dictionary)
}
```

## Table of contents

- [`SaiServer`](#saiserver-autoload) — root singleton / HTTP wrapper
- [`SaiAuth`](#saiauth-saiserverauth) — register / login / logout / refresh
- [`GoogleBackendLogin`](#googlebackendlogin-saiservergoogle_login) — Google OAuth 2-step
- [`GamerProgress`](#gamerprogress-saiserverprogress) — per-player game progress
- [`Mailbox`](#mailbox-saiservermailbox) — list / read / claim / delete server-pushed mail
- [`PlayerContainer`](#playercontainer-saiserverinventory--player_container) — containers + items + gacha
- [`PlayerItem`](#playeritem-saiserverplayer_item) — cross-container inventory ops
- [`ItemAddDeduct`](#itemadddeduct-saiserveritem_add_deduct) — grant / remove stacks
- [`EquipmentSlot`](#equipmentslot-saiserverequipment_slot) — equip / unequip
- [`ItemCrafting`](#itemcrafting-saiserveritem_crafting) — recipes
- [`ItemPreset`](#itempreset-saiserveritem_preset) — loadout presets
- [`ItemTag`](#itemtag-saiserveritem_tag) — tag lookup
- [`GachaPack`](#gachapack-saiservergacha) — open packs
- [`ItemGenerator`](#itemgenerator-saiserveritem_generator) — yield generators
- [`Shop`](#shop-saiservershop) — list / items / purchase
- [`ChainQuest`](#chainquest-saiserverquest--chain_quest) — chain quest + facade
- [`QuestProgressor`](#questprogressor-saiserverquest_progressor) — quest lifecycle
- [`DailyQuest`](#dailyquest-saiserverdaily_quest) — daily quest pools
- [`QuestHistory`](#questhistory-saiserverquest_history) — claims log
- [`PlayerEvent`](#playerevent-saiserverjourney--player_event) — telemetry
- [`Leaderboard`](#leaderboard-saiserverleaderboard) — rankings
- [`BattleSessions`](#battlesessions-saiserverbattle--battle_sessions) — battle list
- [`BattleScript`](#battlescript-saiserverbattle_script) — server-side Lua bridge
- [`LuaScriptManager`](#luascriptmanager-saiserverlua_script) — generic Lua RPC
- [Utilities (`util/*.gd`)](#utilities)
- [Reserved future API](#reserved-future-api)

## `SaiServer` (autoload)

Root singleton. Provides HTTP helpers + token mgmt + sub-service access.

Source: [`addons/sai_services/core/sai_server.gd`](../addons/sai_services/core/sai_server.gd).

### Inspector fields

| Member | Type | Purpose |
|--------|------|---------|
| `VERSION` | `String` | SDK version. |
| `UPSTREAM_VERSION` | `String` | Unity SDK version tracked. |
| `use_local_endpoint` | `bool` | Force local HTTP endpoint. |
| `allow_insecure_tls` | `bool` | Dev-only — accept self-signed certs. |
| `game_id` | `String` | Game identifier sent with most requests. |
| `request_timeout_sec` | `float` | Per-request timeout. |
| `show_buttons_log` / `show_callback_log` / `show_debug_log` / `show_url_request` / `show_json_request` / `show_json_response` / `show_token_log` | `bool` | Per-channel debug logging. |

### Methods

| Signature | Purpose |
|-----------|---------|
| `base_url() -> String` | Current base URL (local or production). |
| `is_authenticated() -> bool` | True iff an access token is set. |
| `access_token() -> String` / `refresh_token() -> String` / `expires_in() -> int` | Token accessors. |
| `set_login_data(access, refresh, expires) -> void` | Set tokens + expiry, persist, emit `token_refreshed`. |
| `set_access_token(token) -> void` | Update access token only. |
| `clear_tokens() -> void` | Wipe stored credentials. |
| `normalized_game_id() -> String` | Trimmed `game_id`. |
| `set_game_id(new_id: String) -> void` | Replace game id at runtime. |
| `save_server_endpoint() -> void` | Persist current endpoint selection. |
| `ping() -> bool` (async) | Health check (`<base>/health`). |
| `get_request(path, query := {}, auth := true) -> Dictionary` (async) | GET. |
| `post_request(path, body = null, auth := true) -> Dictionary` (async) | POST. |
| `put_request(path, body = null, auth := true) -> Dictionary` (async) | PUT. |
| `patch_request(path, body = null, auth := true) -> Dictionary` (async) | PATCH. |
| `delete_request(path, body = null, auth := true) -> Dictionary` (async) | DELETE. |

### Signals

| Signature | When |
|-----------|------|
| `token_refreshed(access_token: String)` | Access token changed (login / refresh / set). |
| `auth_required()` | Authenticated request fired without a token, or 401 returned. |
| `request_started(method: String, path: String)` | Before each request leaves. |
| `request_completed(method: String, path: String, status: int)` | After each request resolves. |

### Typed sub-service accessors

| Accessor | Class | Module |
|----------|-------|--------|
| `auth` | `SaiAuth` | `auth/` |
| `google_login` | `GoogleBackendLogin` | `auth/` |
| `progress` | `GamerProgress` | `progress/` |
| `mailbox` | `Mailbox` | `mailbox/` |
| `inventory` / `player_container` | `PlayerContainer` | `item_container/container/` |
| `player_item` / `item` | `PlayerItem` | `item_container/item/` |
| `item_add_deduct` | `ItemAddDeduct` | `item_container/item/` |
| `gacha` | `GachaPack` | `item_container/container/` |
| `equipment_slot` | `EquipmentSlot` | `item_container/slot/` |
| `item_crafting` | `ItemCrafting` | `item_container/crafting/` |
| `item_preset` | `ItemPreset` | `item_container/preset/` |
| `item_tag` | `ItemTag` | `item_container/tag/` |
| `item_generator` | `ItemGenerator` | `item_container/generator/` |
| `shop` | `Shop` | `shop/` |
| `quest` / `chain_quest` | `ChainQuest` | `quest/` |
| `quest_progressor` | `QuestProgressor` | `quest/` |
| `daily_quest` | `DailyQuest` | `quest/` |
| `quest_history` | `QuestHistory` | `quest/` |
| `journey` / `player_event` | `PlayerEvent` | `journey/` |
| `leaderboard` | `Leaderboard` | `leaderboard/` |
| `battle` / `battle_sessions` | `BattleSessions` | `battle/` |
| `battle_script` | `BattleScript` | `battle/` |
| `lua_script` / `lua_script_manager` | `LuaScriptManager` | `lua_script/` |

## `SaiAuth` (`SaiServer.auth`)

Source: [`addons/sai_services/auth/sai_auth.gd`](../addons/sai_services/auth/sai_auth.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `register(email: String, username: String, password: String) -> Dictionary` (async) | POST `/api/v1/auth/register`. |
| `login(username: String, password: String) -> Dictionary` (async) | POST `/api/v1/auth/login`. Persists tokens. |
| `refresh() -> Dictionary` (async) | POST `/api/v1/auth/refresh` using stored refresh token. |
| `logout() -> Dictionary` (async) | POST `/api/v1/auth/logout`. Wipes tokens regardless of outcome. |
| `get_me() -> Dictionary` (async) | GET `/api/v1/auth/me`. |
| `get_current_user() -> Dictionary` | Cached user (from last login / me / refresh). |
| `is_authenticated() -> bool` | Delegates to `SaiServer.is_authenticated()`. |

### Signals

| Signature | When |
|-----------|------|
| `login_success(user: Dictionary)` | Login OK (`user` is the parsed user dict). |
| `login_failed(error: String)` | Login HTTP / parse error. |
| `register_success(user: Dictionary)` | Register OK. |
| `register_failed(error: String)` | Register error. |
| `logout_success()` | Logout OK. |
| `logout_failed(error: String)` | Server-side logout error (tokens still wiped locally). |
| `refresh_success()` | Tokens rotated successfully. |
| `refresh_failed(error: String)` | Refresh error. |
| `me_loaded(user: Dictionary)` | `get_me()` returned a fresh profile. |

## `GoogleBackendLogin` (`SaiServer.google_login`)

Source: [`addons/sai_services/auth/google_backend_login.gd`](../addons/sai_services/auth/google_backend_login.gd).

Two-step Google OAuth: `start_session()` opens a backend-managed session, then the SDK polls until the user completes browser auth.

### Methods

| Signature | Purpose |
|-----------|---------|
| `start_session(platform: String, client_fingerprint: String = "") -> Dictionary` (async) | POST `/api/v1/auth/google/session`. Emits `session_started`, then begins polling. |
| `cancel_poll() -> void` | Stop the polling loop without finalizing. |
| `is_polling() -> bool` | True while the poll loop is active. |
| `current_session() -> GoogleSession` | Last session DTO (may be null). |

### Signals

| Signature | When |
|-----------|------|
| `session_started(auth_url: String, expires_at: int)` | After start_session 2xx. |
| `login_success(user: Dictionary)` | Poll detected auth completion. |
| `login_failed(error: String)` | Session expired or backend error. |
| `poll_tick(status: String)` | Each poll iteration (status echoes the backend). |

## `GamerProgress` (`SaiServer.progress`)

Source: [`addons/sai_services/progress/gamer_progress.gd`](../addons/sai_services/progress/gamer_progress.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `create(initial: Dictionary = {}) -> Dictionary` (async) | POST `/api/v1/games/{game_id}/gamer-progress`. `initial` keys: `experience`, `gold`, `game_data`. |
| `get_mine() -> Dictionary` (async) | GET `/api/v1/games/{game_id}/my-gamer-progress`. |
| `update(progress_id: String, deltas: Dictionary = {}) -> Dictionary` (async) | PATCH `/api/v1/gamer-progress/{progress_id}`. `deltas` keys: `experience_delta`, `gold_delta`, `game_data`. |
| `delete_mine() -> Dictionary` (async) | DELETE `/api/v1/games/{game_id}/my-gamer-progress`. Always wipes local state. |
| `has_progress() -> bool` | True iff `current_progress.id != ""`. |
| `get_current_progress() -> GamerProgressData` | Cached DTO (may be null). |

Successful create/get/update calls re-wrap `data` as a typed `GamerProgressData` Resource (fields: `id`, `user_id`, `game_id`, `level`, `experience`, `gold`, `game_data`, `created_at`, `updated_at`, `version`).

### Signals

| Signature | When |
|-----------|------|
| `create_success(data: Dictionary)` / `create_failed(error: String)` | After `create()`. |
| `get_success(data: Dictionary)` / `get_failed(error: String)` | After `get_mine()`. |
| `update_success(data: Dictionary)` / `update_failed(error: String)` | After `update()`. |
| `delete_success()` / `delete_failed(error: String)` | After `delete_mine()`. |

## `Mailbox` (`SaiServer.mailbox`)

Source: [`addons/sai_services/mailbox/mailbox.gd`](../addons/sai_services/mailbox/mailbox.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `list(limit: int = 20, offset: int = 0) -> Dictionary` (async) | GET `/api/v1/games/{game_id}/mailbox/messages`. `data` → `{messages: Array[MailboxMessage], total: int, raw: Dictionary}`. |
| `mark_read(message_id: String) -> Dictionary` (async) | PATCH body `{"read": true}`. |
| `mark_unread(message_id: String) -> Dictionary` (async) | PATCH body `{"read": false}`. |
| `claim(message_id: String) -> Dictionary` (async) | POST `.../claim`. `data` → `{rewards: Array[ClaimReward], raw: Dictionary}`. |
| `unclaim(message_id: String) -> Dictionary` (async) | DELETE `.../claim`. |
| `delete(message_id: String) -> Dictionary` (async) | DELETE message. |

### Signals

| Signature | When |
|-----------|------|
| `list_loaded(messages: Array, total: int)` / `list_failed(error: String)` | After `list()`. |
| `read_changed(message_id: String, read: bool, message: MailboxMessage)` | After mark_read / mark_unread. |
| `claim_success(message_id: String, rewards: Array)` / `claim_failed(message_id: String, error: String)` | After `claim()`. |
| `unclaim_success(message_id: String)` | After `unclaim()`. |
| `delete_success(message_id: String)` / `delete_failed(message_id: String, error: String)` | After `delete()`. |

## `PlayerContainer` (`SaiServer.inventory` / `player_container`)

Source: [`addons/sai_services/item_container/container/player_container.gd`](../addons/sai_services/item_container/container/player_container.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `get_containers(limit: int = 50, offset: int = 0) -> Dictionary` (async) | GET `/api/v1/games/{game_id}/containers`. `data` → `{containers, has_more, limit, offset}`. |
| `get_items(container_id: String, limit: int = 50, offset: int = 0) -> Dictionary` (async) | GET `/api/v1/containers/{id}/items`. `data` → `{container_id, items}`. |
| `open_gacha_pack(gacha_pack_def_id: String, container_id: String) -> Dictionary` (async) | POST `/api/v1/games/{game_id}/gacha/{gacha_pack_id}`. |
| `get_container_by_id(container_id: String) -> ContainerData` | Local cache lookup. |
| `get_containers_by_type(container_type: String) -> Array[ContainerData]` | Local cache filter. |
| `clear_containers() -> void` | Drop local cache. |

### Signals

| Signature |
|-----------|
| `containers_loaded(containers: Array, has_more: bool)` / `containers_failed(error: String)` |
| `items_loaded(container_id: String, items: Array)` / `items_failed(container_id: String, error: String)` |
| `gacha_success(response: GachaResponse)` / `gacha_failed(error: String)` |

## `PlayerItem` (`SaiServer.player_item`)

Source: [`addons/sai_services/item_container/item/player_item.gd`](../addons/sai_services/item_container/item/player_item.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `get_items(limit: int = 50, offset: int = 0, category: String = "") -> Dictionary` (async) | Whole-inventory listing. |
| `update_item_properties(item_id: String, properties: Variant) -> Dictionary` (async) | PATCH custom properties. |
| `get_categories() -> Dictionary` (async) | Distinct categories list. |
| `move_item(item_id, target_container_id, quantity, grid_x = 0, grid_y = 0) -> Dictionary` (async) | POST `/api/v1/games/{game_id}/inventory/move`. |
| `swap_items(item_a_id: String, item_b_id: String) -> Dictionary` (async) | POST `/api/v1/games/{game_id}/inventory/swap`. |
| `get_item_by_id(item_id: String) -> InventoryItemData` | Cache lookup. |
| `get_items_by_category(category: String) -> Array[InventoryItemData]` | Cache filter. |
| `clear_inventory() -> void` | Drop cache. |

### Signals

| Signature |
|-----------|
| `items_loaded(items: Array, total: int)` / `items_failed(error: String)` |
| `update_properties_success(item: InventoryItemData)` / `update_properties_failed(error: String)` |
| `categories_loaded(categories: PackedStringArray)` / `categories_failed(error: String)` |
| `move_success(data: Dictionary)` / `move_failed(error: String)` |
| `swap_success(data: Dictionary)` / `swap_failed(error: String)` |

## `ItemAddDeduct` (`SaiServer.item_add_deduct`)

Source: [`addons/sai_services/item_container/item/item_add_deduct.gd`](../addons/sai_services/item_container/item/item_add_deduct.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `add(item_definition_id: String, quantity: int, container_id: String = "") -> Dictionary` (async) | Grant `quantity` of an item definition (positive delta). |
| `deduct(item_definition_id: String, quantity: int, container_id: String = "") -> Dictionary` (async) | Remove `quantity` (negative delta). |
| `add_deduct(item_definition_id: String, quantity: int, container_id: String = "") -> Dictionary` (async) | Generic — sign-of-quantity drives add/deduct. |

### Signals

| Signature |
|-----------|
| `add_deduct_success(data: Variant)` / `add_deduct_failed(error: String)` |

## `EquipmentSlot` (`SaiServer.equipment_slot`)

Source: [`addons/sai_services/item_container/slot/equipment_slot.gd`](../addons/sai_services/item_container/slot/equipment_slot.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `get_slots() -> Dictionary` (async) | List equipment slot definitions. |
| `equip_item(item_id: String, slot_key: String, slot_data: Variant = {}) -> Dictionary` (async) | Equip into named slot. |
| `unequip_item(item_id: String) -> Dictionary` (async) | Remove from currently-equipped slot. |
| `get_equipped() -> Dictionary` (async) | List currently-equipped items. |
| `clear_slots() -> void` | Drop local cache. |

### Signals

| Signature |
|-----------|
| `slots_loaded(slots: Array, total: int)` / `slots_failed(error: String)` |
| `equipped_loaded(equipped: Array)` / `equipped_failed(error: String)` |
| `equip_success(data: Variant)` / `equip_failed(error: String)` |
| `unequip_success(data: Variant)` / `unequip_failed(error: String)` |

## `ItemCrafting` (`SaiServer.item_crafting`)

Source: [`addons/sai_services/item_container/crafting/item_crafting.gd`](../addons/sai_services/item_container/crafting/item_crafting.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `craft(recipe_id: String, idempotency_key: String = "") -> Dictionary` (async) | Craft via recipe id. SDK generates a key if omitted. |
| `craft_by_key(recipe_key: String, idempotency_key: String = "") -> Dictionary` (async) | Craft via stable recipe key. |
| `get_history(page: int = 1, page_size: int = 20, recipe_id: String = "", status: String = "") -> Dictionary` (async) | Paginated history. |
| `get_recipe_by_key(recipe_key: String) -> Dictionary` (async) | Fetch recipe detail. |
| `clear_history() -> void` | Drop cache. |

### Signals

| Signature |
|-----------|
| `craft_success(response: CraftingResponse)` / `craft_failed(error: String)` |
| `history_loaded(transactions: Array, total: int)` / `history_failed(error: String)` |
| `recipe_loaded(recipe: RecipeDetail)` / `recipe_failed(recipe_key: String, error: String)` |

## `ItemPreset` (`SaiServer.item_preset`)

Source: [`addons/sai_services/item_container/preset/item_preset.gd`](../addons/sai_services/item_container/preset/item_preset.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `create_by_code_name(code_name: String, preset_name: String = "") -> Dictionary` (async) | Create from code name. |
| `create_by_definition_id(definition_id: String, preset_name: String = "") -> Dictionary` (async) | Create from definition id. |
| `list() -> Dictionary` (async) | List player's presets. |
| `get_one(preset_id: String) -> Dictionary` (async) | Fetch preset detail. |
| `add_item_to_preset(preset_id: String, slot_index: int, inventory_item_id: String) -> Dictionary` (async) | Place item into preset slot. |
| `remove_item_from_preset(preset_id: String, slot_index: int) -> Dictionary` (async) | Empty preset slot. |
| `rename_preset(preset_id: String, new_name: String) -> Dictionary` (async) | Rename only. |
| `update_preset_metadata(preset_id: String, metadata: Variant) -> Dictionary` (async) | Replace metadata blob. |
| `update_preset(preset_id: String, new_name: String = "", metadata: Variant = null) -> Dictionary` (async) | Combined update. |
| `delete_preset(preset_id: String) -> Dictionary` (async) | Delete. |
| `get_preset_by_id(preset_id: String) -> PresetData` | Cache lookup. |
| `get_presets_by_type(preset_type: String) -> Array[PresetData]` | Cache filter. |
| `clear_presets() -> void` | Drop cache. |

### Signals

| Signature |
|-----------|
| `create_success(preset: PresetData)` / `create_failed(error: String)` |
| `list_loaded(presets: Array)` / `list_failed(error: String)` |
| `get_one_success(preset: PresetData)` / `get_one_failed(preset_id: String, error: String)` |
| `slot_added(preset_id: String, slot_index: int, preset: PresetData)` / `slot_add_failed(preset_id: String, slot_index: int, error: String)` |
| `slot_removed(preset_id: String, slot_index: int, preset: PresetData)` / `slot_remove_failed(preset_id: String, slot_index: int, error: String)` |
| `update_success(preset: PresetData)` / `update_failed(preset_id: String, error: String)` |
| `delete_success(preset_id: String)` / `delete_failed(preset_id: String, error: String)` |

## `ItemTag` (`SaiServer.item_tag`)

Source: [`addons/sai_services/item_container/tag/item_tag.gd`](../addons/sai_services/item_container/tag/item_tag.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `get_tags(limit: int = 50, offset: int = 0) -> Dictionary` (async) | List defined tags. |
| `get_items_by_tag(tag_key: String) -> Dictionary` (async) | List inventory items tagged with `tag_key`. |
| `get_tag_by_id(tag_id: String) -> ItemTagData` | Cache lookup. |
| `get_tag_by_key(tag_key: String) -> ItemTagData` | Cache lookup. |
| `clear_tags() -> void` | Drop cache. |

### Signals

| Signature |
|-----------|
| `tags_loaded(tags: Array, total: int)` / `tags_failed(error: String)` |
| `tag_items_loaded(tag_key: String, items: Array, total: int)` / `tag_items_failed(tag_key: String, error: String)` |

## `GachaPack` (`SaiServer.gacha`)

Source: [`addons/sai_services/item_container/container/gacha_pack.gd`](../addons/sai_services/item_container/container/gacha_pack.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `open_by_id(gacha_pack_def_id: String, container_id: String) -> Dictionary` (async) | Open by definition id. |
| `open_by_code(code: String, container_id: String) -> Dictionary` (async) | Open by redemption code. |
| `clear_last_response() -> void` | Drop cached response. |

### Signals

| Signature |
|-----------|
| `open_success(response: GachaResponse)` / `open_failed(error: String)` |

## `ItemGenerator` (`SaiServer.item_generator`)

Source: [`addons/sai_services/item_container/generator/item_generator.gd`](../addons/sai_services/item_container/generator/item_generator.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `get_generators() -> Dictionary` (async) | List active generators owned by the player. |
| `check_generator(inventory_item_id: String) -> Dictionary` (async) | Inspect pending yield. |
| `collect_generator(inventory_item_id: String) -> Dictionary` (async) | Claim pending yield. |
| `get_generator_by_inventory_item_id(inventory_item_id: String) -> GeneratorData` | Cache lookup. |
| `get_generator_by_definition_id(definition_id: String) -> GeneratorData` | Cache lookup. |
| `get_generators_with_pending_units() -> Array[GeneratorData]` | Cache filter. |
| `clear_generators() -> void` | Drop cache. |

### Signals

| Signature |
|-----------|
| `generators_loaded(generators: Array)` / `generators_failed(error: String)` |
| `generator_checked(generator: GeneratorData)` / `generator_check_failed(inventory_item_id: String, error: String)` |
| `generator_collected(response: GeneratorCollectResponse)` / `generator_collect_failed(inventory_item_id: String, error: String)` |

## `Shop` (`SaiServer.shop`)

Source: [`addons/sai_services/shop/shop.gd`](../addons/sai_services/shop/shop.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `list(limit: int = 20, offset: int = 0) -> Dictionary` (async) | GET `/api/v1/games/{game_id}/shops`. `data` → `{shops, total, limit, offset, raw}`. |
| `items(shop_id: String) -> Dictionary` (async) | GET shop items. `data` → `{items, item_count, shop_id, raw}`. |
| `purchase(shop_id: String, shop_item_id: String, quantity: int = 1, idempotency_key: String = "") -> Dictionary` (async) | POST purchase. `data` → `{record: PurchaseRecord, raw}`. |
| `history(_limit, _offset) -> Dictionary` (async) | Reserved — see [Reserved](#reserved-future-api). |
| `get_shop_by_id(shop_id: String) -> ShopData` | Cache lookup. |
| `get_shop_by_key(shop_key: String) -> ShopData` | Cache lookup. |
| `get_shops_by_type(shop_type: String) -> Array[ShopData]` | Cache filter. |
| `get_active_shops() -> Array[ShopData]` | Cache filter. |
| `clear_shops() -> void` | Drop cache. |
| `has_shops() -> bool` | True iff cache non-empty. |

### Signals

| Signature |
|-----------|
| `list_loaded(shops: Array, total: int)` / `list_failed(error: String)` |
| `items_loaded(shop_id: String, shop_items: Array)` / `items_failed(shop_id: String, error: String)` |
| `purchase_success(record: PurchaseRecord)` / `purchase_failed(error: String)` |
| `history_loaded(records: Array, total: int)` / `history_failed(error: String)` (reserved) |

## `ChainQuest` (`SaiServer.quest` / `chain_quest`)

Source: [`addons/sai_services/quest/chain_quest.gd`](../addons/sai_services/quest/chain_quest.gd).

`SaiServer.quest` aliases this node and also forwards daily / progressor / history methods so `SaiServer.quest.*` is a single quest facade.

### Methods (chain-native)

| Signature | Purpose |
|-----------|---------|
| `list_chain(limit: int = 20, offset: int = 0) -> Dictionary` (async) | List chain quests. |
| `list_chain_members(chain_id: String) -> Dictionary` (async) | List members of one chain. |
| `get_chain_detail(chain_id: String) -> Dictionary` (async) | Fetch full tree (with derived `current_step` / `total_steps`). |
| `get_chain_tree(chain_id: String) -> Dictionary` (async) | Alias of `get_chain_detail`. |
| `get_chain_by_id(chain_id: String) -> Variant` | Cache lookup. |
| `get_chain_by_key(chain_key: String) -> Variant` | Cache lookup. |
| `get_cached_members(chain_id: String) -> Variant` | Cache lookup. |
| `last_total() -> int` | Last `total` from list response. |
| `clear_chains() -> void` | Drop cache. |

### Methods (facade — delegate to siblings)

| Signature | Delegates to |
|-----------|--------------|
| `advance_chain(quest_definition_id: String)` | `QuestProgressor.advance_chain` |
| `increment_progress(objective_code: String, delta: int = 1)` | `QuestProgressor.increment_progress` |
| `claim_quest(quest_definition_id: String)` | `QuestProgressor.claim_quest` |
| `list_daily(pool_id: String)` | `DailyQuest.list_daily` |
| `claim_daily(quest_definition_id: String)` | `DailyQuest.claim_daily` |
| `list_daily_pools()` | `DailyQuest.list_daily_pools` |
| `assign_daily_ahead(pool_id, days_ahead)` | `DailyQuest.assign_daily_ahead` |
| `history(limit, offset)` | `QuestHistory.history` |
| `quest_status(quest_definition_id)` | `QuestHistory.quest_status` |

### Signals

| Signature |
|-----------|
| `list_chain_success(data: Dictionary)` / `list_chain_failed(error: String)` |
| `chain_members_success(chain_id: String, data: Dictionary)` / `chain_members_failed(chain_id: String, error: String)` |
| `chain_advance_success(chain_id: String, data: Dictionary)` / `chain_advance_failed(chain_id: String, error: String)` |

## `QuestProgressor` (`SaiServer.quest_progressor`)

Source: [`addons/sai_services/quest/quest_progressor.gd`](../addons/sai_services/quest/quest_progressor.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `start_quest(quest_definition_id: String) -> Dictionary` (async) | Start a quest definition. |
| `advance_chain(quest_definition_id: String) -> Dictionary` (async) | Alias of `start_quest` for chain context. |
| `check_quest(quest_definition_id: String) -> Dictionary` (async) | Inspect current progress. |
| `increment_progress(objective_code: String, delta: int = 1) -> Dictionary` (async) | Bump an objective counter. |
| `claim_quest(quest_definition_id: String) -> Dictionary` (async) | Claim a completed quest's rewards. |

### Signals

| Signature |
|-----------|
| `start_quest_success(quest_id: String, data: Dictionary)` / `start_quest_failed(quest_id: String, error: String)` |
| `check_quest_success(quest_id: String, data: Dictionary)` / `check_quest_failed(quest_id: String, error: String)` |
| `claim_quest_success(quest_id: String, claim: QuestClaimRecord)` / `claim_quest_failed(quest_id: String, error: String)` |
| `quest_completed(quest_id: String)` |

## `DailyQuest` (`SaiServer.daily_quest`)

Source: [`addons/sai_services/quest/daily_quest.gd`](../addons/sai_services/quest/daily_quest.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `list_daily_pools() -> Dictionary` (async) | List configured daily pools. |
| `list_daily(pool_id: String) -> Dictionary` (async) | Today's quests for one pool. |
| `get_today(pool_id: String) -> Dictionary` (async) | Alias of `list_daily`. |
| `assign_daily_ahead(pool_id: String, days_ahead: int = 7) -> Dictionary` (async) | Pre-assign N days. |
| `claim_daily(quest_definition_id: String) -> Dictionary` (async) | Claim a completed daily. |
| `get_cached_today(pool_id: String) -> Variant` | Cache lookup. |
| `get_cached_assign_ahead(pool_id: String) -> Variant` | Cache lookup. |
| `clear_daily() -> void` | Drop cache. |

### Signals

| Signature |
|-----------|
| `pools_loaded(pools: Array)` / `pools_failed(error: String)` |
| `today_loaded(pool_id: String, entries: Array)` / `today_failed(pool_id: String, error: String)` |
| `assign_ahead_success(pool_id: String, days: Array)` / `assign_ahead_failed(pool_id: String, error: String)` |
| `daily_claim_success(quest_definition_id: String, claim: QuestClaimRecord)` / `daily_claim_failed(quest_definition_id: String, error: String)` |

## `QuestHistory` (`SaiServer.quest_history`)

Source: [`addons/sai_services/quest/quest_history.gd`](../addons/sai_services/quest/quest_history.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `history(limit: int = 20, offset: int = 0) -> Dictionary` (async) | Past claim log. |
| `list_claims(limit, offset) -> Dictionary` (async) | Alias of `history`. |
| `quest_status(quest_definition_id: String) -> Dictionary` (async) | Per-quest server status. |
| `get_claim_by_id(claim_id: String) -> Variant` | Cache lookup. |
| `get_claims_by_quest_definition_id(quest_definition_id: String) -> Array` | Cache filter. |
| `get_cached_status(quest_definition_id: String) -> Variant` | Cache lookup. |
| `last_total() -> int` | Last total from history response. |
| `clear_history() -> void` | Drop cache. |

### Signals

| Signature |
|-----------|
| `history_loaded(entries: Array, total: int)` / `history_failed(error: String)` |
| `quest_status_success(quest_definition_id: String, data: Dictionary)` / `quest_status_failed(quest_definition_id: String, error: String)` |

## `PlayerEvent` (`SaiServer.journey` / `player_event`)

Source: [`addons/sai_services/journey/player_event.gd`](../addons/sai_services/journey/player_event.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `emit_event(event_type: String, payload: Dictionary) -> Dictionary` (async) | POST `/api/v1/games/{game_id}/events`. |
| `emit_batch(events: Array[Dictionary]) -> Dictionary` (async) | Client-side fan-out — one POST per entry. |
| `get_session_id() -> String` | Current telemetry session id. |
| `set_session_id(id: String) -> void` | Override session id. |
| `regenerate_session_id() -> void` | Mint a new session id. |

### Signals

| Signature |
|-----------|
| `event_emitted(event_type: String, response: EventData)` / `event_failed(event_type: String, error: String)` |
| `session_id_changed(session_id: String)` |

## `Leaderboard` (`SaiServer.leaderboard`)

Source: [`addons/sai_services/leaderboard/leaderboard.gd`](../addons/sai_services/leaderboard/leaderboard.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `list_boards() -> Dictionary` (async) | GET available boards. |
| `get_board(board_id: String) -> Dictionary` (async) | Fetch board metadata. |
| `top(board_id: String, limit: int = 10) -> Dictionary` (async) | Top N entries. |
| `my_rank(board_id: String) -> Dictionary` (async) | Calling player's row. |
| `submit(board_id, score) -> Dictionary` (async) | Reserved — see [Reserved](#reserved-future-api). |
| `around_me(board_id, _window) -> Dictionary` (async) | Reserved. |
| `get_board_by_id(board_id: String) -> LeaderboardData` | Cache lookup. |
| `get_board_by_key(board_key: String) -> LeaderboardData` | Cache lookup. |
| `get_active_boards() -> Array[LeaderboardData]` | Cache filter. |
| `get_cached_top(board_id: String) -> Dictionary` | Cache lookup. |
| `get_cached_my_rank(board_id: String) -> LeaderboardLocalRank` | Cache lookup. |
| `clear_boards() -> void` | Drop cache. |
| `has_boards() -> bool` | True iff cache non-empty. |

### Signals

| Signature |
|-----------|
| `list_loaded(boards: Array)` / `list_failed(error: String)` |
| `board_loaded(board: LeaderboardData)` / `board_failed(board_id: String, error: String)` |
| `top_loaded(board_id: String, entries: Array, total: int)` / `top_failed(board_id: String, error: String)` |
| `my_rank_loaded(board_id: String, rank: LeaderboardLocalRank)` / `my_rank_failed(board_id: String, error: String)` |
| `submit_success(board_id: String, score: float)` / `submit_failed(board_id: String, error: String)` (reserved) |
| `around_me_loaded(board_id: String, entries: Array)` / `around_me_failed(board_id: String, error: String)` (reserved) |

## `BattleSessions` (`SaiServer.battle` / `battle_sessions`)

Source: [`addons/sai_services/battle/battle_sessions.gd`](../addons/sai_services/battle/battle_sessions.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `list_sessions(limit: int = 20, offset: int = 0) -> Dictionary` (async) | GET past battle sessions. `data` → `{sessions, total, limit, offset, raw}`. |
| `create_session(_data) -> Dictionary` (async) | Reserved — see [Reserved](#reserved-future-api). |
| `send_event(session_id, event_type, _payload) -> Dictionary` (async) | Reserved. |
| `finish_session(session_id, _result) -> Dictionary` (async) | Reserved. |
| `get_session_by_id(session_id: String) -> BattleData` | Cache lookup. |
| `clear_sessions() -> void` | Drop cache. |
| `has_sessions() -> bool` | True iff cache non-empty. |

### Signals

| Signature |
|-----------|
| `sessions_loaded(sessions: Array, total: int)` / `sessions_failed(error: String)` |
| `session_created(session_id: String)` / `session_create_failed(error: String)` (reserved) |
| `event_sent(session_id: String, event_type: String)` / `event_failed(session_id: String, event_type: String, error: String)` (reserved) |
| `session_finished(session_id: String, summary: Dictionary)` / `session_finish_failed(session_id: String, error: String)` (reserved) |

## `BattleScript` (`SaiServer.battle_script`)

Source: [`addons/sai_services/battle/battle_script.gd`](../addons/sai_services/battle/battle_script.gd).

Thin RPC wrapper over server-hosted Lua. Request body is `{"payload": params}`; response is forwarded raw under `data.raw`.

### Methods

| Signature | Purpose |
|-----------|---------|
| `run_script(script_name: String, params: Dictionary = {}) -> Dictionary` (async) | POST `/api/v1/games/{game_id}/scripts/{script_name}/run`. |

### Signals

| Signature |
|-----------|
| `script_success(name: String, raw_data: Variant)` / `script_failed(name: String, error: String)` |

## `LuaScriptManager` (`SaiServer.lua_script`)

Source: [`addons/sai_services/lua_script/lua_script_manager.gd`](../addons/sai_services/lua_script/lua_script_manager.gd).

### Methods

| Signature | Purpose |
|-----------|---------|
| `list() -> Dictionary` (async) | GET available scripts. `data` → `{scripts, raw}`. |
| `create_script(body: Dictionary) -> Dictionary` (async) | POST script (admin). Body keys: `name`, `description`, `script_body`. |
| `update_script(script_id: String, body: Dictionary) -> Dictionary` (async) | PUT script body / metadata. |
| `set_flags(script_id: String, flags: Dictionary) -> Dictionary` (async) | Patch script flags (e.g. `{"enabled": true}`). |
| `delete_script(script_id: String) -> Dictionary` (async) | Delete script. |
| `run(script_name: String, params: Dictionary = {}) -> Dictionary` (async) | Wraps body as `{"payload": params}` then POSTs to `.../{script_name}/run`. `data` → `{name, raw}`. |
| `run_raw_body(script_name: String, body: Variant) -> Dictionary` (async) | Variant of `run()` without the `payload` wrap. |
| `get_script_by_name(script_name: String) -> Variant` | Cache lookup. |
| `has_scripts() -> bool` | True iff cache non-empty. |
| `clear_scripts() -> void` | Drop cache. |

### Signals

| Signature |
|-----------|
| `list_loaded(scripts: Array)` / `list_failed(error: String)` |
| `create_success(id: String, raw: Variant)` / `create_failed(error: String)` |
| `update_success(id: String, raw: Variant)` / `update_failed(error: String)` |
| `flags_success(id: String, raw: Variant)` / `flags_failed(error: String)` |
| `delete_success(id: String)` / `delete_failed(error: String)` |
| `run_success(script_name: String, raw_data: Variant)` / `run_failed(script_name: String, error: String)` |

## Utilities

Static helpers under `addons/sai_services/util/`. Each is a `class_name` with only static methods — no instances.

| File | Purpose |
|------|---------|
| [`util/aes_helper.gd`](../addons/sai_services/util/aes_helper.gd) | AES-CBC PKCS7 encrypt / decrypt via Godot `AESContext`. |
| [`util/json_helper.gd`](../addons/sai_services/util/json_helper.gd) | JSON parse + stringify, with empty-on-error helpers. |
| [`util/http_helper.gd`](../addons/sai_services/util/http_helper.gd) | URL build, query encode, header construction. |

## Reserved future API

The following methods + signals are wired into the SDK now so callers can subscribe today, but the matching backend endpoints are not in upstream `ss-unity` v0.2.40d. Each returns `{success: false, error: "<...> is not implemented in upstream v0.2.40d"}` and emits its failure signal. They unlock automatically once the backend ships them.

| Service | Reserved method(s) | Status |
|---------|-------------------|--------|
| `Shop` | `history(limit, offset)` | Wire endpoint missing. Track `purchase_success` for an in-memory history meanwhile. |
| `Leaderboard` | `submit(board_id, score)`, `around_me(board_id, window)` | Score-submission endpoint and around-me query not in upstream. |
| `BattleSessions` | `create_session(data)`, `send_event(session_id, event_type, payload)`, `finish_session(session_id, result)` | Lifecycle endpoints not in upstream. Use `BattleScript.run_script` against a server-side Lua script today. |

## Conventions

- Async methods return `Dictionary` (envelope). Connect signals for fire-and-forget reactions.
- All identifiers snake_case.
- Public APIs use static typing; `Variant` only when JSON shape is genuinely dynamic.
- Timestamps stay as ISO-8601 / RFC-3339 strings — parse on demand with `Time.get_unix_time_from_datetime_string()`.
- Cache helpers (`get_*_by_*`, `clear_*`) are local-only; they never hit the network.
