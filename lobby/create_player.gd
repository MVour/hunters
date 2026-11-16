class_name CreatePlayer extends Node2D
## Pick a name and a pawn colour. The choice is only a request: the server
## confirms it (or rejects it if someone grabbed that pawn first).

@onready var name_line: LineEdit = $Panel/NameLine
@onready var panel: Panel = $Panel
@onready var avatar_container: GridContainer = $Panel/AvatarContainer

var btn_scene : PackedScene = preload("res://lobby/select_player_icon_button.tscn")

## Currently selected pawn colour, "" for none.
var color := ""
var buttons := {}


func _ready():
	SignalBus._new_game.connect(reset_buttons)
	SignalBus.pawns_changed.connect(refresh_buttons)
	SignalBus.avatar_rejected.connect(on_avatar_rejected)
	reset_buttons()


func reset_buttons():
	for button in buttons.values():
		button.queue_free()
	buttons = {}
	color = ""
	for pawn in Global.pawns:
		var new_btn = btn_scene.instantiate()
		new_btn.color = pawn
		new_btn.toggled.connect(_on_btn_toggled.bind(pawn))
		new_btn.use_texture()
		avatar_container.add_child(new_btn)
		buttons[pawn] = new_btn
	refresh_buttons()


## Grey out pawns other players own.
func refresh_buttons():
	for pawn in buttons:
		buttons[pawn].disabled = GameState.is_pawn_taken(pawn, GameState.local_id)


func _on_btn_toggled(toggled_on: bool, pawn: String):
	if toggled_on:
		if color != "" and color != pawn:
			buttons[color].set_pressed_no_signal(false)
		color = pawn
	elif color == pawn:
		color = ""


func on_avatar_rejected(pawn: String):
	if color == pawn:
		buttons[pawn].set_pressed_no_signal(false)
		color = ""
	refresh_buttons()


func _on_lock_button_pressed() -> void:
	if color == "":
		return
	SignalBus._avatar_created.emit(name_line.text, color)
