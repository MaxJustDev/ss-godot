## Unit tests for the M4 ItemContainer family (PlayerContainer, PlayerItem,
## ItemAddDeduct, ItemPreset, ItemCrafting, ItemGenerator, EquipmentSlot,
## ItemTag, GachaPack).
##
## Runs against a FakeSaiServer test double — does NOT hit a real backend.
## Requires the GUT framework.
##
## upstream parity: 3_ItemContainer/**/*.cs
extends "res://addons/gut/test.gd"

const PLAYER_CONTAINER := preload(
	"res://addons/sai_services/item_container/container/player_container.gd"
)
const GACHA_PACK := preload("res://addons/sai_services/item_container/container/gacha_pack.gd")
const PLAYER_ITEM := preload("res://addons/sai_services/item_container/item/player_item.gd")
const ITEM_ADD_DEDUCT := preload("res://addons/sai_services/item_container/item/item_add_deduct.gd")
const ITEM_TAG := preload("res://addons/sai_services/item_container/tag/item_tag.gd")
const EQUIPMENT_SLOT := preload("res://addons/sai_services/item_container/slot/equipment_slot.gd")
const ITEM_PRESET := preload("res://addons/sai_services/item_container/preset/item_preset.gd")
const ITEM_CRAFTING := preload("res://addons/sai_services/item_container/crafting/item_crafting.gd")
const ITEM_GENERATOR := preload(
	"res://addons/sai_services/item_container/generator/item_generator.gd"
)

# =========================================================================
# Test double
# =========================================================================


class FakeSaiServer:
	extends Node

	var _next_responses: Array = []
	var calls: Array = []
	var _access_token: String = ""
	var _game_id: String = "test_game"

	func queue_response(response: Dictionary) -> void:
		_next_responses.append(response)

	func _take_next() -> Dictionary:
		if _next_responses.is_empty():
			return {"success": false, "status": 0, "error": "no_canned_response", "data": null}
		return _next_responses.pop_front()

	func get_request(path: String, query: Dictionary = {}, auth: bool = true) -> Dictionary:
		calls.append({"method": "GET", "path": path, "query": query, "auth": auth})
		return _take_next()

	func post_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "POST", "path": path, "body": body, "auth": auth})
		return _take_next()

	func put_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "PUT", "path": path, "body": body, "auth": auth})
		return _take_next()

	func patch_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "PATCH", "path": path, "body": body, "auth": auth})
		return _take_next()

	func delete_request(path: String, body: Variant = null, auth: bool = true) -> Dictionary:
		calls.append({"method": "DELETE", "path": path, "body": body, "auth": auth})
		return _take_next()

	func is_authenticated() -> bool:
		return not _access_token.is_empty()

	func access_token() -> String:
		return _access_token

	func normalized_game_id() -> String:
		return _game_id

	func login() -> void:
		_access_token = "AT_test"


# =========================================================================
# Helpers
# =========================================================================

var _server: FakeSaiServer = null


func before_each() -> void:
	_server = FakeSaiServer.new()
	_server.name = "SaiServer"
	add_child_autofree(_server)


func _attach(klass) -> Node:
	var node: Node = klass.new()
	_server.add_child(node)
	return node


# =========================================================================
# PlayerContainer
# =========================================================================


func test_get_containers_happy_path() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"containers":
					[
						{
							"id": "c_1",
							"container_type": "bag",
							"definition":
							{"id": "def_bag", "name": "Bag", "grid_cols": 4, "grid_rows": 4},
						}
					],
					"has_more": false,
					"limit": 50,
					"offset": 0,
				}
			}
		)
	)

	var pc: PlayerContainer = _attach(PLAYER_CONTAINER)
	watch_signals(pc)
	var result: Dictionary = await pc.get_containers()

	assert_true(result.get("success", false))
	assert_signal_emitted(pc, "containers_loaded")
	assert_eq(_server.calls[0]["method"], "GET")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/containers")
	var containers: Array = result.data.containers
	assert_eq(containers.size(), 1)
	assert_eq(containers[0].id, "c_1")
	assert_eq(containers[0].definition.name, "Bag")


