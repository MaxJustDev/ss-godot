# Changelog

All notable changes to **ss-godot** are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Tracks upstream `SaiGame-studio/ss-unity` SDK. Godot port uses independent SemVer (see `sdk_port_plan.html` §10).

## [Unreleased]

(no entries yet)

## [0.1.0] — 2026-05-20

First public release. Tracks ss-unity v0.2.40d. 62 distinct REST endpoints (73 method+path rows) across 10 service modules. Asset Library submission pending.

### Added (M1 — Core)
- `core/sai_server.gd` (439 lines) — full HTTP wrapper (GET/POST/PUT/PATCH/DELETE async), token mgmt with `ConfigFile` persistence at `user://sai_server.cfg`, base URL switch, request timeout, bearer-token injection gated by `auth` param, TLS-unsafe toggle (`allow_insecure_tls`) for local dev.
- `core/sai_singleton.gd` — base class for sub-services (Godot autoload-aware).
- `core/sai_behaviour.gd` — `Node` base with virtual `_load_components()` / `_reset_values()` hooks (replaces Unity reflection-based MonoBehaviour auto-wiring).
- `core/auth_event_listener.gd` — convenience subscriber for `SaiServer` auth signals.
- `core/domain_option.gd`, `core/server_endpoint_option.gd` — endpoint config enums.
- `util/aes_helper.gd` — AES CBC PKCS7 encrypt/decrypt via Godot `AESContext`.
- `util/json_helper.gd` — JSON parse + stringify wrappers with empty-on-error helpers.
- `util/http_helper.gd` — URL build, query encode, header construction.
- Signals: `token_refreshed`, `auth_required`, `request_started`, `request_completed`.

### Added (M2 — Auth)
- `auth/sai_auth.gd` (311 lines) — `register`, `login`, `refresh`, `logout`, `get_me`.
- `auth/google_backend_login.gd` (307 lines) — 2-step polling flow for Google OAuth (`POST /session` → poll `GET /session/{id}`).
- `auth/dto/user_data.gd`, `auth/dto/login_response.gd`, `auth/dto/google_session.gd` — typed Resources.
- Sub-service registration: `SaiServer.auth: SaiAuth` and `SaiServer.google_login: GoogleBackendLogin` autoload children.
- Endpoint coverage: 7/7 Auth endpoints.
- Tests: `tests/unit/test_sai_auth.gd`, `tests/integration/test_auth_flow.gd`.

### Added (M3a — GamerProgress)
- `progress/gamer_progress.gd` — `create`, `get_mine`, `update`, `delete_mine` with full CRUD signal pairs.
- `progress/dto/gamer_progress_data.gd` — typed Resource with raw-JSON `game_data` opaque field.
- Sub-service `SaiServer.progress: GamerProgress`.

### Added (M3b — Mailbox)
- `mailbox/mailbox.gd` — `list`, `mark_read`, `mark_unread`, `claim`, `unclaim`, `delete`.
- Typed DTOs: `MailboxMessage`, `MailboxAttachment`, `ClaimReward`.
- Sub-service `SaiServer.mailbox: Mailbox`.

### Added (M4 — ItemContainer family)
- 10 sub-services: `PlayerContainer`, `PlayerItem`, `ItemAddDeduct`, `GachaPack`, `EquipmentSlot`, `ItemCrafting`, `ItemPreset`, `ItemTag`, `ItemGenerator`, plus shared DTOs.
- Aliases `SaiServer.inventory` → `PlayerContainer`, `SaiServer.item` ↔ `SaiServer.player_item`.
- 18 DTO Resources (`ContainerData`, `InventoryItemData`, `GachaResponse`, `CraftingResponse`, `PresetData`, `RecipeDetail`, `GeneratorData`, …).
- Endpoint coverage: ~29 endpoints across container, item, slot, preset, crafting, tag, gacha, generator.

### Added (M5a — Shop)
- `shop/shop.gd` — `list`, `items`, `purchase`, plus reserved `history()` placeholder.
- Typed DTOs: `ShopData`, `ShopItem`, `PurchaseRecord`.
- Sub-service `SaiServer.shop: Shop`.

### Added (M5b — Quest)
- 4 sub-services: `ChainQuest`, `QuestProgressor`, `DailyQuest`, `QuestHistory`.
- `SaiServer.quest` alias of `ChainQuest` plus facade methods delegating to sibling services (`advance_chain`, `increment_progress`, `claim_quest`, `list_daily`, `claim_daily`, `history`, `quest_status`).
- Typed DTOs: `QuestData`, `QuestStep`, `DailyQuestData`, `QuestClaimRecord`.

### Added (M6a — Journey)
- `journey/player_event.gd` — `emit_event`, `emit_batch`, session-id rotation tied to `SaiServer.token_refreshed` / `logout_success`.
- Typed DTO: `EventData`.
- Sub-service `SaiServer.journey` (alias of `player_event`).

### Added (M6b — Leaderboard)
- `leaderboard/leaderboard.gd` — `list_boards`, `get_board`, `top`, `my_rank`, plus reserved `submit()` / `around_me()` placeholders.
- Typed DTOs: `LeaderboardData`, `LeaderboardEntry`, `LeaderboardLocalRank`.
- Sub-service `SaiServer.leaderboard: Leaderboard`.

### Added (M6c — Battle)
- `battle/battle_sessions.gd` — `list_sessions`, plus reserved `create_session()` / `send_event()` / `finish_session()` placeholders.
- `battle/battle_script.gd` — `run_script(name, params)` thin RPC wrapper over server-hosted Lua.
- Typed DTO: `BattleData` (with raw `start_data` / `end_data` Dictionaries for per-game schema flexibility).
- Aliases `SaiServer.battle` → `BattleSessions`.

### Added (M6d — LuaScript)
- `lua_script/lua_script_manager.gd` — `list`, `create_script`, `update_script`, `set_flags`, `delete_script`, `run`, `run_raw_body`.
- Sub-service `SaiServer.lua_script: LuaScriptManager` (alias `lua_script_manager`).

### Added (M7 — docs + demo polish)
- Expanded `docs/api_reference.md` from stub to full reference (~600 lines) — every service's methods + signals + reserved-future API.
- Fixed `docs/examples/*.md` drift: signal arities, DTO field names, method signatures across login / mailbox / inventory / shop / quest / leaderboard / battle / lua_script examples.
- `README.md` rewrite with Quick-start, "Modules at a glance" table, status promoted to Done.
- `demo/scenes/login.tscn` + `demo/scenes/lobby.tscn` minimal working demo scaffolds.
- `demo/scripts/lobby_demo.gd` exercising `SaiServer.progress` save / load / reset.

### Added (discovery)
- `docs/endpoints.md` — 62 distinct endpoint paths (73 method+path rows) documented across all modules with method, path, auth, body, response, upstream `file:line` refs.

### Added (tooling)
- `.github/workflows/ci.yml` — gdtoolkit lint + GUT unit tests.
- `.github/workflows/release.yml` — auto-zip addon on tag push.
- `tests/mock_server/app.py` — Python Flask mock backend for offline integration tests.
- `demo/project.godot` — separate demo project showcasing the SDK.

### Notes
- Tracks `ss-unity` v0.2.40d.
- Upstream Unity repo has no explicit LICENSE file — port published in good faith under MIT.
- Reserved-future-API entries (Shop.history, Leaderboard.submit / around_me, BattleSessions.create_session / send_event / finish_session) return failure envelopes today and unlock automatically once upstream ships the matching wire endpoints.

