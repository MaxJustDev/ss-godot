# Example — Login / register / logout

Minimal scene wiring `SaiServer.auth` signals.

## Scene structure

```
LoginScene (Control)
├ UsernameField (LineEdit)
├ PasswordField (LineEdit, secret = true)
├ LoginButton (Button)
├ RegisterButton (Button)
└ StatusLabel (Label)
```

## Script

```gdscript
extends Control

@onready var username_field: LineEdit = $UsernameField
@onready var password_field: LineEdit = $PasswordField
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
    SaiServer.auth.login_success.connect(_on_login_ok)
    SaiServer.auth.login_failed.connect(_on_login_err)
    SaiServer.auth.register_success.connect(_on_register_ok)
    SaiServer.auth.register_failed.connect(_on_register_err)


func _on_login_button_pressed() -> void:
    status_label.text = "Logging in..."
    SaiServer.auth.login(username_field.text, password_field.text)


func _on_register_button_pressed() -> void:
    status_label.text = "Registering..."
    # SaiServer.auth.register(email, username, password)
    var email := "%s@example.com" % username_field.text
    SaiServer.auth.register(email, username_field.text, password_field.text)


func _on_login_ok(user: Dictionary) -> void:
    status_label.text = "Welcome %s" % user.username
    get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_login_err(error: String) -> void:
    status_label.text = "Login failed: %s" % error


func _on_register_ok(user: Dictionary) -> void:
    status_label.text = "Account created. Please log in."


func _on_register_err(error: String) -> void:
    status_label.text = "Registration failed: %s" % error
```

## Logout

```gdscript
func _on_logout_pressed() -> void:
    await SaiServer.auth.logout()
    SaiServer.clear_tokens()
    get_tree().change_scene_to_file("res://scenes/login.tscn")
```

## Token persistence

Tokens are persisted automatically to `user://sai_server.cfg` by `SaiServer`. On app launch, call:

```gdscript
func _ready() -> void:
    if SaiServer.is_authenticated():
        get_tree().change_scene_to_file("res://scenes/lobby.tscn")
```