func test_get_containers_unauthenticated_fails_fast() -> void:
	var pc: PlayerContainer = _attach(PLAYER_CONTAINER)
	watch_signals(pc)
	var result: Dictionary = await pc.get_containers()
	assert_false(result.get("success", true))
	assert_signal_emitted(pc, "containers_failed")
	assert_eq(_server.calls.size(), 0)


func test_get_items_for_container() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"container_id": "c_1",
					"items": [{"id": "i_1", "item_definition_id": "d_sword", "quantity": 1}],
				}
			}
		)
	)
	var pc: PlayerContainer = _attach(PLAYER_CONTAINER)
	var result: Dictionary = await pc.get_items("c_1")
	assert_true(result.get("success", false))
	assert_eq(_server.calls[0]["path"], "/api/v1/containers/c_1/items")
	assert_eq(result.data.items.size(), 1)
	assert_eq(result.data.items[0].id, "i_1")


func test_open_gacha_pack_emits_success() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"is_duplicate": false,
					"items_granted": [{"item_definition_id": "d_gem", "quantity": 3}],
					"transaction_id": "tx_1",
				}
			}
		)
	)
	var pc: PlayerContainer = _attach(PLAYER_CONTAINER)
	watch_signals(pc)
	var result: Dictionary = await pc.open_gacha_pack("g_pack_1", "c_1")
	assert_true(result.get("success", false))
	assert_signal_emitted(pc, "gacha_success")
	assert_eq(_server.calls[0]["method"], "POST")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/gacha/g_pack_1")
	var dto: GachaResponse = result.data
	assert_eq(dto.transaction_id, "tx_1")
	assert_eq(dto.items_granted.size(), 1)
	# Body should include idempotency_key + container_id.
	var body: Dictionary = _server.calls[0]["body"]
	assert_true(body.has("idempotency_key"))
	assert_eq(body["container_id"], "c_1")


# =========================================================================
# GachaPack (by-code variant)
# =========================================================================


func test_gacha_open_by_code_uses_by_code_path() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"is_duplicate": true, "items_granted": [], "transaction_id": "tx_2"},
			}
		)
	)
	var gp: GachaPack = _attach(GACHA_PACK)
	var result: Dictionary = await gp.open_by_code("SPRING_BANNER", "c_1")
	assert_true(result.get("success", false))
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/gacha/by-code/SPRING_BANNER")
	assert_true((result.data as GachaResponse).is_duplicate)


# =========================================================================
# PlayerItem
# =========================================================================


func test_get_items_happy_path() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"items": [{"id": "i_1", "quantity": 5}],
					"limit": 50,
					"offset": 0,
					"total": 1,
				}
			}
		)
	)
	var pi: PlayerItem = _attach(PLAYER_ITEM)
	watch_signals(pi)
	var result: Dictionary = await pi.get_items()
	assert_true(result.get("success", false))
	assert_signal_emitted(pi, "items_loaded")
	assert_eq(result.data.total, 1)


func test_move_item_emits_success() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"ok": true},
			}
		)
	)
	var pi: PlayerItem = _attach(PLAYER_ITEM)
	watch_signals(pi)
	var result: Dictionary = await pi.move_item("i_1", "c_2", 1, 0, 0)
	assert_true(result.get("success", false))
	assert_signal_emitted(pi, "move_success")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/inventory/move")
	var body: Dictionary = _server.calls[0]["body"]
	assert_eq(body["item_id"], "i_1")
	assert_eq(body["target_container_id"], "c_2")
	assert_eq(body["quantity"], 1)


