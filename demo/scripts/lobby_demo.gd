## Lobby demo scene controller.
##
## Minimal post-login surface that exercises `SaiServer.progress` (M3a).
## Attach to a Control node with these direct children:
##   - WelcomeLabel  (Label) — shows "Logged in as $USERNAME"
##   - SaveButton    (Button)
##   - LoadButton    (Button)
##   - ResetButton   (Button)
##   - StatusLabel   (Label) — last action / error
##
## Mirrors `docs/examples/progress.md`.
extends Control

@onready var welcome_label: Label = $WelcomeLabel
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	_refresh_welcome()
	if SaiServer == null:
		status_label.text = "SaiServer autoload not registered."
		return

	SaiServer.progress.create_success.connect(_on_create_ok)
	SaiServer.progress.create_failed.connect(_on_create_err)
	SaiServer.progress.get_success.connect(_on_get_ok)
	SaiServer.progress.get_failed.connect(_on_get_err)
	SaiServer.progress.delete_success.connect(_on_delete_ok)
	SaiServer.progress.delete_failed.connect(_on_delete_err)


func _refresh_welcome() -> void:
	var username := "(unknown)"
	if SaiServer != null and SaiServer.auth != null:
		var user := SaiServer.auth.get_current_user()
		if user is Dictionary and user.has("username"):
			username = String(user.get("username", "(unknown)"))
	welcome_label.text = "Logged in as %s" % username


# ── Save = create new progress record (idempotent enough for a demo) ──────

func _on_save_button_pressed() -> void:
	status_label.text = "Saving..."
	# In a real game you'd `update()` an existing record if one exists. This demo
	# just creates a fresh one so the button works on first run.
	await SaiServer.progress.create({
		"experience": 0,
		"gold": 100,
		"game_data": {"tutorial_done": false},
	})


# ── Load = fetch the player's existing progress ──────────────────────────

func _on_load_button_pressed() -> void:
	status_label.text = "Loading..."
	await SaiServer.progress.get_mine()


# ── Reset = wipe server-side progress ────────────────────────────────────

func _on_reset_button_pressed() -> void:
	status_label.text = "Resetting..."
	await SaiServer.progress.delete_mine()


# ── Signal handlers ──────────────────────────────────────────────────────

func _on_create_ok(_data: Dictionary) -> void:
	var p := SaiServer.progress.current_progress
	if p != null:
		status_label.text = "Saved. Lvl %d, XP %d, Gold %d" % [p.level, p.experience, p.gold]
	else:
		status_label.text = "Saved."


func _on_create_err(error: String) -> void:
	status_label.text = "Save failed: %s" % error


func _on_get_ok(_data: Dictionary) -> void:
	var p := SaiServer.progress.current_progress
	if p != null:
		status_label.text = "Loaded. Lvl %d, XP %d, Gold %d" % [p.level, p.experience, p.gold]
	else:
		status_label.text = "Loaded (empty)."


func _on_get_err(error: String) -> void:
	status_label.text = "Load failed: %s" % error


func _on_delete_ok() -> void:
	status_label.text = "Progress reset."


func _on_delete_err(error: String) -> void:
	status_label.text = "Reset failed: %s" % error
