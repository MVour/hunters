class_name PlayerHub extends Control
## The player hub at the bottom of the match screen: three tabs over a dark
## panel with a thin gold edge (the dialogs' look), and a hide button.
## - You: portrait (your species' colour around it), character, goal,
##   ability, a life bar, Use Ability / Reveal;
## - Equipment: your equipment as small cards;
## - This turn: the cheat sheet: the turn's steps (the current one lit,
##   each with how to do it), who you can attack right now, and what you
##   can do any time (ability, reveal, green cards).
## Pure view: PlayScene feeds it (set_character, set_damage, set_equipment,
## update_turn) and owns what the buttons do.

const AREA := Rect2(363, 776, 947, 268)  # tab bar + body, screen pixels
const TAB_HEIGHT := 34.0
const GOLD := Color("c8a85a")
const BODY_BG := Color(0.04, 0.05, 0.08, 0.93)

var ability_button: Button
var reveal_button: Button

var _tabs := {}          # name -> tab Button
var _pages := {}         # name -> page Control
var _current := "you"
var _hidden := false
var _hide_button: Button
var _body: PanelContainer

# You
var _card: CharacterCard

# Equipment
var _equipment_row: HBoxContainer
var _equipment_empty: Label
var _equipment_count := 0

# This turn
var _turn_title: Label
var _step_rows: Array[Label] = []
var _step_tips: Array[Label] = []
var _reach_line: Label
var _anytime_heading: Label
var _anytime: Label


