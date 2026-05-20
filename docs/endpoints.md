# Endpoint reference

REST endpoints exposed by SaiGame backend. Source of truth for ss-godot port.

## Base URL

| Environment | URL |
|-------------|-----|
| Production  | `https://api.saigame.studio` |
| Local dev   | `http://local-api.saigame.studio:82` |

Source: `Assets/SaiGame/Scripts/SaiServer.cs:74-87` (BaseUrl switch on `ServerEndpointOption`).

## Auth

All authenticated endpoints expect header `Authorization: Bearer <access_token>`. Header is added in `Assets/SaiGame/Scripts/SaiServer.cs:196-211` (`CreateAuthenticatedRequest`) whenever `IsAuthenticated` is true. This means *every* request that goes through the `GetRequest` / `PostRequest` / `PutRequest` / `PatchRequest` / `DeleteRequest` helpers carries the token if a user is logged in. The four explicitly unauthenticated endpoints (`/api/v1/auth/login`, `/api/v1/auth/register`, `/api/v1/auth/refresh`, `/api/v1/client/auth/google/session` create) work fine because the helper simply skips the header when no token is set.

All bodies are sent with `Content-Type: application/json`.

## Endpoint table

> Discovery complete on 2026-05-20.

Legend:
- **Auth = No** means the call is normally made before a token exists; the request will still attach the header if one happens to be present.
- "dynamic" in body / response columns means the wire shape is built/consumed as raw JSON (not via a typed model) — verify against captured traffic.

---

## Auth

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| POST   | `/api/v1/auth/register`                       | No  | `RegisterRequest { email: string, username: string, password: string }` | `RegisterResponse { user: UserData }` | `Assets/SaiGame/Scripts/0_Auth/SaiAuth.cs:171` |
| POST   | `/api/v1/auth/login`                          | No  | `LoginRequest { username: string, password: string }` | `LoginResponse { user: UserData, access_token: string, refresh_token: string, expires_in: int }` | `Assets/SaiGame/Scripts/0_Auth/SaiAuth.cs:234` |
| POST   | `/api/v1/auth/refresh`                        | No  | `RefreshTokenRequest { refresh_token: string }` | `LoginResponse` (same shape as `/auth/login`) | `Assets/SaiGame/Scripts/0_Auth/SaiAuth.cs:308` |
| POST   | `/api/v1/auth/logout`                         | Yes | `{}` (empty literal) | empty / ignored | `Assets/SaiGame/Scripts/0_Auth/SaiAuth.cs:381` |
| GET    | `/api/v1/auth/me`                             | Yes | — | `GetMeResponse { user: UserData }` | `Assets/SaiGame/Scripts/0_Auth/SaiAuth.cs:435` |
| POST   | `/api/v1/client/auth/google/session`          | No  | `GoogleSessionRequest { game_id: string, platform: string, client_fingerprint: string }` | `GoogleSessionResponse { session_id: string, auth_url: string, expires_at: long, poll_interval_seconds: int }` | `Assets/SaiGame/Scripts/0_Auth/Google/GoogleBackendLogin.cs:34,132` |
| GET    | `/api/v1/client/auth/google/session/{session_id}` | No  | — | `GoogleSessionPollResponse { status: string, expires_at: long, error: string, user: UserData, access_token: string, refresh_token: string, expires_in: int }` | `Assets/SaiGame/Scripts/0_Auth/Google/GoogleBackendLogin.cs:202-204` |

`UserData` = `{ id: string, email: string, username: string, display_name: string, is_active: bool, is_verified: bool, created_at: long }` (`Assets/SaiGame/Scripts/0_Auth/UserData.cs`).

---

## GamerProgress

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| POST   | `/api/v1/games/{game_id}/gamer-progress`     | Yes | `{ user_id: string, game_id: string, experience: int=0, gold: int=0, game_data: object }` (hand-built JSON, not a serialized model; matches `CreateGamerProgressRequest`) | `CreateGamerProgressResponse { data: GamerProgressData, message: string }` | `Assets/SaiGame/Scripts/1_GamerProgress/GamerProgress.cs:240` |
| GET    | `/api/v1/games/{game_id}/my-gamer-progress`  | Yes | — | `GamerProgressData` (flat, not wrapped) | `Assets/SaiGame/Scripts/1_GamerProgress/GamerProgress.cs:315` |
| PATCH  | `/api/v1/gamer-progress/{progress_id}`       | Yes | `UpdateGamerProgressRequest { experience_delta: int, gold_delta: int, game_data: object }` (hand-built; `game_data` is dynamic JSON) | `GamerProgressData` (flat) | `Assets/SaiGame/Scripts/1_GamerProgress/GamerProgress.cs:379` |
| DELETE | `/api/v1/games/{game_id}/my-gamer-progress`  | Yes | — | empty / ignored | `Assets/SaiGame/Scripts/1_GamerProgress/GamerProgress.cs:462` |

