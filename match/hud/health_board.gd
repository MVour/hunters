class_name DamageBoard extends HBoxContainer
## The life track: one row per damage level (0 at the bottom). Each row lists
## the initials of the characters who die at that much damage, and every
## player's marker (their pawn, in their colour) sits on their damage row.
## Damage is public; who has how much health is the deduction game.
## Collapsible with the side button.

const ROW_HEIGHT := 25
const MARKER := 20

@onready var damage_entries: VBoxContainer = $DamageEntries
@onready var collapse_button: Button = $CollapseButton

var _rows := {}       # damage level -> HBoxContainer holding markers
var _markers := {}    # player id -> TextureRect
var _right := false   # docked to the right edge (arrow on the inner side)
var _top_right := Vector2.ZERO


func _ready() -> void:
	SignalBus.damage_changed.connect(_on_damage_changed)
	SignalBus.player_died.connect(_on_player_died)
	collapse_button.text = "<"
	collapse_button.add_theme_font_size_override("font_size", 22)
	damage_entries.add_theme_constant_override("separation", 1)
	_build()


func _max_level() -> int:
	var top := 0
	for list in Global.deck.characters.values():
		for character in list:
			top = maxi(top, character.health)
	return top


## Initials of every character who dies at exactly this much damage.
func _initials_at(level: int) -> String:
	var names := []
	for list in Global.deck.characters.values():
		for character in list:
			if character.health == level:
				names.append(character.name.left(1))
	return " ".join(names)


func _build() -> void:
	for child in damage_entries.get_children():
		child.queue_free()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.04, 0.06, 0.78)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 6
	bg.content_margin_right = 6

	for level in range(_max_level(), -1, -1):
		var row_panel := PanelContainer.new()
		var style: StyleBoxFlat = bg.duplicate()
		var initials := _initials_at(level)
		if initials != "":
			style.border_color = Color("8a2a2a")  # someone dies here
			style.border_width_left = 3
		row_panel.add_theme_stylebox_override("panel", style)
		row_panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		damage_entries.add_child(row_panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row_panel.add_child(row)

		var number := Label.new()
		number.text = str(level)
		number.custom_minimum_size = Vector2(24, 0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.add_theme_font_size_override("font_size", 16)
		row.add_child(number)

		var markers := HBoxContainer.new()
		markers.custom_minimum_size = Vector2(MARKER * 4 + 6, 0)
		markers.add_theme_constant_override("separation", -6)  # overlap when crowded
		row.add_child(markers)
		_rows[level] = markers

		var names := Label.new()
		names.text = initials
		names.custom_minimum_size = Vector2(40, 0)
		names.add_theme_font_size_override("font_size", 14)
		names.add_theme_color_override("font_color", Color("e06a6a"))
		row.add_child(names)


func _marker_for(player_id: int) -> TextureRect:
	if _markers.has(player_id):
		return _markers[player_id]
	var player: Dictionary = GameState.players.get(player_id, {})
	var marker := TextureRect.new()
	marker.custom_minimum_size = Vector2(MARKER, MARKER)
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if Global.pawns.has(player.get("pawn", "")):
		marker.texture = Global.pawns[player.pawn].sprite
	marker.tooltip_text = player.get("name", "?")
	_markers[player_id] = marker
	return marker


## Put every player's marker on their current damage row.
func show_players(players: Dictionary) -> void:
	for id in players:
		_place(id, players[id].dmg)


func _place(player_id: int, damage: int) -> void:
	var marker := _marker_for(player_id)
	var row: HBoxContainer = _rows.get(clampi(damage, 0, _max_level()))
	if marker.get_parent():
		marker.get_parent().remove_child(marker)
	row.add_child(marker)
	# A little pop so the change is noticed.
	marker.pivot_offset = Vector2(MARKER, MARKER) / 2.0
	marker.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(marker, "scale", Vector2.ONE, 0.25)


func _on_damage_changed(player_id: int, damage: int) -> void:
	_place(player_id, damage)


func _on_player_died(player_id: int, _killer_id: int) -> void:
	if _markers.has(player_id):
		_markers[player_id].modulate = Color(0.45, 0.45, 0.45, 0.8)


func _on_button_pressed() -> void:
	damage_entries.visible = not damage_entries.visible
	_update_arrow()
	reset_size()


## Stick to the right edge: `top_right` is where the top-right corner goes.
func dock_right(top_right: Vector2) -> void:
	_right = true
	_top_right = top_right
	move_child(collapse_button, 0)
	_update_arrow()
	resized.connect(_redock)
	_redock.call_deferred()


func _redock() -> void:
	position = Vector2(_top_right.x - size.x, _top_right.y)


func _update_arrow() -> void:
	var open := damage_entries.visible
	if _right:
		collapse_button.text = ">" if open else "<"
	else:
		collapse_button.text = "<" if open else ">"