func _ready() -> void:
	position = AREA.position
	size = AREA.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	tab_row.position = Vector2(14, 0)
	tab_row.size = Vector2(AREA.size.x - 28, TAB_HEIGHT)
	add_child(tab_row)
	for tab_name in ["you", "equipment", "turn"]:
		var tab := Button.new()
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(120, TAB_HEIGHT)
		tab.add_theme_font_size_override("font_size", 17)
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_tab(tab)
		tab.pressed.connect(show_tab.bind(tab_name))
		tab_row.add_child(tab)
		_tabs[tab_name] = tab
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_row.add_child(spacer)
	_hide_button = Button.new()
	_hide_button.focus_mode = Control.FOCUS_NONE
	_hide_button.custom_minimum_size = Vector2(44, TAB_HEIGHT)
	_hide_button.add_theme_font_size_override("font_size", 17)
	_hide_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_tab(_hide_button)
	_hide_button.pressed.connect(func(): set_collapsed(not _hidden))
	tab_row.add_child(_hide_button)

	_body = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BODY_BG
	style.border_color = Color(GOLD, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.corner_radius_top_left = 0
	style.set_content_margin_all(14)
	_body.add_theme_stylebox_override("panel", style)
	_body.position = Vector2(0, TAB_HEIGHT - 2)
	_body.size = Vector2(AREA.size.x, AREA.size.y - TAB_HEIGHT + 2)
	_body.custom_minimum_size = _body.size
	_body.clip_contents = true
	add_child(_body)
	move_child(_body, 0)  # the tabs sit on its edge

	_pages.you = _build_you()
	_pages.equipment = _build_equipment()
	_pages.turn = _build_turn()
	for page in _pages.values():
		_body.add_child(page)
	apply_language()
	show_tab("you")


func show_tab(tab_name: String) -> void:
	_current = tab_name
	for n in _pages:
		_pages[n].visible = n == tab_name
		_tabs[n].button_pressed = n == tab_name
	if _hidden:
		set_collapsed(false)


## Slide the body down out of the way; the tabs stay to bring it back.
func set_collapsed(on: bool) -> void:
	_hidden = on
	_hide_button.text = "▴" if on else "▾"
	_hide_button.tooltip_text = Global.text("hub.show") if on else Global.text("hub.hide")
	var drop := AREA.size.y - TAB_HEIGHT - 6.0 if on else 0.0
	create_tween().tween_property(self, "position:y", AREA.position.y + drop, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _style_tab(tab: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var s := StyleBoxFlat.new()
		var on: bool = state in ["pressed", "hover_pressed"]
		s.bg_color = BODY_BG if on else Color(0.07, 0.08, 0.11, 0.88).lightened(0.08 if state == "hover" else 0.0)
		s.border_color = Color(GOLD, 0.6) if on else Color(1, 1, 1, 0.12)
		s.border_width_top = 2
		s.border_width_left = 2
		s.border_width_right = 2
		s.corner_radius_top_left = 9
		s.corner_radius_top_right = 9
		s.content_margin_left = 14
		s.content_margin_right = 14
		tab.add_theme_stylebox_override(state, s)
	tab.add_theme_color_override("font_color", Color(0.7, 0.7, 0.74))
	tab.add_theme_color_override("font_hover_color", Color(0.92, 0.9, 0.85))
	tab.add_theme_color_override("font_pressed_color", Color("ffd27a"))
	tab.add_theme_color_override("font_hover_pressed_color", Color("ffe2a8"))


func _heading() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("e8c060"))
	return label


func _text(size_px := 16) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	return label


func _gold_button(fill: Color, edge: Color) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", edge.lightened(0.55))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.53))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(9)
		s.set_border_width_all(2)
		s.set_content_margin_all(6)
		s.bg_color = {"normal": fill, "hover": fill.lightened(0.15), "pressed": fill.darkened(0.3),
			"disabled": Color(0.11, 0.11, 0.13)}[state]
		s.border_color = Color(0.32, 0.32, 0.35) if state == "disabled" else (edge.lightened(0.25) if state == "hover" else edge)
		button.add_theme_stylebox_override(state, s)
	return button


# --- You -------------------------------------------------------------------------

## Your character card, with Reveal / Use Ability under the life bar.
func _build_you() -> Control:
	_card = CharacterCard.new()
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card.side.add_child(gap)
	reveal_button = _gold_button(Color(0.2, 0.1, 0.28), Color("a77ad8"))
	_card.side.add_child(reveal_button)
	ability_button = _gold_button(Color(0.2, 0.15, 0.05), GOLD)
	_card.side.add_child(ability_button)
	return _card


func set_character(character: Dictionary, dmg: int) -> void:
	_card.set_character(character, dmg)


func set_damage(dmg: int) -> void:
	_card.set_damage(dmg)


# --- Equipment ---------------------------------------------------------------------

func _build_equipment() -> Control:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	scroll.add_child(column)
	_equipment_empty = _text(17)
	# One line: in a sideways-scrolling box a wrapping label gets no width
	# and puts one letter per line.
	_equipment_empty.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_equipment_empty)
	_equipment_row = HBoxContainer.new()
	_equipment_row.add_theme_constant_override("separation", 12)
	column.add_child(_equipment_row)
	return scroll


func set_equipment(cards: Array) -> void:
	for child in _equipment_row.get_children():
		child.queue_free()
	_equipment_count = cards.size()
	_equipment_empty.visible = cards.is_empty()
	for card in cards:
		_equipment_row.add_child(CardView.card_face(card, 200.0, false))
	_tabs.equipment.text = Global.text("hub.tab_equipment") + ("  %d" % cards.size() if not cards.is_empty() else "")


# --- This turn -------------------------------------------------------------------------

func _build_turn() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	var steps := VBoxContainer.new()
	steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steps.size_flags_stretch_ratio = 1.5
	steps.add_theme_constant_override("separation", 1)
	_turn_title = Label.new()
	_turn_title.add_theme_font_size_override("font_size", 19)
	_turn_title.add_theme_color_override("font_color", Color("ffe2a8"))
	steps.add_child(_turn_title)
	for i in 4:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var step := Label.new()
		step.custom_minimum_size = Vector2(190, 0)
		step.add_theme_font_size_override("font_size", 16)
		line.add_child(step)
		var tip := _text(14)
		tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(tip)
		steps.add_child(line)
		_step_rows.append(step)
		_step_tips.append(tip)
	_reach_line = _text(15)
	steps.add_child(_reach_line)
	row.add_child(steps)

	var anytime := VBoxContainer.new()
	anytime.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anytime.add_theme_constant_override("separation", 4)
	_anytime_heading = _heading()
	anytime.add_child(_anytime_heading)
	_anytime = _text(14)
	anytime.add_child(_anytime)
	row.add_child(anytime)
	return row


## The cheat sheet, from PlayScene's view of the turn.
## `at`: the current step indexes (0 roll .. 3 end; [] = between turns);
## `turn_name`: whose turn ("" = yours); `reach`: names you could attack now
## (null = not your attack step); `ability`: "" if Use Ability works now,
## else why not.
func update_turn(step_names: Array, at: Array, turn_name: String, reach, ability: String,
		revealed: bool) -> void:
	_turn_title.text = Global.text("hub.your_turn") if turn_name == "" else Global.text("hub.their_turn") % turn_name
	var tips := [Global.text("hub.tip_roll"), Global.text("hub.tip_location"),
		Global.text("hub.tip_attack"), Global.text("hub.tip_end")]
	var first: int = at[0] if not at.is_empty() else -1
	for i in 4:
		var now: bool = i in at
		var done: bool = first != -1 and i < first
		_step_rows[i].text = ("▶ " if now else ("✓ " if done else "   ")) + "%d. %s" % [i + 1, step_names[i]]
		_step_rows[i].add_theme_color_override("font_color",
			Color("ffd27a") if now else (Color(0.55, 0.57, 0.6) if done else Color(0.85, 0.85, 0.88)))
		_step_tips[i].text = tips[i]
		_step_tips[i].modulate.a = 1.0 if now or first == -1 else 0.6
	if reach == null:
		_reach_line.visible = false
	else:
		_reach_line.visible = true
		var names: Array = reach
		_reach_line.text = Global.text("hub.reach_none") if names.is_empty() \
			else Global.text("hub.reach_some") % ", ".join(names)
		_reach_line.add_theme_color_override("font_color", Color("ff8a7a") if not names.is_empty() else Color(0.7, 0.7, 0.72))
	var lines := []
	lines.append("• " + (Global.text("hub.ability_ready") if ability == "" else Global.text("hub.ability_not") % ability))
	if not revealed:
		lines.append("• " + Global.text("hub.tip_reveal"))
	lines.append("• " + Global.text("hub.tip_green"))
	lines.append("• " + Global.text("hub.tip_reach"))
	_anytime.text = "\n".join(lines)


func apply_language() -> void:
	_tabs.you.text = Global.text("hub.tab_you")
	_tabs.turn.text = Global.text("hub.tab_turn")
	_tabs.equipment.text = Global.text("hub.tab_equipment") + ("  %d" % _equipment_count if _equipment_count > 0 else "")
	_hide_button.text = "▴" if _hidden else "▾"
	_equipment_empty.text = Global.text("match.no_equipment_yet")
	_anytime_heading.text = Global.text("hub.anytime").to_upper()
	ability_button.text = Global.text("match.use_ability")
	reveal_button.text = Global.text("match.reveal")
	reveal_button.tooltip_text = Global.text("match.reveal_tooltip")
	_card.apply_language()