func test_swap_items_refuses_identical_ids() -> void:
	_server.login()
	var pi: PlayerItem = _attach(PLAYER_ITEM)
	watch_signals(pi)
	var result: Dictionary = await pi.swap_items("i_1", "i_1")
	assert_false(result.get("success", true))
	assert_signal_emitted(pi, "swap_failed")
	assert_eq(_server.calls.size(), 0)


# =========================================================================
# ItemAddDeduct — only `/api/v2/` endpoint in the SDK.
# =========================================================================


func test_add_deduct_uses_v2_prefix() -> void:
	_server.login()
	_server.queue_response({"success": true, "status": 200, "error": "", "data": {"ok": true}})
	var iad: ItemAddDeduct = _attach(ITEM_ADD_DEDUCT)
	watch_signals(iad)
	var result: Dictionary = await iad.add_deduct("d_gold", 100, "c_1")
	assert_true(result.get("success", false))
	assert_signal_emitted(iad, "add_deduct_success")
	# Path uses /api/v2/ NOT /api/v1/.
	assert_eq(_server.calls[0]["method"], "PUT")
	assert_eq(_server.calls[0]["path"], "/api/v2/games/test_game/item-inventories/d_gold/qty")
	var body: Dictionary = _server.calls[0]["body"]
	assert_eq(body["quantity"], 100)
	assert_eq(body["container_id"], "c_1")


func test_add_deduct_refuses_zero_quantity() -> void:
	_server.login()
	var iad: ItemAddDeduct = _attach(ITEM_ADD_DEDUCT)
	watch_signals(iad)
	var result: Dictionary = await iad.add_deduct("d_gold", 0)
	assert_false(result.get("success", true))
	assert_signal_emitted(iad, "add_deduct_failed")
	assert_eq(_server.calls.size(), 0)


# =========================================================================
# ItemTag
# =========================================================================


func test_get_tags_happy_path() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"tags": [{"id": "t_1", "tag_key": "weapon", "label": "Weapons"}],
					"total": 1,
					"limit": 50,
					"offset": 0,
				}
			}
		)
	)
	var it: ItemTag = _attach(ITEM_TAG)
	watch_signals(it)
	var result: Dictionary = await it.get_tags()
	assert_true(result.get("success", false))
	assert_signal_emitted(it, "tags_loaded")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/item-tags")
	assert_eq(result.data.total, 1)
	assert_eq((result.data.tags[0] as ItemTagData).tag_key, "weapon")


# =========================================================================
# EquipmentSlot
# =========================================================================


func test_get_slots_happy_path() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"slots": [{"id": "s_1", "slot_key": "weapon"}], "total": 1},
			}
		)
	)
	var es: EquipmentSlot = _attach(EQUIPMENT_SLOT)
	watch_signals(es)
	var result: Dictionary = await es.get_slots()
	assert_true(result.get("success", false))
	assert_signal_emitted(es, "slots_loaded")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/inventory/equipment-slots")


func test_equip_item_sends_slot_data() -> void:
	_server.login()
	_server.queue_response({"success": true, "status": 200, "error": "", "data": {"ok": true}})
	var es: EquipmentSlot = _attach(EQUIPMENT_SLOT)
	watch_signals(es)
	await es.equip_item("i_1", "weapon", {"glow": true})
	assert_signal_emitted(es, "equip_success")
	var body: Dictionary = _server.calls[0]["body"]
	assert_eq(body["item_id"], "i_1")
	assert_eq(body["slot_key"], "weapon")
	assert_eq(body["slot_data"], {"glow": true})


# =========================================================================
# ItemPreset — including dual PATCH body shapes + slot-add refresh chain.
# =========================================================================


func test_create_by_code_name_sends_code_name_body() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 201,
				"error": "",
				"data":
				{
					"id": "p_1",
					"definition_id": "d_loadout",
					"preset_type": "loadout",
					"max_slots": 4
				},
			}
		)
	)
	var ip: ItemPreset = _attach(ITEM_PRESET)
	watch_signals(ip)
	var result: Dictionary = await ip.create_by_code_name("favorite_loadout", "Favs")
	assert_true(result.get("success", false))
	assert_signal_emitted(ip, "create_success")
	var body: Dictionary = _server.calls[0]["body"]
	assert_eq(body["code_name"], "favorite_loadout")
	assert_eq(body["name"], "Favs")
	assert_false(body.has("definition_id"))


