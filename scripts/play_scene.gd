class_name PlayScene extends Node2D

@onready var damage_board: DamageBoard = $DamageBoard
@onready var players_slots: Node2D = $PlayersSlots
@onready var player_hud: PlayerHud = $Hud/PlayerHud
@onready var decks_container: HBoxContainer = $DecksContainer
@onready var deck_scn : PackedScene = preload("res://scenes/card_deck.tscn")
@onready var game_map: GameMap = $Locations
@onready var end_turn_button: Button = $EndTurnButton
@onready var roll_button: Button = $DicesContainer/RollButton
@onready var game_manager: GameManager = $GameManager
@onready var playing_label: Label = $PlayingLabel

var game_finished := false
var pawn_layer: PawnLayer
var prompt_label: Label
var action_bar: HBoxContainer
var toast_box: VBoxContainer
var choice_panel: PanelContainer
var choice_title: Label
var choice_buttons: HFlowContainer
## Values offered by the open choice panel (empty when closed).
var asked_options := []
var attack_button: Button
var reveal_button: Button
var attack_used_this_turn := false
var decks := {}  # card type -> CardDeck
## Locations you may pick after rolling a 7 (empty when not choosing).
var choice_options := []
## The location action currently offered to you ("" when none).
var offered_action := ""


func _ready():
	SignalBus._end_game.connect(_on_end_game)
	SignalBus._set_character.connect(_on_set_character)
	SignalBus.set_locations.connect(_on_set_locations)
	SignalBus._attach_deck.connect(_on_attach_deck)
	SignalBus.begin_turn.connect(_on_begin_turn)
	SignalBus.end_turn.connect(_on_end_turn)
	SignalBus.pawn_moved.connect(_on_pawn_moved)
	SignalBus.choose_location.connect(_on_choose_location)
	SignalBus.damage_changed.connect(_on_damage_changed)
	game_map.location_chosen.connect(_on_location_chosen)

	# Life track down the left edge.
	damage_board.position = Vector2(8, 192)

	# Pawns draw above the locations, below the HUD.
	pawn_layer = PawnLayer.new()
	pawn_layer.name = "Pawns"
	add_child(pawn_layer)
	move_child(pawn_layer, game_map.get_index() + 1)

	SignalBus.location_action_offered.connect(_on_location_action_offered)
	SignalBus.deck_count_changed.connect(_on_deck_count_changed)
	SignalBus.question_drawn.connect(_on_question_drawn)
	SignalBus.question_asked.connect(_on_question_asked)
	SignalBus.question_passed.connect(_on_question_passed)
	SignalBus.question_answered.connect(_on_question_answered)
	SignalBus.card_drawn_secretly.connect(_on_card_drawn_secretly)
	SignalBus.card_revealed.connect(_on_card_revealed)
	SignalBus.choice_requested.connect(_on_choice_requested)
	SignalBus.notice.connect(toast)
	SignalBus.private_info.connect(_show_info)
	SignalBus.private_character.connect(_on_private_character)
	SignalBus.equipment_changed.connect(_on_equipment_changed)

	action_bar = HBoxContainer.new()
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_bar.add_theme_constant_override("separation", 10)
	action_bar.position = Vector2(560, 636)
	action_bar.size = Vector2(800, 50)
	add_child(action_bar)

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(460, 190)
	toast_box.size = Vector2(1000, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.z_index = 15
	add_child(toast_box)

	# Choice panel (above the HUD): "choose a player", "which deck?", ...
	choice_panel = PanelContainer.new()
	var choice_style := StyleBoxFlat.new()
	choice_style.bg_color = Color(0.04, 0.05, 0.08, 0.94)
	choice_style.border_color = Color("c8a85a")
	choice_style.set_border_width_all(2)
	choice_style.set_corner_radius_all(10)
	choice_style.set_content_margin_all(14)
	choice_panel.add_theme_stylebox_override("panel", choice_style)
	choice_panel.z_index = 25
	choice_panel.hide()
	add_child(choice_panel)
	var choice_column := VBoxContainer.new()
	choice_column.add_theme_constant_override("separation", 10)
	choice_panel.add_child(choice_column)
	choice_title = Label.new()
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_title.add_theme_font_size_override("font_size", 22)
	choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_title.custom_minimum_size = Vector2(560, 0)
	choice_column.add_child(choice_title)
	choice_buttons = HFlowContainer.new()
	choice_buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	choice_buttons.add_theme_constant_override("h_separation", 10)
	choice_buttons.add_theme_constant_override("v_separation", 8)
	choice_column.add_child(choice_buttons)

	prompt_label = Label.new()
	prompt_label.position = Vector2(560, 446)
	prompt_label.size = Vector2(800, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 8)
	prompt_label.hide()
	add_child(prompt_label)

	playing_label.hide()
	end_turn_button.hide()
	roll_button.hide()

	# Signals are connected, so we're ready for the server's messages.
	# Attack button, next to End Turn.
	attack_button = Button.new()
	attack_button.text = "Attack  ·  Επίθεση"
	attack_button.position = Vector2(640, 702)
	attack_button.custom_minimum_size = Vector2(205, 44)
	attack_button.add_theme_color_override("font_color", Color("ff8a7a"))
	attack_button.hide()
	attack_button.pressed.connect(func():
		attack_used_this_turn = true
		attack_button.hide()
		game_manager.request_attack.rpc_id(1))
	add_child(attack_button)

	# HUD: Use Ability + Reveal.
	var ability_button: Button = $Hud/PlayerHud/AbilityButton
	ability_button.text = "Use Ability\nΙκανότητα"
	ability_button.pressed.connect(func(): game_manager.request_ability.rpc_id(1))
	reveal_button = Button.new()
	reveal_button.text = "Reveal · Αποκάλυψη"
	reveal_button.tooltip_text = "Show everyone your character card. Passive abilities only work once you're revealed."
	reveal_button.position = ability_button.position + Vector2(0, -44)
	reveal_button.custom_minimum_size = Vector2(ability_button.size.x, 36)
	reveal_button.pressed.connect(func(): game_manager.request_reveal.rpc_id(1))
	ability_button.get_parent().add_child(reveal_button)

	SignalBus.character_revealed.connect(func(pl_id, _c):
		if pl_id == GameState.local_id:
			reveal_button.hide())
	SignalBus.ability_used.connect(func(pl_id):
		if pl_id == GameState.local_id:
			ability_button.disabled = GameState.local_player.character.get("timing", "") == "once")
	SignalBus.attack_happened.connect(_on_attack_happened)
	SignalBus.game_over.connect(_on_game_over)

	game_manager.report_loaded.rpc_id(1)


func _on_set_locations(_locations):
	game_map.locations_spawn()
	pawn_layer.setup(game_map, GameState.players)
	damage_board.show_players(GameState.players)


func _on_damage_changed(pl_id, dmg):
	if pl_id == GameState.local_id:
		player_hud.player_damage.text = str(dmg)


func _on_attach_deck(card_type: String, count: int):
	var new_deck : CardDeck = deck_scn.instantiate()
	decks_container.add_child(new_deck)
	new_deck.add_cards(card_type, count)
	new_deck.init()
	decks[card_type] = new_deck


func _on_end_game():
	game_finished = true


func _on_set_character(_pl_id, character):
	player_hud.init("%s · %s" % [character.name, character.get("name_el", "")], character.species,
		"%s\n%s" % [character.goal, character.get("goal_el", "")],
		"%s\n%s" % [character.ability, character.get("ability_el", "")],
		character.health, GameState.local_player.dmg)


# --- Turn flow UI ------------------------------------------------------------

func _on_begin_turn(pl_id):
	var my_turn: bool = pl_id == GameState.local_id
	playing_label.visible = my_turn
	roll_button.visible = my_turn
	end_turn_button.hide()  # shown once you've moved


func _on_end_turn(pl_id):
	if pl_id == GameState.local_id:
		playing_label.hide()
		roll_button.hide()
		end_turn_button.hide()
		attack_button.hide()
		attack_used_this_turn = false
		_clear_action_bar()


func _on_pawn_moved(pl_id, _location_id):
	if pl_id == GameState.local_id and GameState.local_player.playing:
		roll_button.hide()
		end_turn_button.show()
		if not attack_used_this_turn:
			attack_button.show()


## Rolled a 7: light up every other location and wait for a click.
func _on_choose_location(options: Array) -> void:
	choice_options = options
	roll_button.hide()
	prompt_label.text = "You rolled 7! Pick any other location."
	prompt_label.show()
	game_map.set_choosable(options)


func _on_location_chosen(location_id: String) -> void:
	if not location_id in choice_options:
		return
	choice_options = []
	prompt_label.hide()
	game_map.set_choosable([])
	game_manager.request_choose_location.rpc_id(1, location_id)


func _on_end_turn_button_pressed() -> void:
	game_manager.request_end_turn.rpc_id(1)


# --- Location actions & cards ------------------------------------------------

func _player_name(id: int) -> String:
	return GameState.players.get(id, {}).get("name", "?")


func _player_color(id: int) -> Color:
	var pawn: String = GameState.players.get(id, {}).get("pawn", "")
	return Color(Global.pawns[pawn].hex) if Global.pawns.has(pawn) else Color.WHITE


## Short messages stack under the top seats and fade out.
func toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	toast_box.add_child(label)
	var tween := create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _clear_action_bar() -> void:
	for child in action_bar.get_children():
		child.queue_free()
	offered_action = ""
	prompt_label.hide()
	for deck in decks.values():
		deck.set_highlight(false)


func _add_action_button(text: String, color: Color, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 46)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", color)
	button.pressed.connect(func():
		_clear_action_bar()
		callback.call())
	action_bar.add_child(button)


## You arrived somewhere: offer what the location lets you do.
func _on_location_action_offered(action: String) -> void:
	_clear_action_bar()
	offered_action = action
	var loc_label := ""
	for loc in GameState.locations:
		if loc.id == GameState.local_player.location:
			loc_label = loc.label
	prompt_label.text = "%s: %s" % [loc_label, Global.LOCATION_ACTIONS[action].text]
	prompt_label.show()

	var draws: Array = GameManager.DRAW_ACTIONS.get(action, [])
	for card_type in draws:
		var info: Dictionary = Global.CARD_COLORS[card_type]
		_add_action_button("Draw %s" % info.label, Color(info.color).lightened(0.3),
			func(): game_manager.request_draw.rpc_id(1, card_type))
		decks[card_type].set_highlight(true)
	if draws.is_empty():
		_add_action_button("Use", Color(Global.LOCATION_ACTIONS[action].color).lightened(0.3),
			func(): game_manager.request_location_action.rpc_id(1))
	_add_action_button("Skip", Color(0.8, 0.8, 0.8),
		func(): game_manager.request_skip_action.rpc_id(1))


func _on_deck_count_changed(card_type: String, count: int) -> void:
	if decks.has(card_type):
		decks[card_type].set_count(count)


## You drew a green question: read it, then pick who to ask.
func _on_question_drawn(card: Dictionary) -> void:
	var buttons := []
	for id in GameState.game_info.players_turn:
		var player: Dictionary = GameState.players[id]
		if id != GameState.local_id and not player.dead:
			buttons.append([player.name, func(): game_manager.request_give_question.rpc_id(1, id), _player_color(id)])
	CardView.open(self, card, "Your question. Who do you ask?  ·  Σε ποιον τη δίνεις;", buttons)


## Someone asked you a question.
func _on_question_asked(from_id: int, card: Dictionary) -> void:
	CardView.open(self, card, "%s asks you:  ·  Σε ρωτάει:" % _player_name(from_id),
		[["Answer", func(): game_manager.request_answer_question.rpc_id(1)]])


func _on_question_passed(from_id: int, to_id: int) -> void:
	if to_id != GameState.local_id:
		toast("%s gave a green card to %s" % [_player_name(from_id), _player_name(to_id)])


func _on_question_answered(from_id: int, to_id: int) -> void:
	toast("%s answered %s's question" % [_player_name(to_id), _player_name(from_id)])


func _on_card_drawn_secretly(pl_id: int, card_type: String) -> void:
	if pl_id != GameState.local_id:
		toast("%s drew a %s card" % [_player_name(pl_id), Global.CARD_COLORS[card_type].label])


## Red/blue cards are read aloud: everyone sees them.
func _on_card_revealed(pl_id: int, card: Dictionary) -> void:
	var who := "You" if pl_id == GameState.local_id else _player_name(pl_id)
	CardView.open(self, card, "%s drew:" % who, [["OK", func(): pass]])


# --- Choices & private info --------------------------------------------------

## The server asks you to pick (a player, a deck, a piece of equipment...).
func _on_choice_requested(prompt: String, options: Array, allow_skip: bool) -> void:
	_open_choice(prompt, options, allow_skip,
		func(value): game_manager.request_choice.rpc_id(1, value))


func _open_choice(prompt: String, options: Array, allow_skip: bool, on_pick: Callable) -> void:
	for child in choice_buttons.get_children():
		child.queue_free()
	choice_title.text = prompt
	asked_options = options.map(func(o): return o.value)
	var entries := options.duplicate()
	if allow_skip:
		entries.append({"value": null, "label": "Skip", "color": "b0b0b0"})
	for option in entries:
		var button := Button.new()
		button.text = option.label
		button.custom_minimum_size = Vector2(140, 44)
		button.add_theme_font_size_override("font_size", 19)
		if option.has("color"):
			button.add_theme_color_override("font_color", Color(option.color).lightened(0.25))
		var value = option.value
		button.pressed.connect(func():
			choice_panel.hide()
			asked_options = []
			on_pick.call(value))
		choice_buttons.add_child(button)
	choice_panel.reset_size()
	choice_panel.show()
	await get_tree().process_frame
	choice_panel.position = Vector2(960 - choice_panel.size.x / 2.0, 812)


## A message only for you, with an OK button.
func _show_info(title: String, text: String) -> void:
	_open_choice("%s\n%s" % [title, text], [{"value": "ok", "label": "OK"}], false, func(_v): pass)


func _on_private_character(pl_id: int, character: Dictionary) -> void:
	_show_info("You secretly see %s's character:" % _player_name(pl_id),
		"%s, %s, %d health\n%s" % [character.get("name", "?"), character.get("species", "?"),
			character.get("health", 0), character.get("goal", "")])


func _on_equipment_changed(pl_id: int) -> void:
	if pl_id == GameState.local_id:
		_refresh_my_cards()


## The HUD "CARDS" tab lists your equipment.
func _refresh_my_cards() -> void:
	var panel: Control = $Hud/PlayerCards
	for child in panel.get_children():
		child.queue_free()
	var list := VBoxContainer.new()
	list.position = Vector2(24, 16)
	list.size = Vector2(panel.size.x - 48, 0)
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)
	var equipment: Array = GameState.local_player.equipment
	if equipment.is_empty():
		var none := Label.new()
		none.text = "No equipment yet.  ·  Κανένας εξοπλισμός."
		list.add_child(none)
	for card in equipment:
		var line := Label.new()
		line.text = "%s  ·  %s — %s" % [card.name, card.get("name_el", ""), card.text]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(panel.size.x - 48, 0)
		line.add_theme_color_override("font_color", Color(Global.CARD_COLORS[card.deck].color).lightened(0.35))
		list.add_child(line)