`GamerProgressData` = `{ id, user_id, game_id: string, level, experience, gold: int, game_data: string (raw JSON), created_at, updated_at: long, version: int }` (`Assets/SaiGame/Scripts/1_GamerProgress/Models/GamerProgressData.cs`).

---

## Mailbox

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/mailbox/messages?limit={limit}&offset={offset}`     | Yes | — | `MailBoxResponse { messages: MailboxMessage[], total: int }` | `Assets/SaiGame/Scripts/2_Mailbox/Mailbox.cs:125` |
| PATCH  | `/api/v1/games/{game_id}/mailbox/messages/{message_id}` (mark read)         | Yes | `{ "read": true }` literal | `ReadMessageResponse { message: MailboxMessage, message_text: string }` *or* a flat `MailboxMessage` (helper tries both) | `Assets/SaiGame/Scripts/2_Mailbox/Mailbox.cs:184-187` |
| PATCH  | `/api/v1/games/{game_id}/mailbox/messages/{message_id}` (mark unread)       | Yes | `{ "read": false }` literal | `ReadMessageResponse` / `MailboxMessage` (same as above) | `Assets/SaiGame/Scripts/2_Mailbox/Mailbox.cs:257-260` |
| POST   | `/api/v1/games/{game_id}/mailbox/messages/{message_id}/claim`               | Yes | `{}` literal | `ClaimMessageResponse { rewards: ClaimReward[] }` | `Assets/SaiGame/Scripts/2_Mailbox/Mailbox.cs:328-330`, `Assets/SaiGame/Scripts/2_Mailbox/Mailbox.cs:478-481` |
| DELETE | `/api/v1/games/{game_id}/mailbox/messages/{message_id}/claim` (unclaim)     | Yes | — | empty / ignored | `Assets/SaiGame/Scripts/2_Mailbox/Mailbox.cs:401-403` |
| DELETE | `/api/v1/games/{game_id}/mailbox/messages/{message_id}` (delete message)    | Yes | — | empty / ignored | `Assets/SaiGame/Scripts/2_Mailbox/Mailbox.cs:565-567` |

`MailboxMessage` = `{ id, sender_id, subject, body, message_type, status: string, attachments: MailBoxAttachment[], expires_at, read_at, claimed_at, created_at: string }`. `MailBoxAttachment` = `{ type, definition_id: string, quantity: int, item_definition: ItemDefinitionData }`. `ClaimReward` = `{ type, definition_id: string, quantity: int }`.

---

## ItemContainer / Container

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/containers?limit={limit}&offset={offset}`         | Yes | — | `ContainerResponse { containers: ContainerData[], has_more: bool, limit: int, offset: int }` | `Assets/SaiGame/Scripts/3_ItemContainer/Container/PlayerContainer.cs:129` |
| GET    | `/api/v1/containers/{container_id}/items?limit={limit}&offset={offset}`     | Yes | — | `ContainerItemsResponse { container_id: string, items: InventoryItemData[] }` | `Assets/SaiGame/Scripts/3_ItemContainer/Container/PlayerContainer.cs:327` |
| POST   | `/api/v1/games/{game_id}/gacha/{gacha_pack_id}`                            | Yes | `{ idempotency_key: string, container_id: string }` (hand-built) | `GachaResponse { is_duplicate: bool, items_granted: GachaItemGranted[], mailbox_message_id: string, transaction_id: string }` | `Assets/SaiGame/Scripts/3_ItemContainer/Container/PlayerContainer.cs:397-401`, `Assets/SaiGame/Scripts/3_ItemContainer/Gacha/GachaPack.cs:77-81` |
| POST   | `/api/v1/games/{game_id}/gacha/by-code/{code}`                             | Yes | `{ idempotency_key: string, container_id: string }` (hand-built) | `GachaResponse` (same as above) | `Assets/SaiGame/Scripts/3_ItemContainer/Gacha/GachaPack.cs:167-171` |

