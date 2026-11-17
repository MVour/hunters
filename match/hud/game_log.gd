class_name GameLog extends PanelContainer
## The match's running log: every turn, roll, move, card, green card,
## attack, damage, ability, reveal and death, newest at the bottom.
## Pure view: built only from the SignalBus events this screen already gets,
## so it shows exactly what this player may know (private lines, like a
## peek, are marked "only you"). Entries are kept as Msg dicts and re-drawn
## in the current language when it changes. Player names are in their colour.
## A header button folds it to one line.

## Ends above the bottom-right corner, where drawn / asked cards appear.
const SIZE_OPEN := Vector2(290, 225)
const SIZE_FOLDED := Vector2(290, 34)

var _text: RichTextLabel
var _toggle: Button
## [{"msg": Msg or text, "kind": "turn"/"private"/""}]
var _entries := []
var _dmg := {}            # player id -> damage we last saw (for +/- lines)
var _roll_total := 0      # the turn player's last movement throw (0 = none)
var _turn_player := 0
var _open := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.85)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	_toggle = Button.new()
	_toggle.flat = true
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toggle.add_theme_font_size_override("font_size", 16)
	_toggle.pressed.connect(func(): _set_open(not _open))
	column.add_child(_toggle)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_following = true
	_text.selection_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 13)
	_text.add_theme_font_size_override("bold_font_size", 13)
	_text.add_theme_font_size_override("italics_font_size", 13)
	_toggle.clip_text = true
	column.add_child(_text)

	SignalBus.begin_turn.connect(_on_begin_turn)
	SignalBus.dice_rolled.connect(_on_dice_rolled)
	SignalBus.pawn_moved.connect(_on_pawn_moved)
	SignalBus.card_revealed.connect(func(id, card):
		_add(Msg.make("log.drew", {"player": _name(id), "card": Msg.named(card)})))
	SignalBus.card_drawn_secretly.connect(func(id, _type):
		_add(Msg.make("log.drew_green", {"player": _name(id)})))
	SignalBus.question_passed.connect(func(from_id, to_id):
		_add(Msg.make("log.gave_green", {"player": _name(from_id), "target": _name(to_id)})))
	SignalBus.question_answered.connect(func(from_id, to_id):
		_add(Msg.make("log.answered", {"player": _name(from_id), "target": _name(to_id)})))
	SignalBus.notice.connect(func(message): _add(message))
	SignalBus.attack_happened.connect(func(_a, _t, _d): _roll_total = 0)  # not a movement throw
	SignalBus.damage_changed.connect(_on_damage_changed)
	SignalBus.ability_used.connect(func(id):
		_add(Msg.make("log.ability", {"player": _name(id)})))
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.private_character.connect(func(id, character):
		_add(Msg.make("log.you_saw", {"player": _name(id), "character": Msg.named(character),
			"species": Msg.species(character.get("species", ""))}), "private"))
	SignalBus.private_info.connect(func(_title, text):
		_add(Msg.make("log.only_you", {"text": text}), "private"))
	SignalBus.game_over.connect(func(_faction, _winners): _add(Msg.make("log.game_over"), "turn"))
	Global.language_changed.connect(_redraw)
	for id in GameState.players:
		_dmg[id] = GameState.players[id].dmg
	_set_open(true)


func _set_open(open: bool) -> void:
	_open = open
	_text.visible = open
	custom_minimum_size = SIZE_OPEN if open else SIZE_FOLDED
	size = custom_minimum_size
	_redraw()


# --- Events ----------------------------------------------------------------------

func _on_begin_turn(id: int) -> void:
	_turn_player = id
	_roll_total = 0
	_add(Msg.make("log.turn", {"player": _name(id), "round": GameState.game_info.round}), "turn")


## Movement throws: remembered until the pawn moves. (Attack throws are in
## the attack announcement.)
func _on_dice_rolled(val6: int, val4: int) -> void:
	_roll_total = val6 + val4


func _on_pawn_moved(id: int, location_id: String) -> void:
	var i := GameState.location_index(location_id)
	var place: Dictionary = Msg.named(GameState.locations[i]) if i != -1 else Msg.named({"name": "?"})
	if id == _turn_player and _roll_total > 0:
		_add(Msg.make("log.rolled_moved", {"player": _name(id), "total": _roll_total, "location": place}))
	else:
		_add(Msg.make("log.moved", {"player": _name(id), "location": place}))
	_roll_total = 0


func _on_damage_changed(id: int, dmg: int) -> void:
	var before: int = _dmg.get(id, 0)
	_dmg[id] = dmg
	if dmg > before:
		_add(Msg.make("log.damage", {"player": _name(id), "amount": dmg - before, "total": dmg}))
	elif dmg < before:
		_add(Msg.make("log.heal", {"player": _name(id), "amount": before - dmg, "total": dmg}))


func _on_player_died(id: int, killer_id: int) -> void:
	var character: Dictionary = GameState.players.get(id, {}).get("character", {})
	var params := {"player": _name(id), "character": Msg.named(character),
		"species": Msg.species(character.get("species", ""))}
	if killer_id != 0 and killer_id != id:
		params.killer = _name(killer_id)
		_add(Msg.make("log.killed", params), "turn")
	else:
		_add(Msg.make("log.died", params), "turn")


# --- Drawing -------------------------------------------------------------------------

func _name(id: int) -> String:
	return GameState.players.get(id, {}).get("name", "?")


func _add(message, kind := "") -> void:
	_entries.append({"msg": message, "kind": kind})
	if _open:
		_text.append_text(_line(_entries.back()) + "\n")
	else:
		_toggle.text = _header()


func _redraw(_lang = null) -> void:
	_toggle.text = _header()
	_text.clear()
	if not _open:
		return
	var lines := []
	for entry in _entries:
		lines.append(_line(entry))
	_text.append_text("\n".join(lines) + ("\n" if not lines.is_empty() else ""))


## Folded: the title and the latest line, so it still tells you something.
func _header() -> String:
	var title := Global.text("log.title")
	if _open or _entries.is_empty():
		return title + ("  ▾" if _open else "  ▸")
	return "%s  ▸  %s" % [title, Global.msg(_entries.back().msg)]


func _line(entry: Dictionary) -> String:
	var text := Global.msg(entry.msg).replace("[", "[lb]")  # no formatting from names
	text = _colour_names(text)
	match entry.kind:
		"turn":
			return "[b][color=#c8a85a]%s[/color][/b]" % text
		"private":
			return "[i][color=#9fb6d8]%s[/color][/i]" % text
	return text


## Every player's name in their pawn's colour (longest names first, whole words).
func _colour_names(text: String) -> String:
	var players := GameState.players.values().duplicate()
	players.sort_custom(func(a, b): return a.name.length() > b.name.length())
	for p in players:
		if p.name == "" or not Global.pawns.has(p.pawn):
			continue
		var name_safe: String = p.name.replace("[", "[lb]")
		var re := RegEx.create_from_string("(?<![\\w\\]])" + _escape_regex(name_safe) + "(?![\\w\\[])")
		if re == null:
			continue
		text = re.sub(text, "[color=#%s]%s[/color]" % [Global.pawns[p.pawn].hex, name_safe], true)
	return text


static func _escape_regex(s: String) -> String:
	var out := ""
	for c in s:
		out += ("\\" + c) if c in ".^$*+?()[]{}|\\/" else c
	return out