# --- Attacks & the end -------------------------------------------------------

func _on_attack_happened(attacker: int, target: int, damage: int) -> void:
	pawn_layer.play_attack(attacker, target, damage)


func _on_game_over(faction: String, winners: Array) -> void:
	_clear_action_bar()
	choice_panel.hide()
	CardView._queue.clear()
	for child in get_children():
		if child is CardView:
			child.close()
	for node in [roll_button, end_turn_button, attack_button, playing_label]:
		node.hide()

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = Vector2(1920, 1080)
	overlay.z_index = 30
	add_child(overlay)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.position = Vector2(460, 170)
	column.size = Vector2(1000, 0)
	overlay.add_child(column)

	var headline := Label.new()
	headline.text = {
		"vampire": "The vampires win!  ·  Οι βρικόλακες κερδίζουν!",
		"werewolf": "The werewolves win!  ·  Οι λυκάνθρωποι κερδίζουν!",
	}.get(faction, "Nobody's side survived.  ·  Καμία πλευρά δεν επέζησε.")
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override("font_size", 40)
	headline.add_theme_color_override("font_color", Color("ffd27a"))
	column.add_child(headline)

	var me_won := GameState.local_id in winners
	var verdict := Label.new()
	verdict.text = "You WIN!  ·  Κέρδισες!" if me_won else "You lose.  ·  Έχασες."
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict.add_theme_font_size_override("font_size", 30)
	column.add_child(verdict)

	for id in GameState.game_info.players_turn:
		var p: Dictionary = GameState.players[id]
		var row := Label.new()
		row.text = "%s %s — %s (%s)%s" % ["★" if id in winners else "  ", p.name, p.character.get("name", "?"),
			p.character.get("species", "?"), "  †" if p.dead else ""]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", _player_color(id))
		column.add_child(row)

	var back := Button.new()
	back.text = "Back to menu  ·  Μενού"
	back.custom_minimum_size = Vector2(260, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): SignalBus.leave_match.emit())
	column.add_child(back)