`ContainerData` = `{ id, studio_id, game_id, owner_user_id, item_container_definition_id, container_type, position_data (raw JSON string), created_at, updated_at: string, definition: ContainerDefinitionData }`.

---

## ItemContainer / Tags

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/item-tags?limit={limit}&offset={offset}` | Yes | — | `ItemTagsResponse { limit: int, offset: int, tags: ItemTagData[], total: int }` | `Assets/SaiGame/Scripts/3_ItemContainer/Tag/ItemTag.cs:114-116` |
| GET    | `/api/v1/games/{game_id}/item-tags/{tag_key}/items`               | Yes | — | `InventoryResponse { items: InventoryItemData[], limit, offset, total: int }` | `Assets/SaiGame/Scripts/3_ItemContainer/Tag/ItemTag.cs:218-220` |

---

## ItemContainer / Slot (Equipment)

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/inventory/equipment-slots` | Yes | — | `EquipmentSlotsResponse { slots: EquipmentSlotData[], total: int }` | `Assets/SaiGame/Scripts/3_ItemContainer/Slot/EquipmentSlot.cs:109-111` |
| POST   | `/api/v1/games/{game_id}/inventory/equip`           | Yes | `{ item_id: string, slot_key: string, slot_data: object }` (hand-built; `slot_data` is dynamic JSON) | response is forwarded raw (no typed model) | `Assets/SaiGame/Scripts/3_ItemContainer/Slot/EquipmentSlot.cs:171-177` |
| POST   | `/api/v1/games/{game_id}/inventory/unequip`         | Yes | `{ item_id: string }` (hand-built) | response is forwarded raw | `Assets/SaiGame/Scripts/3_ItemContainer/Slot/EquipmentSlot.cs:221-224` |
| GET    | `/api/v1/games/{game_id}/inventory/equipped`        | Yes | — | `EquippedItemsResponse { equipped: EquippedItemData[] }` (each `EquippedItemData.slot_data` is re-extracted as raw JSON in `slot_data_raw`) | `Assets/SaiGame/Scripts/3_ItemContainer/Slot/EquipmentSlot.cs:268-270` |

---

