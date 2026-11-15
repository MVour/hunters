class_name MultiplayerController extends Control
## Host / Join menu. How players actually connect is the Network autoload's
## job, so this screen works the same with direct ENet or a lobby service.

@onready var multiplayer_menu_container: VBoxContainer = $MultiplayerMenuContainer
@onready var line_edit: LineEdit = $ConnectToLobby/Panel/LineEdit
@onready var connect_to_lobby: Node2D = $ConnectToLobby
@onready var return_button: Button = $ConnectToLobby/Panel/ReturnButton
@onready var lobby_scene : PackedScene = preload("res://scenes/lobby.tscn")

var lobby : Lobby


func _ready():
	return_button.pressed.connect(_on_return_button_pressed)
	SignalBus._return_to_multiplayer_menu.connect(_on_return_button_pressed)
	Network.connected_to_host.connect(_on_connected_to_host)
	Network.connection_failed.connect(_on_connection_failed)
	Network.host_disconnected.connect(_on_host_disconnected)


func _on_back_pressed() -> void:
	SignalBus._return_to_main_menu.emit()


func _on_join_pressed() -> void:
	_close_lobby()
	multiplayer_menu_container.hide()
	connect_to_lobby.show()


func _on_host_pressed() -> void:
	if Network.host() != OK:
		push_warning(Network.get_last_error())
		return
	GameState.reset_session(multiplayer.get_unique_id())
	multiplayer_menu_container.hide()
	connect_to_lobby.hide()
	_open_lobby(Network.get_invite_code())
	if Network.server_is_player:
		lobby.request_join.rpc_id(1)


func _on_connect_lobby_button_pressed() -> void:
	var code := line_edit.text.strip_edges()
	if Network.join(code) != OK:
		push_warning(Network.get_last_error())
		return
	GameState.reset_session(multiplayer.get_unique_id())
	connect_to_lobby.hide()
	_open_lobby(code if code != "" else "this computer")


func _on_visibility_changed() -> void:
	if visible:
		multiplayer_menu_container.show()
		connect_to_lobby.hide()


func _on_return_button_pressed() -> void:
	Network.leave()
	_close_lobby()
	multiplayer_menu_container.show()
	connect_to_lobby.hide()


func _on_connected_to_host() -> void:
	print("Connected to host!")
	if lobby:
		lobby.request_join.rpc_id(1)


func _on_connection_failed(reason: String) -> void:
	push_warning(reason)
	_close_lobby()
	connect_to_lobby.show()


func _on_host_disconnected() -> void:
	push_warning("The host left the game.")
	_close_lobby()
	multiplayer_menu_container.show()
	connect_to_lobby.hide()


func _open_lobby(code: String) -> void:
	_close_lobby()
	lobby = lobby_scene.instantiate()
	add_child(lobby)
	lobby.lobby_init(code)
	lobby.show()


func _close_lobby() -> void:
	if lobby:
		# Remove right away so a new lobby gets the same node name (and path):
		# RPCs find nodes by path, so it must match on every computer.
		remove_child(lobby)
		lobby.queue_free()
		lobby = null
