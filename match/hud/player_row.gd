class_name PlayerRow extends VBoxContainer
## One player in the PlayerList: play-order number, pawn, name, what's
## known of their character, damage, equipment; an arrow opens a drawer with
## the details. Pure view: rebuilt from GameState by refresh().
## While picking (attack, card targets…) the row can be clickable.

signal picked(player_id: int)
signal drawer_opened(player_id: int)

const C_BG := Color(0.05, 0.06, 0.09, 0.86)
const C_CURRENT := Color("e8c060")
const C_PICK := Color("ff7a5a")
const DRAWER_WIDTH := 330.0

var player_id := 0
var order_number := 0

var _card: PanelContainer
var _style: StyleBoxFlat
var _number: Label
var _pawn: TextureRect
var _name: Label
var _info: Label
var _arrow: Button
var _drawer: PanelContainer
var _drawer_text: RichTextLabel
var _pickable := false
var _picking := false   # some pick is going on (others dim)
var _pulse: Tween


func _init(id: int, number: int) -> void:
	player_id = id
	order_number = number
	add_theme_constant_override("separation", 2)

	_card = PanelContainer.new()
	_style = StyleBoxFlat.new()
	_style.bg_color = C_BG
	_style.set_corner_radius_all(8)
	_style.set_border_width_all(2)
	_style.border_color = Color(1, 1, 1, 0.08)
	_style.content_margin_left = 6
	_style.content_margin_right = 4
	_style.content_margin_top = 4
	_style.content_margin_bottom = 4
	_card.add_theme_stylebox_override("panel", _style)
	_card.gui_input.connect(_on_card_input)
	add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)

	_number = Label.new()
	_number.text = str(number)
	_number.custom_minimum_size = Vector2(18, 0)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.add_theme_font_size_override("font_size", 15)
	_number.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	row.add_child(_number)

	_pawn = TextureRect.new()
	_pawn.custom_minimum_size = Vector2(36, 36)
	_pawn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pawn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pawn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_pawn)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 17)
	_name.clip_text = true
	texts.add_child(_name)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_color", Color(0.78, 0.78, 0.84))
	_info.clip_text = true
	texts.add_child(_info)

	_arrow = Button.new()
	_arrow.text = "▸"
	_arrow.flat = true
	_arrow.tooltip_text = Global.text("players.details")
	_arrow.custom_minimum_size = Vector2(28, 0)
	_arrow.add_theme_font_size_override("font_size", 18)
	_arrow.pressed.connect(toggle_drawer)
	row.add_child(_arrow)

	_drawer = PanelContainer.new()
	var drawer_style := StyleBoxFlat.new()
	drawer_style.bg_color = Color(0.03, 0.035, 0.05, 0.92)
	drawer_style.set_corner_radius_all(6)
	drawer_style.set_content_margin_all(8)
	drawer_style.border_color = Color(1, 1, 1, 0.15)
	drawer_style.set_border_width_all(1)
	_drawer.add_theme_stylebox_override("panel", drawer_style)
	_drawer.hide()
	# The drawer floats to the LEFT of the row (outside the list's layout), so
	# opening it doesn't push the list down over the game log.
	_drawer.top_level = true
	_drawer.z_index = 30
	_drawer.custom_minimum_size = Vector2(DRAWER_WIDTH, 0)
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_drawer)
	_drawer_text = RichTextLabel.new()
	_drawer_text.bbcode_enabled = true
	_drawer_text.fit_content = true
	_drawer_text.custom_minimum_size = Vector2(DRAWER_WIDTH - 16, 0)
	_drawer_text.scroll_active = false
	_drawer_text.add_theme_font_size_override("normal_font_size", 15)
	_drawer_text.add_theme_constant_override("line_separation", 2)
	_drawer_text.add_theme_font_size_override("bold_font_size", 15)
	_drawer.add_child(_drawer_text)


func toggle_drawer() -> void:
	_drawer.visible = not _drawer.visible
	_arrow.text = "◂" if _drawer.visible else "▸"
	refresh()
	_place_drawer()
	if _drawer.visible:
		drawer_opened.emit(player_id)  # the list closes any other open drawer


func close_drawer() -> void:
	if _drawer.visible:
		toggle_drawer()


## Keep the open drawer beside its row (rows move when the list scrolls),
## and on screen.
func _process(_delta: float) -> void:
	if _drawer.visible:
		_place_drawer()


func _place_drawer() -> void:
	if not _drawer.visible or not is_inside_tree():
		return
	_drawer.reset_size()
	var at := _card.global_position + Vector2(-DRAWER_WIDTH - 8, 0)
	var screen := get_viewport_rect().size
	at.y = clampf(at.y, 4, maxf(4, screen.y - _drawer.size.y - 4))
	_drawer.global_position = at


