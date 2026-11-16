extends Node2D

@onready var multiplayer_controller: MultiplayerController = $CanvasLayer/MultiplayerController

@onready var canvas_layer: CanvasLayer = $CanvasLayer

@onready var main_menu: MainMenu = $CanvasLayer/MainMenu


@onready var play_scene_pack : PackedScene = preload("res://match/play_scene.tscn")
var play_scene

func _ready()->void :
	SignalBus.connect("_exit_game", _on_exit_game)
	SignalBus.connect("_new_game", _on_new_game)
	SignalBus.connect("_return_to_main_menu", _on_main_menu)
	SignalBus.connect("_start_game", _on_start_game)
	Network.host_disconnected.connect(_on_host_disconnected)
	SignalBus.leave_match.connect(_on_leave_match)
	set_main_screen()
	_maybe_start_autotest()


## Dev only: `-- --autotest=host|client` lets a bot play (tools/autotest.gd).
func _maybe_start_autotest() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			var bot: Node = load("res://tools/autotest.gd").new(arg.get_slice("=", 1))
			add_child(bot)


func set_main_screen():
	main_menu.show()
	multiplayer_controller.hide()
	
func _on_main_menu():
	set_main_screen()

func _on_new_game():
	main_menu.hide()
	multiplayer_controller.show()
	
	
func _on_start_game(id):
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
	get_tree().quit()

func _input(event):
	if event.is_action_pressed("esc"):
		get_tree().quit()

