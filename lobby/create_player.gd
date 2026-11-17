class_name CreatePlayer extends PanelContainer
## Pick a name and a pawn colour. The choice is only a request: the server
## confirms it (or rejects it if someone grabbed that pawn first).

var btn_scene : PackedScene = preload("res://lobby/select_player_icon_button.tscn")

var name_line: LineEdit
var avatar_container: GridContainer
var lock_button: Button
var _name_label: Label
var _pick_label: Label

## Currently selected pawn colour, "" for none.
var color := ""
var buttons := {}


func _init() -> void:
	add_theme_stylebox_override("panel", LobbyStyle.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 14)
	column.add_child(name_row)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	name_row.add_child(_name_label)
	name_line = LineEdit.new()
	name_line.placeholder_text = "...."
	name_line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_line.max_length = 16
	name_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_line.custom_minimum_size = Vector2(0, 44)
	name_line.add_theme_font_size_override("font_size", 22)
	name_row.add_child(name_line)

	_pick_label = Label.new()
	_pick_label.add_theme_font_size_override("font_size", 22)
	column.add_child(_pick_label)

	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 16)
	column.add_child(pick_row)
	avatar_container = GridContainer.new()
	avatar_container.columns = 8
	avatar_container.add_theme_constant_override("h_separation", 8)
	avatar_container.add_theme_constant_override("v_separation", 8)
	avatar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_row.add_child(avatar_container)
	lock_button = LobbyStyle.big_button(64, true)
	lock_button.custom_minimum_size.x = 170
	lock_button.add_theme_font_size_override("font_size", 22)
	lock_button.pressed.connect(_on_lock_button_pressed)
	pick_row.add_child(lock_button)


func _ready():
	SignalBus._new_game.connect(reset_buttons)
	SignalBus.pawns_changed.connect(refresh_buttons)
	SignalBus.avatar_rejected.connect(on_avatar_rejected)
	Global.language_changed.connect(func(_l = null): _apply_texts())
	_apply_texts()
	reset_buttons()


func _apply_texts() -> void:
	_name_label.text = Global.text("Name:")
	_pick_label.text = Global.text("Select Player:")
	lock_button.text = Global.text("Lock")


func reset_buttons():
	for button in buttons.values():
		button.queue_free()
	buttons = {}
	color = ""
	for pawn in Global.pawns:
		var new_btn = btn_scene.instantiate()
		new_btn.color = pawn
		new_btn.custom_minimum_size = Vector2(64, 64)
		new_btn.expand_icon = true
		# Selected: a gold frame. Taken by someone else: faded.
		for state in ["pressed", "hover_pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.16, 0.06)
			style.border_color = LobbyStyle.GOLD
			style.set_border_width_all(3)
			style.set_corner_radius_all(6)
			new_btn.add_theme_stylebox_override(state, style)
		new_btn.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.2))
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
