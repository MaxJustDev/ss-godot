## Login / register / logout demo scene controller.
##
## Mirrors `docs/examples/login.md`. Attach to a Control node with these
## children:
##   - UsernameField  (LineEdit)
##   - PasswordField  (LineEdit, secret = true)
##   - LoginButton    (Button)
##   - RegisterButton (Button)
##   - LogoutButton   (Button, optional)
##   - StatusLabel    (Label)
extends Control

@onready var username_field: LineEdit = $UsernameField
@onready var password_field: LineEdit = $PasswordField
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	# If already logged in (token persisted to disk), short-circuit.
	if SaiServer.is_authenticated():
		status_label.text = "Already logged in."
		return

	SaiServer.auth.login_success.connect(_on_login_ok)
	SaiServer.auth.login_failed.connect(_on_login_err)
	SaiServer.auth.register_success.connect(_on_register_ok)
	SaiServer.auth.register_failed.connect(_on_register_err)
	SaiServer.auth.logout_success.connect(_on_logout_ok)


func _on_login_button_pressed() -> void:
	status_label.text = "Logging in..."
	SaiServer.auth.login(username_field.text, password_field.text)


func _on_register_button_pressed() -> void:
	status_label.text = "Registering..."
	# Demo uses username@example.com as the email — replace with a real field
	# in production scenes.
	var email: String = "%s@example.com" % username_field.text
	SaiServer.auth.register(email, username_field.text, password_field.text)


func _on_logout_button_pressed() -> void:
	status_label.text = "Logging out..."
	await SaiServer.auth.logout()


func _on_login_ok(user: Dictionary) -> void:
	status_label.text = "Welcome %s" % user.get("username", "?")


func _on_login_err(error: String) -> void:
	status_label.text = "Login failed: %s" % error


func _on_register_ok(_user: Dictionary) -> void:
	status_label.text = "Account created. Please log in."


func _on_register_err(error: String) -> void:
	status_label.text = "Registration failed: %s" % error


func _on_logout_ok() -> void:
	status_label.text = "Logged out."
