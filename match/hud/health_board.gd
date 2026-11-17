class_name DamageBoard extends HBoxContainer
## The life track: one row per damage level (0 at the bottom). Each row lists
## the initials of the characters who die at that much damage, and every
## player's marker (their pawn, in their colour) sits on their damage row.
## Damage is public; who has how much health is the deduction game.
## Collapsible with the side button. "Who's who" opens a key beside it: how
## many of each side are in this game, every character's health, and which
## player turned out to be whom.

const ROW_HEIGHT := 25
const MARKER := 20
const SPECIES_COLOURS := {"vampire": "e06a6a", "werewolf": "e0a84c", "human": "8fb8e0"}
const KEY_WIDTH := 300.0

@onready var damage_entries: VBoxContainer = $DamageEntries
@onready var collapse_button: Button = $CollapseButton

var _rows := {}       # damage level -> HBoxContainer holding markers
var _markers := {}    # player id -> TextureRect
var _right := false   # docked to the right edge (arrow on the inner side)
var _top_right := Vector2.ZERO
var _key_button: Button
var _key: PanelContainer
var _key_text: RichTextLabel


func _ready() -> void:
	SignalBus.damage_changed.connect(_on_damage_changed)
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.player_died.connect(_refresh_key.unbind(2))
	SignalBus.character_revealed.connect(_refresh_key.unbind(2))
	Global.language_changed.connect(func(_l = null):
		_build()
		show_players(GameState.players)
		_refresh_key())
	_make_key()
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


## Every character who dies at exactly this much damage.
func _characters_at(level: int) -> Array:
	var found := []
	for list in Global.deck.characters.values():
		for character in list:
			if character.health == level:
				found.append(character)
	return found


func _build() -> void:
	for child in damage_entries.get_children():
		if child != _key_button:
			damage_entries.remove_child(child)
			child.queue_free()
	_markers_out()
	_key_button.text = Global.text("track.key")
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.04, 0.06, 0.78)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 6
	bg.content_margin_right = 6

	for level in range(_max_level(), -1, -1):
		var row_panel := PanelContainer.new()
		var style: StyleBoxFlat = bg.duplicate()
		var dying := _characters_at(level)
		if not dying.is_empty():
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

		# Their initials, in their side's colour; hover for the names.
		var names := RichTextLabel.new()
		names.bbcode_enabled = true
		names.fit_content = true
		names.scroll_active = false
		names.autowrap_mode = TextServer.AUTOWRAP_OFF
		names.custom_minimum_size = Vector2(40, 0)
		names.add_theme_font_size_override("normal_font_size", 14)
		var initials := []
		var full := []
		for character in dying:
			initials.append("[color=#%s]%s[/color]" % [SPECIES_COLOURS.get(character.species, "e06a6a"),
				Global.field(character, "name").left(1)])
			full.append("%s (%s)" % [Global.field(character, "name"), Global.species_name(character.species)])
		names.text = " ".join(initials)
		names.tooltip_text = ", ".join(full)
		row.add_child(names)
	# The rows were rebuilt: markers go back on them.
	damage_entries.move_child(_key_button, 0)


## The markers' rows are being rebuilt: take them off first (they're kept).
func _markers_out() -> void:
	for marker in _markers.values():
		if marker.get_parent():
			marker.get_parent().remove_child(marker)


# --- The key ("Who's who") -------------------------------------------------------

func _make_key() -> void:
	_key_button = Button.new()
	_key_button.flat = true
	_key_button.add_theme_font_size_override("font_size", 14)
	_key_button.add_theme_color_override("font_color", Color("e8c060"))
	_key_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_key_button.pressed.connect(func():
		_key.visible = not _key.visible
		_refresh_key())
	damage_entries.add_child(_key_button)

	_key = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.035, 0.05, 0.94)
	style.border_color = Color(1, 1, 1, 0.15)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	_key.add_theme_stylebox_override("panel", style)
	_key.top_level = true  # floats beside the track, outside its layout
	_key.z_index = 30
	_key.hide()
	add_child(_key)
	_key_text = RichTextLabel.new()
	_key_text.bbcode_enabled = true
	_key_text.fit_content = true
	_key_text.scroll_active = false
	_key_text.custom_minimum_size = Vector2(KEY_WIDTH, 0)
	_key_text.add_theme_font_size_override("normal_font_size", 14)
	_key_text.add_theme_font_size_override("bold_font_size", 15)
	_key.add_child(_key_text)


func _refresh_key() -> void:
	if not _key.visible:
		return
	# Who is known to be whom (revealed, dead, or you).
	var known := {}
	for p in GameState.players.values():
		var character: Dictionary = p.get("character", {})
		if not character.is_empty() and (not p.hidden or p.id == GameState.local_id):
			known[character.get("id", "")] = p.name
	var lines := []
	var counts := []
	for key in Global.SPECIES:
		var n: int = GameState.game_settings.get(key, 0)
		if n > 0:
			var species: String = Global.SPECIES[key].species
			counts.append("[color=#%s]%s[/color] %d" % [SPECIES_COLOURS[species], Global.species_name(species), n])
	lines.append("[b]%s[/b]  %s" % [Global.text("track.in_play"), " · ".join(counts)])
	for key in Global.SPECIES:
		if GameState.game_settings.get(key, 0) <= 0:
			continue
		var species: String = Global.SPECIES[key].species
		var colour: String = SPECIES_COLOURS[species]
		lines.append("")
		lines.append("[b][color=#%s]%s[/color][/b]" % [colour, Global.species_name(species).capitalize()])
		for character in Global.deck.characters[Global.SPECIES[key].list]:
			var line := "[color=#%s]%s[/color]  %s · %s" % [colour, Global.field(character, "name").left(1),
				Global.field(character, "name"), Global.text("track.health") % character.health]
			if known.has(character.get("id", "")):
				line += "  → [b]%s[/b]" % known[character.id].replace("[", "[lb]")
			lines.append(line)
	_key_text.text = "\n".join(lines)
	_key.reset_size()
	var screen := get_viewport_rect().size
	var at := global_position + Vector2(size.x + 6, 0)
	at.y = clampf(at.y, 4, maxf(4, screen.y - _key.size.y - 4))
	_key.global_position = at


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
	_key.hide()
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


## A player's marker on the track (for hit / heal effects), or null.
func marker_of(player_id: int) -> Control:
	return _markers.get(player_id)