## ItemContainer / Items

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/inventory?limit={limit}&offset={offset}&include_metadata=true[&category={category}]` | Yes | — | `InventoryResponse { items: InventoryItemData[], limit, offset, total: int }` (response is pre-sanitized — object fields like `base_stats`, `public_properties`, `private_properties` are converted to escaped strings before deserialization) | `Assets/SaiGame/Scripts/3_ItemContainer/Item/PlayerItem.cs:201` |
| PATCH  | `/api/v1/games/{game_id}/inventory-items/{item_id}` | Yes | `{ version: 0, properties: object }` (hand-built; `properties` is dynamic JSON) | `{ message: "properties updated successfully" }` (not modeled; caller treats response opaquely) | `Assets/SaiGame/Scripts/3_ItemContainer/Item/PlayerItem.cs:296-301` |
| GET    | `/api/v1/items/categories`                          | Yes (in practice — only called when authenticated; the helper still attaches header if logged in) | — | `ItemCategoriesResponse { categories: string[] }` | `Assets/SaiGame/Scripts/3_ItemContainer/Item/PlayerItem.cs:438-440` |
| PUT    | `/api/v2/games/{game_id}/item-inventories/{item_definition_id}/qty` | Yes | `{ quantity: int [, container_id: string] }` (hand-built; the optional `container_id` is included when provided) | response forwarded raw | `Assets/SaiGame/Scripts/3_ItemContainer/Item/ItemAddDeduct.cs:134-143` |
| POST   | `/api/v1/games/{game_id}/inventory/move`            | Yes | `{ item_id: string, target_container_id: string, quantity: int, grid_x: int, grid_y: int }` (hand-built) | response forwarded raw | `Assets/SaiGame/Scripts/3_ItemContainer/Item/ItemMove.cs:148-155` |
| POST   | `/api/v1/games/{game_id}/inventory/swap`            | Yes | `{ item_a_id: string, item_b_id: string }` (hand-built) | response forwarded raw | `Assets/SaiGame/Scripts/3_ItemContainer/Item/ItemSwap.cs:130-137` |

`InventoryItemData` = `{ id, studio_id, game_id, user_id, item_definition_id, item_container_id: string, grid_x, grid_y, quantity, level: int, custom_properties, private_properties, public_properties: string (raw JSON), acquired_at, last_modified_at: string, version: int, definition: ItemDefinitionData }`.

---

## ItemContainer / Preset

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| POST   | `/api/v1/games/{game_id}/presets`                              | Yes | `{ code_name: string, name?: string }` *or* `{ definition_id: string, name?: string }` (hand-built — caller picks one of the two key forms) | `PresetData` (flat) | `Assets/SaiGame/Scripts/3_ItemContainer/Preset/ItemPreset.cs:209-220` |
| GET    | `/api/v1/games/{game_id}/presets`                              | Yes | — | `PresetResponse { containers: PresetData[] }` | `Assets/SaiGame/Scripts/3_ItemContainer/Preset/ItemPreset.cs:494-496` |
| GET    | `/api/v1/games/{game_id}/presets/{preset_id}`                  | Yes | — | `PresetDetailResponse { container: PresetData, slots: PresetSlotData[] }` | `Assets/SaiGame/Scripts/3_ItemContainer/Preset/ItemPreset.cs:576-578` |
| PUT    | `/api/v1/games/{game_id}/presets/{preset_id}/slots/{slot_index}` | Yes | `{ inventory_item_id: string }` (hand-built) | response forwarded raw (caller then GETs `/presets/{preset_id}` to refresh) | `Assets/SaiGame/Scripts/3_ItemContainer/Preset/ItemPreset.cs:297-303` |
| DELETE | `/api/v1/games/{game_id}/presets/{preset_id}/slots/{slot_index}` | Yes | — | response forwarded raw (caller then GETs `/presets/{preset_id}` to refresh) | `Assets/SaiGame/Scripts/3_ItemContainer/Preset/ItemPreset.cs:401-406` |
| PATCH  | `/api/v1/games/{game_id}/presets/{preset_id}`                  | Yes | `{ name?: string, metadata?: object }` (hand-built; at least one field required; `metadata` is dynamic JSON) | `PresetData` (flat) | `Assets/SaiGame/Scripts/3_ItemContainer/Preset/ItemPreset.cs:730-749` |
| DELETE | `/api/v1/games/{game_id}/presets/{preset_id}`                  | Yes | — | response forwarded raw | `Assets/SaiGame/Scripts/3_ItemContainer/Preset/ItemPreset.cs:659-661` |

`PresetData` = `{ id, definition_id: string, definition: PresetDefinition, preset_type, name: string, max_slots: int, is_temp: bool, slots: PresetSlotData[], created_at, updated_at: string }`.

---

## ItemContainer / Crafting

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| POST   | `/api/v1/games/{game_id}/crafting/craft`                                | Yes | `CraftRequest { recipe_id: string, idempotency_key: string }` *or* `CraftByKeyRequest { recipe_key: string, idempotency_key: string }` | `CraftingResponse { transaction_id: string, success: bool, bonus_triggered: bool, output_items: CraftingOutputItem[], materials_used: CraftingMaterialItem[] }` | `Assets/SaiGame/Scripts/3_ItemContainer/Crafting/ItemCrafting.cs:161,183` |
| GET    | `/api/v1/games/{game_id}/crafting/history?page={page}&page_size={page_size}[&recipe_id=…][&status=…]` | Yes | — | `CraftingHistoryResponse { page, page_size, total: int, transactions: CraftingHistoryTransaction[] }` | `Assets/SaiGame/Scripts/3_ItemContainer/Crafting/ItemCrafting.cs:280` |
| GET    | `/api/v1/games/{game_id}/crafting/recipes-by-key/{recipe_key}`          | Yes | — | `RecipeDetail { id, studio_id, game_id, recipe_key, name, description, category: string, success_rate, bonus_rate: int, is_active: bool, metadata: RecipeMetadata, created_by, created_at, updated_at: string, inputs: RecipeInput[], outputs: RecipeOutput[] }` | `Assets/SaiGame/Scripts/3_ItemContainer/Crafting/ItemCrafting.cs:362` |

---

## ItemContainer / Generator

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/generators`                                          | Yes | — | Top-level JSON array `GeneratorData[]` (wrapped client-side into `{ generators: [...] }` for `JsonUtility`) — i.e. **the server returns a bare array** | `Assets/SaiGame/Scripts/3_ItemContainer/Generator/ItemGenerator.cs:122-131` |
| GET    | `/api/v1/games/{game_id}/generators/{inventory_item_id}`                      | Yes | — | `GeneratorData { definition_id, inventory_item_id: string, definition: GeneratorDefinition, ticket_count: int, is_full: bool, next_tick_in_seconds: int, checkpoint_at: string }` | `Assets/SaiGame/Scripts/3_ItemContainer/Generator/ItemGenerator.cs:350` |
| POST   | `/api/v1/games/{game_id}/generators/{inventory_item_id}/collect`              | Yes | `{}` literal | `GeneratorCollectResponse { units_collected: int, output_item_code: string, output_inventory_item_id: string }` | `Assets/SaiGame/Scripts/3_ItemContainer/Generator/ItemGenerator.cs:454-456` |

