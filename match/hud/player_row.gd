class_name PlayerRow extends VBoxContainer
## One player in the PlayerList: an arrow, pawn, name, what's known of
## their character, damage, equipment, and their play-order number on the
## right. A click (or the arrow) asks for their character card (PlayScene
## shows it: known or not, with their equipment). Pure view: rebuilt from
## GameState by refresh(). While picking (attack, card targets…) a click
## picks the player instead.

signal picked(player_id: int)
## Show this player's character card.
signal card_wanted(player_id: int)

const C_BG := Color(0.05, 0.06, 0.09, 0.86)
const C_CURRENT := Color("e8c060")
const C_PICK := Color("ff7a5a")
const C_REACH := Color("e8402e")

var player_id := 0
var order_number := 0

var _card: PanelContainer
var _style: StyleBoxFlat
var _number: Label
var _pawn: TextureRect
var _name: Label
var _info: Label
var _arrow: Button
var _pickable := false
var _picking := false   # some pick is going on (others dim)
var _in_reach := false  # you could attack them now (your attack step)
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

	_arrow = Button.new()
	_arrow.text = "◂"
	_arrow.flat = true
	_arrow.focus_mode = Control.FOCUS_NONE
	_arrow.tooltip_text = Global.text("players.details")
	_arrow.custom_minimum_size = Vector2(22, 0)
	_arrow.add_theme_font_size_override("font_size", 18)
	_arrow.pressed.connect(func(): card_wanted.emit(player_id))
	row.add_child(_arrow)

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

	_number = Label.new()
	_number.text = str(number)
	_number.custom_minimum_size = Vector2(22, 0)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.add_theme_font_size_override("font_size", 15)
	_number.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	row.add_child(_number)


## Redraw from GameState.
func refresh() -> void:
	var p: Dictionary = GameState.players.get(player_id, {})
	if p.is_empty():
		return
	var me := player_id == GameState.local_id
	var pawn_info: Dictionary = Global.pawns.get(p.pawn, {})
	_pawn.texture = Global.player_sprite(p)  # pawn, revealed figure or gravestone, as on the board
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
	if _in_reach:
		_style.border_color = C_REACH
		_style.bg_color = C_BG.lerp(Color(0.35, 0.03, 0.03, 0.9), 0.45)
	if _pickable:
		_style.border_color = C_PICK
	modulate = Color(0.55, 0.55, 0.6) if p.dead or (_picking and not _pickable) else Color.WHITE


## You could attack this player now: a red edge.
func set_in_reach(on: bool) -> void:
	if on != _in_reach:
		_in_reach = on
		refresh()


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
			card_wanted.emit(player_id)