func test_rename_preset_only_sends_name() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"id": "p_1", "name": "Renamed"},
			}
		)
	)
	var ip: ItemPreset = _attach(ITEM_PRESET)
	watch_signals(ip)
	await ip.rename_preset("p_1", "Renamed")
	var body: Dictionary = _server.calls[0]["body"]
	assert_eq(body["name"], "Renamed")
	assert_false(body.has("metadata"))


func test_update_preset_metadata_only_sends_metadata() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"id": "p_1"},
			}
		)
	)
	var ip: ItemPreset = _attach(ITEM_PRESET)
	await ip.update_preset_metadata("p_1", {"theme": "dark"})
	var body: Dictionary = _server.calls[0]["body"]
	assert_eq(body["metadata"], {"theme": "dark"})
	assert_false(body.has("name"))


func test_update_preset_with_no_fields_fails_fast() -> void:
	_server.login()
	var ip: ItemPreset = _attach(ITEM_PRESET)
	watch_signals(ip)
	var result: Dictionary = await ip.update_preset("p_1", "", null)
	assert_false(result.get("success", true))
	assert_signal_emitted(ip, "update_failed")
	assert_eq(_server.calls.size(), 0)


func test_add_item_to_preset_does_put_then_refresh_get() -> void:
	_server.login()
	# PUT response (any payload).
	_server.queue_response({"success": true, "status": 200, "error": "", "data": {"ok": true}})
	# Refresh GET response.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"container": {"id": "p_1", "preset_type": "loadout", "max_slots": 4},
					"slots": [{"slot_index": 0, "inventory_item_id": "i_sword"}],
				},
			}
		)
	)
	var ip: ItemPreset = _attach(ITEM_PRESET)
	watch_signals(ip)
	var result: Dictionary = await ip.add_item_to_preset("p_1", 0, "i_sword")
	assert_true(result.get("success", false))
	assert_signal_emitted(ip, "slot_added")
	# Two calls — PUT then GET.
	assert_eq(_server.calls.size(), 2)
	assert_eq(_server.calls[0]["method"], "PUT")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/presets/p_1/slots/0")
	assert_eq(_server.calls[1]["method"], "GET")
	assert_eq(_server.calls[1]["path"], "/api/v1/games/test_game/presets/p_1")
	# Refreshed preset has the slot.
	var dto: PresetData = result.data
	assert_eq(dto.slots.size(), 1)
	assert_eq(dto.slots[0].inventory_item_id, "i_sword")


func test_delete_preset_removes_from_cache() -> void:
	_server.login()
	_server.queue_response({"success": true, "status": 200, "error": "", "data": null})
	var ip: ItemPreset = _attach(ITEM_PRESET)
	# Pre-seed cached preset.
	var cached := PresetData.new()
	cached.id = "p_1"
	ip.current_presets = [cached]
	watch_signals(ip)
	await ip.delete_preset("p_1")
	assert_signal_emitted(ip, "delete_success")
	assert_eq(ip.current_presets.size(), 0)


# =========================================================================
# ItemCrafting
# =========================================================================


func test_craft_includes_idempotency_key_and_recipe_id() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"transaction_id": "tx_3", "success": true, "bonus_triggered": false},
			}
		)
	)
	var ic: ItemCrafting = _attach(ITEM_CRAFTING)
	watch_signals(ic)
	var result: Dictionary = await ic.craft("r_1")
	assert_true(result.get("success", false))
	assert_signal_emitted(ic, "craft_success")
	assert_eq(_server.calls[0]["path"], "/api/v1/games/test_game/crafting/craft")
	var body: Dictionary = _server.calls[0]["body"]
	assert_eq(body["recipe_id"], "r_1")
	assert_true(body.has("idempotency_key"))
	assert_false(body["idempotency_key"].is_empty())