---

## Shop

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/shops?limit={limit}&offset={offset}`            | Yes | — | `ShopResponse { shops: ShopData[], limit, offset, total: int }` | `Assets/SaiGame/Scripts/4_Shop/Shop.cs:139` |
| GET    | `/api/v1/games/{game_id}/shops/{shop_id}/items`                          | Yes | — | `ShopItemsResponse { items: ShopItemData[], item_count: int, shop_id: string }` | `Assets/SaiGame/Scripts/4_Shop/Shop.cs:315` |
| POST   | `/api/v1/games/{game_id}/shops/{shop_id}/purchase`                       | Yes | `PurchaseRequest { shop_item_id: string, quantity: int, idempotency_key: string }` | `PurchaseResponse { purchase_record: PurchaseRecord }` | `Assets/SaiGame/Scripts/4_Shop/Shop.cs:406-416` |

---

## Quest / Chain

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/quests/chains?limit={limit}&offset={offset}`         | Yes | — | `ChainQuestResponse { chains: ChainQuestData[], limit, offset, total: int }` | `Assets/SaiGame/Scripts/5_Quest/Chain/ChainQuest.cs:132` |
| GET    | `/api/v1/games/{game_id}/quests/chains/{chain_id}/members`                    | Yes | — | `ChainMembersResponse { members: ChainMemberData[] }` | `Assets/SaiGame/Scripts/5_Quest/Chain/ChainQuest.cs:328` |
| GET    | `/api/v1/games/{game_id}/quests/chains/{chain_id}/tree`                       | Yes | — | `ChainQuestTreeResponse { chain_id: string, chain_name: string, nodes: QuestTreeNode[] }` | `Assets/SaiGame/Scripts/5_Quest/Chain/ChainQuest.cs:405` |

---

## Quest / Progress

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| POST   | `/api/v1/games/{game_id}/quests/{quest_definition_id}/start`         | Yes | `{}` literal | `StartQuestResponse { id, studio_id, game_id, user_id, quest_definition_id, status: string, version: int, created_at, updated_at: string }` | `Assets/SaiGame/Scripts/5_Quest/Progress/QuestProgressor.cs:197-199` |
| POST   | `/api/v1/games/{game_id}/quests/{quest_definition_id}/check`         | Yes | `{}` literal | `CheckQuestResponse { progress: CheckQuestProgressRecord, quest_definition: QuestDefinitionData, status: string }` (`progress.progress_data` is dynamic — re-extracted as raw JSON into `progress_data_json`) | `Assets/SaiGame/Scripts/5_Quest/Progress/QuestProgressor.cs:275-277` |
| POST   | `/api/v1/games/{game_id}/quests/{quest_definition_id}/claim`         | Yes | `{}` literal | `ClaimQuestResponse { id, studio_id, game_id, user_id, quest_definition_id, progress_id, idempotency_key: string, rewards_granted: ClaimQuestGrantedReward[], claimed_at: string }` | `Assets/SaiGame/Scripts/5_Quest/Progress/QuestProgressor.cs:362-364` |

---