## Redraw from GameState.
func refresh() -> void:
	var p: Dictionary = GameState.players.get(player_id, {})
	if p.is_empty():
		return
	var me := player_id == GameState.local_id
	var pawn_info: Dictionary = Global.pawns.get(p.pawn, {})
	_pawn.texture = pawn_info.get("sprite")
	_name.text = p.name + (Global.text("players.you") if me else "") \
		+ (Global.text("players.bot") if LobbyNet.is_bot(p) else "")
	_name.add_theme_color_override("font_color", Color(pawn_info.get("hex", "ffffff")).lightened(0.25))

	var character: Dictionary = p.get("character", {})
	var known: bool = not character.is_empty() and (me or not p.hidden)
	var parts := []
	if p.dead:
		parts.append(Global.text("players.out"))
	parts.append("%s %s" % [Global.species_name(character.get("species", "")), Global.field(character, "name")] if known else "?????")
	var health := " / %d" % character.health if known and character.has("health") else ""
	parts.append(Global.text("players.dmg") % [p.dmg, health])
	if not p.equipment.is_empty():
		parts.append(Global.text("players.eq") % p.equipment.size())
	if p.get("protected", false):
		parts.append(Global.text("players.shield"))
	_info.text = "  ·  ".join(parts)

	var current: bool = p.get("playing", false)
	_style.border_color = C_CURRENT if current else Color(1, 1, 1, 0.08)
	_style.bg_color = C_BG.lightened(0.12) if current else C_BG
	_number.add_theme_color_override("font_color", C_CURRENT if current else Color(0.7, 0.7, 0.75))
	if _pickable:
		_style.border_color = C_PICK
	modulate = Color(0.55, 0.55, 0.6) if p.dead or (_picking and not _pickable) else Color.WHITE

	if _drawer.visible:
		_drawer_text.text = _details(p, known, character)


## The drawer: name, character, a damage bar, goal / ability, where they
## are, equipment — each under its own small heading.
func _details(p: Dictionary, known: bool, character: Dictionary) -> String:
	var lines := []
	var pawn_hex: String = Global.pawns.get(p.pawn, {}).get("hex", "ffffff")
	lines.append("[font_size=19][b][color=#%s]%s[/color][/b][/font_size]%s" % [
		Color(pawn_hex).lightened(0.25).to_html(false), _safe(p.name),
		"  [color=#9aa]%s[/color]" % Global.text("players.out") if p.dead else ""])
	if known:
		var species: String = character.get("species", "")
		lines.append("[font_size=16][color=#%s]%s[/color] · [b]%s[/b][/font_size]" % [
			DamageBoard.SPECIES_COLOURS.get(species, "ffffff"),
			Global.species_name(species).capitalize(), Global.field(character, "name")])
	else:
		lines.append("[font_size=16][i][color=#9aa]%s[/color][/i][/font_size]" % Global.text("players.hidden_character"))

	# Damage: a bar when their health is known, else just the number.
	var health: int = character.get("health", 0) if known else 0
	if health > 0:
		var taken := mini(p.dmg, health)
		lines.append("%s  [color=#e06a6a]%s[/color][color=#555a66]%s[/color]" % [
			Global.text("players.damage_of") % [p.dmg, health], "■".repeat(taken), "■".repeat(health - taken)])
	else:
		lines.append(Global.text("players.damage") % p.dmg)

	if known and character.has("goal"):
		lines.append(_heading(Global.text("players.goal")))
		lines.append(Global.field(character, "goal"))
	if known and character.has("ability"):
		var used := "  [color=#9aa](%s)[/color]" % Global.text("players.ability_used") \
			if p.get("ability_used", false) else ""
		lines.append(_heading(Global.text("players.ability")) + used)
		lines.append(Global.field(character, "ability"))

	var loc := GameState.location_index(p.location)
	lines.append(_heading(Global.text("players.where")))
	lines.append(Global.field(GameState.locations[loc], "label") if loc != -1 else Global.text("players.campfire"))

	lines.append(_heading("%s (%d)" % [Global.text("players.equipment"), p.equipment.size()]))
	for card in p.equipment:
		var color: String = Global.CARD_COLORS.get(card.get("deck", ""), {}).get("color", "ffffff")
		lines.append("[color=#%s]▌[/color][b]%s[/b]" % [Color(color).lightened(0.2).to_html(false), Global.field(card, "name")])
		lines.append("[indent][color=#b8bcc8]%s[/color][/indent]" % Global.field(card, "text"))
	return "\n".join(lines)


## A small gold heading with a little space above it.
func _heading(text: String) -> String:
	return "[font_size=6] [/font_size]\n[font_size=14][b][color=#e8c060]%s[/color][/b][/font_size]" % text.trim_suffix(":")


static func _safe(text: String) -> String:
	return text.replace("[", "[lb]")


## Picking mode: `on` = this row can be clicked; `picking` = a pick is
## going on (rows that can't be picked dim).
func set_pick_state(on: bool, picking: bool) -> void:
	_pickable = on
	_picking = picking
	_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	if _pulse:
		_pulse.kill()
		_pulse = null
	_card.modulate = Color.WHITE
	if on:
		_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_card, "modulate", Color(1.35, 1.2, 1.1), 0.45)
		_pulse.tween_property(_card, "modulate", Color.WHITE, 0.45)
	refresh()


func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _pickable:
			picked.emit(player_id)
		else:
			toggle_drawer()
