## GeneratorData - typed mirror of a single generator instance.
##
## Local-calculation helpers (`get_current_pending_units`,
## `get_seconds_until_full`, etc.) port the upstream client-side timer
## projection used to update UI between server syncs. Server's `ticket_count`
## is the CURRENT real count at the moment of the API call — when ingesting
## fresh server data, call `sync_checkpoint_to_now()` before display.
##
## upstream: 3_ItemContainer/Generator/GeneratorData.cs:11
class_name GeneratorData
extends Resource

const DEFAULT_COLLECT_DESTINATION := "mailbox"

## upstream: GeneratorData.cs:13
@export var definition_id: String = ""
## upstream: GeneratorData.cs:14
@export var inventory_item_id: String = ""
## upstream: GeneratorData.cs:15
@export var definition: GeneratorDefinition = null
## upstream: GeneratorData.cs:16
@export var ticket_count: int = 0
## upstream: GeneratorData.cs:17
@export var is_full: bool = false
## upstream: GeneratorData.cs:18
@export var next_tick_in_seconds: int = 0
## upstream: GeneratorData.cs:19
@export var checkpoint_at: String = ""
## upstream: GeneratorData.cs:22
@export var enable_local_calculation: bool = true


static func from_dict(d: Variant) -> GeneratorData:
	var out := GeneratorData.new()
	if not (d is Dictionary):
		return out
	var dict: Dictionary = d
	out.definition_id = String(dict.get("definition_id", ""))
	out.inventory_item_id = String(dict.get("inventory_item_id", ""))
	var def: Variant = dict.get("definition", null)
	if def is Dictionary:
		out.definition = GeneratorDefinition.from_dict(def)
	out.ticket_count = int(dict.get("ticket_count", 0))
	out.is_full = bool(dict.get("is_full", false))
	out.next_tick_in_seconds = int(dict.get("next_tick_in_seconds", 0))
	out.checkpoint_at = String(dict.get("checkpoint_at", ""))
	out.enable_local_calculation = bool(dict.get("enable_local_calculation", true))
	return out


func to_dict() -> Dictionary:
	return {
		"definition_id": definition_id,
		"inventory_item_id": inventory_item_id,
		"definition": definition.to_dict() if definition != null else {},
		"ticket_count": ticket_count,
		"is_full": is_full,
		"next_tick_in_seconds": next_tick_in_seconds,
		"checkpoint_at": checkpoint_at,
		"enable_local_calculation": enable_local_calculation,
	}


# ── Config accessors ────────────────────────────────────────────────────────


## upstream: GeneratorData.cs:25 (Config)
func config() -> GeneratorConfig:
	if definition == null:
		return null
	return definition.generator_config


## upstream: GeneratorData.cs:27 (tick_capacity)
func tick_capacity() -> int:
	var c: GeneratorConfig = config()
	return c.tick_capacity if c != null else 0


## upstream: GeneratorData.cs:29 (production_interval_seconds)
func production_interval_seconds() -> int:
	var c: GeneratorConfig = config()
	return c.production_interval_seconds if c != null else 0


## upstream: GeneratorData.cs:33-40 (collect_destination property)
func collect_destination() -> String:
	var c: GeneratorConfig = config()
	if c == null or c.collect_destination.is_empty():
		return DEFAULT_COLLECT_DESTINATION
	return c.collect_destination


## upstream: GeneratorData.cs:42 (output_pool property)
func output_pool() -> Array[GeneratorOutputPool]:
	var c: GeneratorConfig = config()
	if c != null:
		return c.output_pool
	var empty: Array[GeneratorOutputPool] = []
	return empty


## upstream: GeneratorData.cs:45 (capacity property)
func capacity() -> int:
	return tick_capacity()


# ── Local calculation helpers ───────────────────────────────────────────────


## upstream: GeneratorData.cs:53 (GetCurrentPendingUnits)
func get_current_pending_units() -> int:
	if not enable_local_calculation:
		return ticket_count
	var elapsed: float = _elapsed_seconds_since_checkpoint()
	if elapsed < 0:
		return ticket_count
	var first_tick: int = next_tick_in_seconds
	if elapsed < first_tick:
		return ticket_count
	var interval: int = production_interval_seconds()
	if interval <= 0:
		return ticket_count
	var elapsed_after_first: float = elapsed - first_tick
	var new_ticks: int = 1 + int(elapsed_after_first / interval)
	return mini(ticket_count + new_ticks, capacity())


## upstream: GeneratorData.cs:117 (GetSecondsUntilFull)
func get_seconds_until_full() -> float:
	var current: int = get_current_pending_units()
	if current >= capacity():
		return 0.0
	var units_needed: int = capacity() - current
	var dynamic_next: int = get_dynamic_next_tick_seconds()
	if units_needed <= 1:
		return float(dynamic_next)
	return dynamic_next + (units_needed - 1) * production_interval_seconds()


## upstream: GeneratorData.cs:159 (IsAtCapacity)
func is_at_capacity() -> bool:
	return get_current_pending_units() >= capacity()


## upstream: GeneratorData.cs:168 (GetDynamicNextTickSeconds)
func get_dynamic_next_tick_seconds() -> int:
	if not enable_local_calculation:
		return next_tick_in_seconds
	if is_at_capacity():
		return 0
	var elapsed: float = _elapsed_seconds_since_checkpoint()
	if elapsed < 0:
		return next_tick_in_seconds
	var remaining: float = next_tick_in_seconds - elapsed
	if remaining > 0:
		return int(remaining)
	var interval: int = production_interval_seconds()
	if interval <= 0:
		return 0
	var past_first: float = elapsed - next_tick_in_seconds
	var remainder: float = fmod(past_first, interval)
	var until_next: int = int(interval - remainder)
	return clampi(until_next, 0, interval)


## upstream: GeneratorData.cs:210 (SyncCheckpointToNow)
func sync_checkpoint_to_now() -> void:
	checkpoint_at = Time.get_datetime_string_from_system(true) + "Z"


# ── Internal ────────────────────────────────────────────────────────────────


func _elapsed_seconds_since_checkpoint() -> float:
	if checkpoint_at.is_empty():
		return 0.0
	# Strip Z suffix and timezone designators because Time.get_unix_time_from_datetime_string
	# only accepts ISO-8601 without trailing 'Z'.
	var iso: String = checkpoint_at
	if iso.ends_with("Z"):
		iso = iso.substr(0, iso.length() - 1)
	var t: float = Time.get_unix_time_from_datetime_string(iso)
	if t == 0:
		return 0.0
	var now: float = Time.get_unix_time_from_system()
	return now - t
