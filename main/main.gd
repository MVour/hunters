extends Node2D

@onready var multiplayer_controller: MultiplayerController = $CanvasLayer/MultiplayerController

@onready var canvas_layer: CanvasLayer = $CanvasLayer

@onready var main_menu: MainMenu = $CanvasLayer/MainMenu


@onready var play_scene_pack : PackedScene = preload("res://match/play_scene.tscn")
var play_scene

## Opened from the lobby web page: leaving the game goes back there.
var _from_lobby_page := false


func _ready()->void :
	# Dedicated server for an online room: no screens at all (D007).
	if RoomServer.wanted():
		canvas_layer.hide()
		add_child(RoomServer.new())
		return
	SignalBus.connect("_exit_game", _on_exit_game)
	SignalBus.connect("_new_game", _on_new_game)
	SignalBus.connect("_return_to_main_menu", _on_main_menu)
	SignalBus.connect("_start_game", _on_start_game)
	Network.host_disconnected.connect(_on_host_disconnected)
	SignalBus.leave_match.connect(_on_leave_match)
	set_main_screen()
	_add_overlay()
	_maybe_start_autotest()
	_maybe_join_from_page()


## Browser build started from the lobby page: straight into that room.
func _maybe_join_from_page() -> void:
	var link := OnlineLaunch.link_from_page()
	if link == "":
		return
	_from_lobby_page = true
	for sig in [Network.session_closed, Network.host_disconnected]:
		sig.connect(OnlineLaunch.back_to_lobby)
	Network.connection_failed.connect(func(_reason): OnlineLaunch.back_to_lobby())
	SignalBus._new_game.emit()
	multiplayer_controller.line_edit.text = link
	multiplayer_controller._on_connect_lobby_button_pressed()


## Always on top, on every screen: the language button (bottom-left) and,
## above it, the chat (only while in a session).
func _add_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "Overlay"
	overlay.layer = 5
	add_child(overlay)

	var chat := ChatBox.new()
	chat.name = "ChatBox"
	chat.position = Vector2(8, 1080 - 8 - 40 - 8 - ChatBox.BOX.y)
	chat.hide()
	overlay.add_child(chat)

	var lang_button := Button.new()
	lang_button.name = "LanguageButton"
	lang_button.position = Vector2(8, 1080 - 8 - 40)
	lang_button.custom_minimum_size = Vector2(130, 40)
	lang_button.add_theme_font_size_override("font_size", 17)
	var update := func():
		# Shows the language you'd switch TO.
		lang_button.text = "Ελληνικά" if Global.lang == "en" else "English"
		lang_button.tooltip_text = Global.text("main.switch_language")
	update.call()
	Global.language_changed.connect(update)
	lang_button.pressed.connect(func(): Global.lang = "el" if Global.lang == "en" else "en")
	overlay.add_child(lang_button)


## Dev only: `-- --autotest=host|client` lets a bot play (tools/autotest.gd).
func _maybe_start_autotest() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			var script: GDScript = load("res://tools/autotest.gd")
			if script == null or not script.can_instantiate():
				print("AUTOTEST FAIL could not load tools/autotest.gd")
				get_tree().quit(1)
				return
			add_child(script.new(arg.get_slice("=", 1)))


func set_main_screen():
	main_menu.show()
	multiplayer_controller.hide()
	
func _on_main_menu():
	set_main_screen()

func _on_new_game():
	main_menu.hide()
	multiplayer_controller.show()
	
	
func _on_start_game(id):
	if not Network.server_is_player:
		return  # a dedicated server has no match screen
	play_scene = play_scene_pack.instantiate()
	
	canvas_layer.add_child(play_scene)
	main_menu.hide()
	multiplayer_controller.hide()
	#create_player.show()

## "Back to menu" after a game: leave the session and return to the menu.
func _on_leave_match():
	Network.leave()
	GameState.reset_session()
	_on_host_disconnected()


func _on_host_disconnected():
	if play_scene:
		canvas_layer.remove_child(play_scene)
		play_scene.queue_free()
		play_scene = null
		set_main_screen()


func _on_exit_game():
	_quit()

func _input(event):
	if event.is_action_pressed("esc"):
		_quit()


## In a browser, quitting would leave a dead page: go back to the lobby page.
func _quit() -> void:
	if OS.has_feature("web"):
		Network.leave()
		OnlineLaunch.back_to_lobby()
	else:
		get_tree().quit()