## Quest / Claims & Status

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/quest-claims?limit={limit}&offset={offset}` | Yes | — | `QuestClaimsResponse { claims: QuestClaimRecord[], limit, offset, total: int }` | `Assets/SaiGame/Scripts/5_Quest/Claims/QuestHistory.cs:123` |
| GET    | `/api/v1/games/{game_id}/quests/{quest_definition_id}`               | Yes | — | `QuestDefinitionStatusResponse { progress: QuestProgressSnapshot, quest_definition: QuestDefinitionData, status: string }` (response contains an `operator` key which is read manually because `JsonUtility` can't map C# reserved words) | `Assets/SaiGame/Scripts/5_Quest/Claims/QuestHistory.cs:199` |

---

## Quest / Daily

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| POST   | `/api/v1/games/{game_id}/daily-quests/{dq_pool_id}/assign-ahead`     | Yes | `AssignAheadRequest { days_ahead: int }` | `AssignAheadResponse { pool_id: string, days_ahead: int, start_date, end_date: string, days: DailyDayData[] }` | `Assets/SaiGame/Scripts/5_Quest/Daily/DailyQuest.cs:142-150` |
| GET    | `/api/v1/games/{game_id}/daily-quest-pools`                          | Yes | — | `DailyQuestPoolsResponse { pools: DailyQuestPoolData[], limit, offset, total: int }` | `Assets/SaiGame/Scripts/5_Quest/Daily/DailyQuest.cs:238` |
| GET    | `/api/v1/games/{game_id}/daily-quests/{dq_pool_id}`                  | Yes | — | `TodayQuestResponse { pool: DailyQuestPoolData, entries: DailyQuestEntryData[], streak: DailyStreakData, assigned_date: string }` (each entry's `progress.progress_data` is dynamic — re-extracted into `progress_data_json`) | `Assets/SaiGame/Scripts/5_Quest/Daily/DailyQuest.cs:317` |

---

## Journey (PlayerEvent / analytics)

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| POST   | `/api/v1/games/{game_id}/events` | Yes | `{ event_type: string, session_id: string, event_data: object }` (hand-built; `event_data` is dynamic JSON, embedded raw) | `TrackEventResponse { message: string, event_id: string }` | `Assets/SaiGame/Scripts/6_Journey/PlayerEvent.cs:126-134` |

---

## Leaderboard

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/leaderboards`                                 | Yes | — | `LeaderboardBoardsResponse { boards: LeaderboardBoard[] }` | `Assets/SaiGame/Scripts/7_Leaderboard/Leaderboard.cs:131-133` |
| GET    | `/api/v1/games/{game_id}/leaderboards/{board_id}`                      | Yes | — | `LeaderboardBoardResponse { board: LeaderboardBoard }` *or* a flat `LeaderboardBoard` (client tries wrapped first, then flat) | `Assets/SaiGame/Scripts/7_Leaderboard/Leaderboard.cs:199-201` |
| GET    | `/api/v1/games/{game_id}/leaderboards/{board_id}/top?limit={limit}`    | Yes | — | `LeaderboardRankingsResponse { entries: LeaderboardRankingEntry[], limit: int, total: int }` | `Assets/SaiGame/Scripts/7_Leaderboard/Leaderboard.cs:273-275` |
| GET    | `/api/v1/games/{game_id}/leaderboards/{board_id}/me`                   | Yes | — | `LeaderboardLocalRankingResponse { rank: int, user_id: string, score: float, metadata: string, season: LeaderboardSeason, updated_at: string }` | `Assets/SaiGame/Scripts/7_Leaderboard/Leaderboard.cs:344-346` |

---

