## CraftingHistoryTransaction - typed mirror of a single past craft record.
##
## upstream: 3_ItemContainer/Crafting/Models/CraftingHistoryTransaction.cs:6
class_name CraftingHistoryTransaction
extends Resource

## upstream: CraftingHistoryTransaction.cs:8
@export var id: String = ""
## upstream: CraftingHistoryTransaction.cs:9
@export var studio_id: String = ""
## upstream: CraftingHistoryTransaction.cs:10
@export var game_id: String = ""
## upstream: CraftingHistoryTransaction.cs:11
@export var user_id: String = ""
## upstream: CraftingHistoryTransaction.cs:12
@export var recipe_id: String = ""
## upstream: CraftingHistoryTransaction.cs:13
@export var idempotency_key: String = ""
## upstream: CraftingHistoryTransaction.cs:14
@export var status: String = ""
## upstream: CraftingHistoryTransaction.cs:15
@export var success: bool = false
## upstream: CraftingHistoryTransaction.cs:16
@export var bonus_triggered: bool = false
## upstream: CraftingHistoryTransaction.cs:17
@export var materials_snapshot: Array[CraftingMaterialItem] = []
## upstream: CraftingHistoryTransaction.cs:18
@export var outputs_snapshot: Array[CraftingOutputItem] = []
## upstream: CraftingHistoryTransaction.cs:19
@export var created_at: String = ""
## upstream: CraftingHistoryTransaction.cs:20
@export var recipe_detail: RecipeDetail = null


static func from_dict(d: Variant) -> CraftingHistoryTransaction:
	var out := CraftingHistoryTransaction.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.id = String(dict.get("id", ""))
	out.studio_id = String(dict.get("studio_id", ""))
	out.game_id = String(dict.get("game_id", ""))
	out.user_id = String(dict.get("user_id", ""))
	out.recipe_id = String(dict.get("recipe_id", ""))
	out.idempotency_key = String(dict.get("idempotency_key", ""))
	out.status = String(dict.get("status", ""))
	out.success = bool(dict.get("success", false))
	out.bonus_triggered = bool(dict.get("bonus_triggered", false))
	var mats: Variant = dict.get("materials_snapshot", null)
	if mats is Array:
		var t1: Array[CraftingMaterialItem] = []
		for m in mats:
			t1.append(CraftingMaterialItem.from_dict(m))
		out.materials_snapshot = t1
	var outs: Variant = dict.get("outputs_snapshot", null)
	if outs is Array:
		var t2: Array[CraftingOutputItem] = []
		for o in outs:
			t2.append(CraftingOutputItem.from_dict(o))
		out.outputs_snapshot = t2
	out.created_at = String(dict.get("created_at", ""))
	var rec: Variant = dict.get("recipe_detail", null)
	if rec is Dictionary:
		out.recipe_detail = RecipeDetail.from_dict(rec)
	return out


func to_dict() -> Dictionary:
	var m_arr: Array = []
	for m in materials_snapshot:
		m_arr.append(m.to_dict())
	var o_arr: Array = []
	for o in outputs_snapshot:
		o_arr.append(o.to_dict())
	return {
		"id": id,
		"studio_id": studio_id,
		"game_id": game_id,
		"user_id": user_id,
		"recipe_id": recipe_id,
		"idempotency_key": idempotency_key,
		"status": status,
		"success": success,
		"bonus_triggered": bonus_triggered,
		"materials_snapshot": m_arr,
		"outputs_snapshot": o_arr,
		"created_at": created_at,
		"recipe_detail": recipe_detail.to_dict() if recipe_detail != null else {},
	}