func test_get_recipe_by_key_path() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data": {"id": "r_1", "recipe_key": "iron_sword", "name": "Iron Sword"},
			}
		)
	)
	var ic: ItemCrafting = _attach(ITEM_CRAFTING)
	var result: Dictionary = await ic.get_recipe_by_key("iron_sword")
	assert_true(result.get("success", false))
	assert_eq(
		_server.calls[0]["path"], "/api/v1/games/test_game/crafting/recipes-by-key/iron_sword"
	)
	var dto: RecipeDetail = result.data
	assert_eq(dto.recipe_key, "iron_sword")


# =========================================================================
# ItemGenerator — bare-array response.
# =========================================================================


func test_get_generators_handles_bare_array() -> void:
	_server.login()
	# Server returns BARE array — no wrapping object.
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				[
					{
						"inventory_item_id": "g_1",
						"definition_id": "d_gen",
						"ticket_count": 5,
						"is_full": false,
						"next_tick_in_seconds": 60,
					},
				]
			}
		)
	)
	var ig: ItemGenerator = _attach(ITEM_GENERATOR)
	watch_signals(ig)
	var result: Dictionary = await ig.get_generators()
	assert_true(result.get("success", false))
	assert_signal_emitted(ig, "generators_loaded")
	var gens: Array = result.data
	assert_eq(gens.size(), 1)
	assert_eq((gens[0] as GeneratorData).inventory_item_id, "g_1")
	assert_eq((gens[0] as GeneratorData).ticket_count, 5)


func test_collect_generator_returns_collect_response() -> void:
	_server.login()
	(
		_server
		. queue_response(
			{
				"success": true,
				"status": 200,
				"error": "",
				"data":
				{
					"units_collected": 3,
					"output_item_code": "gem",
					"output_inventory_item_id": "out_1"
				},
			}
		)
	)
	# Queue a stub GET for the post-collect refresh fire-and-forget.
	_server.queue_response({"success": false, "status": 0, "error": "ignored", "data": null})
	var ig: ItemGenerator = _attach(ITEM_GENERATOR)
	watch_signals(ig)
	var result: Dictionary = await ig.collect_generator("g_1")
	assert_true(result.get("success", false))
	assert_signal_emitted(ig, "generator_collected")
	var dto: GeneratorCollectResponse = result.data
	assert_eq(dto.units_collected, 3)
	assert_eq(dto.output_item_code, "gem")


# =========================================================================
# DTO smoke tests — round-trip dict ↔ resource.
# =========================================================================


func test_container_data_round_trip() -> void:
	var src: Dictionary = {
		"id": "c_1",
		"container_type": "bag",
		"position_data": {"x": 1, "y": 2},
		"definition": {"id": "def_bag", "grid_cols": 3},
	}
	var c := ContainerData.from_dict(src)
	assert_eq(c.id, "c_1")
	assert_eq(c.container_type, "bag")
	# position_data was passed as a Dictionary — should be stringified.
	var parsed: Variant = JSON.parse_string(c.position_data)
	assert_eq(parsed, {"x": 1, "y": 2})
	assert_eq(c.definition.grid_cols, 3)


func test_inventory_item_data_round_trip() -> void:
	var src: Dictionary = {
		"id": "i_1",
		"quantity": 7,
		"public_properties": {"skin": "gold"},
		"definition": {"id": "d_1", "name": "Sword"},
	}
	var it := InventoryItemData.from_dict(src)
	assert_eq(it.quantity, 7)
	# public_properties was a Dictionary, must round-trip via stringify.
	assert_eq(JSON.parse_string(it.public_properties), {"skin": "gold"})
	assert_eq(it.definition.name, "Sword")