## Battle

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/me/battle-sessions?limit={limit}&offset={offset}` | Yes | — | `BattleSessionsResponse { limit, offset, total: int, sessions: BattleSessionData[] }` | `Assets/SaiGame/Scripts/8_Battle/BattleSessions.cs:123-125` |
| POST   | `/api/v1/games/{game_id}/scripts/{script_name}/run`                        | Yes | Free-form JSON object (default `{ "payload": {} }`). Reference model: `BattleScriptRequest { payload: BattleScriptPayload }` — the actual body is the Inspector-edited raw string sent verbatim. | dynamic (raw JSON string, beautified by the client; no typed model — `BattleScriptResponse { raw }` exists but isn't deserialized) | `Assets/SaiGame/Scripts/8_Battle/BattleScript.cs:69-71` |

---

## LuaScript

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/api/v1/games/{game_id}/scripts`             | Yes | — | Either a bare JSON array of script records, or one of `{ scripts: [...] }` / `{ data: [...] }` / `{ items: [...] }` (client tries all). Record shape: `{ id, name, description, script_body: string, version: int, is_active, is_library: bool, created_by, created_at, updated_at: string }` | `Assets/SaiGame/Scripts/9_LuaScript/LuaScriptManager.cs:274-275` |
| POST   | `/api/v1/games/{game_id}/scripts`             | Yes | `CreateRequest { name: string, description: string, script_body: string }` | `{ id: string, ... }` (only `id` is read by the client) | `Assets/SaiGame/Scripts/9_LuaScript/LuaScriptManager.cs:370-373` |
| PATCH  | `/api/v1/games/{game_id}/scripts/{script_id}` (full update) | Yes | `UpdateRequest { description: string, script_body: string, is_active: bool, is_library: bool }` | `{ id: string, ... }` | `Assets/SaiGame/Scripts/9_LuaScript/LuaScriptManager.cs:389-392` |
| PATCH  | `/api/v1/games/{game_id}/scripts/{script_id}` (flags only)  | Yes | `FlagsRequest { is_active: bool, is_library: bool }` | `{ id: string, ... }` | `Assets/SaiGame/Scripts/9_LuaScript/LuaScriptManager.cs:409-412` |
| DELETE | `/api/v1/games/{game_id}/scripts/{script_id}` | Yes | — | response forwarded raw | `Assets/SaiGame/Scripts/9_LuaScript/LuaScriptManager.cs:419-420` |

---

## Health / connectivity

| Method | Path | Auth | Body | Response | Upstream ref |
|--------|------|------|------|----------|--------------|
| GET    | `/health` | No (uses bare `UnityWebRequest.Get`, no `Authorization` header is set) | — | response is ignored; only HTTP success boolean is reported | `Assets/SaiGame/Scripts/SaiServer.cs:729-742` |

---

## Notes / non-obvious behavior

- **Google login is a two-step polling flow.** `POST /api/v1/client/auth/google/session` returns a `session_id` + `auth_url` (browser is opened to that URL). The client then polls `GET /api/v1/client/auth/google/session/{session_id}` every `poll_interval_seconds` until `status == "completed" | "denied" | "expired" | "error"`. See `GoogleBackendLogin.cs:152-198`. The `GET` URL is **not** a static path — `session_id` comes from the previous `POST` and is URL-escaped.
- **Two `PATCH /presets/{preset_id}` shapes coexist.** Same path, two different bodies depending on whether the caller wants to rename, change metadata, or both.
- **Two `PATCH /scripts/{script_id}` shapes coexist** (full body vs. flags-only). Same endpoint, different schemas.
- **`GET /generators` returns a bare JSON array**, not a wrapper object. Client wraps it on the way in.
- **`GET /scripts` accepts three possible wrapper shapes** (`scripts`, `data`, `items`) and falls back to bare array. Backend's canonical shape is not documented from the SDK side.
- **Gacha and crafting bodies require client-supplied `idempotency_key`.** Gacha generates a random multi-segment string per call; crafting falls back to `Guid.NewGuid()` if the caller didn't pass one.
- **`/api/v2/games/{game_id}/item-inventories/{item_definition_id}/qty`** is the only `v2` endpoint in the entire SDK — every other endpoint is `v1`.
- **`{}` literal POST bodies** are used by claim, unclaim → claim, generator collect, quest start/check/claim, and logout. None of these take a real request body.
- **Mailbox `PATCH .../{message_id}` with `{"read": true|false}`** is the same endpoint for read and unread — only the body differs.
- **Two endpoints accept dynamic / arbitrary JSON values in their request body**: `equip` (`slot_data`), `update gamer-progress` (`game_data`), `create gamer-progress` (`game_data`), `update preset` (`metadata`), `update item properties` (`properties`), `track event` (`event_data`), and `run script` (whole body). These are flagged "dynamic" above. They are built by hand-concatenated strings, not serialized typed models, so the Godot port should treat them as `Dictionary<string, object>` / Godot `Dictionary` rather than strongly-typed DTOs.
- **No multipart upload, no websocket, no streaming endpoints** were found in the SDK. All traffic is REST + JSON.
- **`/health` is the only endpoint that bypasses `CreateAuthenticatedRequest`** and therefore never sends an `Authorization` header.
