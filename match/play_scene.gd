class_name PlayScene extends Node2D

@onready var damage_board: DamageBoard = $DamageBoard
@onready var player_hud: PlayerHud = $Hud/PlayerHud
@onready var decks_container: HBoxContainer = $DecksContainer
@onready var deck_scn : PackedScene = preload("res://match/cards/card_deck.tscn")
@onready var game_map: GameMap = $Locations
@onready var end_turn_button: Button = $EndTurnButton
@onready var roll_button: Button = $DicesContainer/RollButton
@onready var playing_label: Label = $PlayingLabel

var game_finished := false
var pawn_layer: PawnLayer
var prompt_label: Label
var toast_box: VBoxContainer
var choice_panel: PanelContainer
var choice_title: Label
var choice_buttons: HFlowContainer
## Left of the choices: the card the choice is about (if any).
var choice_card_slot: CenterContainer
## The card you're acting on right now (drawn / being asked), shown in the
## dialog so you can read what it does while choosing. {} = none.
var _context_card := {}
## Whether the open dialog is the location offer (closed when the turn ends).
var _offer_open := false
## Values offered by the open choice panel (empty when closed).
var asked_options := []
var attack_button: Button
var reveal_button: Button
var attack_used_this_turn := false
## This turn: you've moved (so attack / end turn make sense).
var moved_this_turn := false
## You drew a green card and still have to give it to someone.
var question_to_give := false
## The server is waiting for you to pick in the choice panel.
var server_choice_open := false
## You gave your green card to this player; they still have to answer (0 = none).
var question_waiting_on := 0
## This player gave you a green card you haven't answered yet (0 = none).
var question_from := 0
## One line at the bottom: what's happening and who we're waiting on.
var status_label: Label
## Everyone, down the right edge (replaces the old seats around the board).
var player_list: PlayerList
## Players you may pick right now (attack, card target…); [] when not picking.
var pick_ids := []
## Counts picks started (tests use it to tell "my click worked" from "a new pick began").
var pick_serial := 0
var _pick_callback: Callable
var _refresh_queued := false
var decks := {}  # card type -> CardDeck
## Locations you may pick after rolling a 7 (empty when not choosing).
var choice_options := []
## The location action currently offered to you ("" when none).
var offered_action := ""


func _ready():
	SignalBus._set_character.connect(_on_set_character)
	SignalBus.set_locations.connect(_on_set_locations)
	SignalBus._attach_deck.connect(_on_attach_deck)
	SignalBus.begin_turn.connect(_on_begin_turn)
	SignalBus.end_turn.connect(_on_end_turn)
	SignalBus.pawn_moved.connect(_on_pawn_moved)
	SignalBus.choose_location.connect(_on_choose_location)
	SignalBus.damage_changed.connect(_on_damage_changed)
	game_map.location_chosen.connect(_on_location_chosen)

	# Classic art: the original path-tile board replaces the forest clearing
	# (the forest stays in the scene, just hidden).
	if Global.classic_art:
		var forest: Node2D = $ForestBoard
		var classic: Node2D = preload("res://match/board/classic_board.tscn").instantiate()
		add_child(classic)
		move_child(classic, forest.get_index())
		forest.hide()
		forest.process_mode = Node.PROCESS_MODE_DISABLED

	# Players down the right edge (top-right corner; decks are bottom-right),
	# the life track down the left edge.
	player_list = PlayerList.new()
	player_list.position = Vector2(1920 - 8 - PlayerList.WIDTH, 12)
	player_list.z_index = 4
	add_child(player_list)
	player_list.player_picked.connect(_on_player_picked)
	damage_board.position = Vector2(8, 120)
	# The decks: a small row of packs on the left, under the life track.
	decks_container.position = Vector2(8, 560)
	decks_container.scale = Vector2(0.62, 0.62)

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

	# Announcements: small black boxes stacked near the top, fading out.
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(560, 150)
	toast_box.size = Vector2(800, 0)
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.add_theme_constant_override("separation", 6)
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
	# [the card it's about] [the choices]
	var choice_row := HBoxContainer.new()
	choice_row.add_theme_constant_override("separation", 16)
	choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_column.add_child(choice_row)
	choice_card_slot = CenterContainer.new()
	choice_row.add_child(choice_card_slot)
	choice_buttons = HFlowContainer.new()
	choice_buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	choice_buttons.custom_minimum_size = Vector2(420, 0)
	choice_buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_buttons.add_theme_constant_override("h_separation", 10)
	choice_buttons.add_theme_constant_override("v_separation", 8)
	choice_row.add_child(choice_buttons)

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
	attack_button.position = Vector2(640, 702)
	attack_button.custom_minimum_size = Vector2(205, 44)
	attack_button.add_theme_color_override("font_color", Color("ff8a7a"))
	attack_button.hide()
	attack_button.pressed.connect(func():
		attack_used_this_turn = true
		_queue_refresh()
		MatchNet.attack())
	add_child(attack_button)

	# HUD: Use Ability + Reveal.
	var ability_button: Button = $Hud/PlayerHud/AbilityButton
	ability_button.pressed.connect(MatchNet.use_ability)
	reveal_button = Button.new()
	reveal_button.position = ability_button.position + Vector2(0, -44)
	reveal_button.custom_minimum_size = Vector2(ability_button.size.x, 36)
	reveal_button.pressed.connect(MatchNet.reveal)
	ability_button.get_parent().add_child(reveal_button)

	status_label = Label.new()
	status_label.position = Vector2(410, 752)
	status_label.size = Vector2(1100, 40)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("ffe2a8"))
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 8)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.z_index = 5
	add_child(status_label)

	_apply_language()
	Global.language_changed.connect(_apply_language)

	# Grey out what you can't do right now (the server would refuse it anyway).
	for sig in [SignalBus.begin_turn, SignalBus.end_turn, SignalBus.equipment_changed,
			SignalBus.ability_used, SignalBus.question_drawn, SignalBus.waiting_changed,
			SignalBus.location_action_offered, SignalBus.choose_location]:
		sig.connect(_queue_refresh.unbind(1))
	for sig in [SignalBus.pawn_moved, SignalBus.player_died, SignalBus.character_revealed,
			SignalBus.question_passed, SignalBus._set_character, SignalBus.game_over,
			SignalBus.damage_changed, SignalBus.question_asked, SignalBus.question_answered]:
		sig.connect(_queue_refresh.unbind(2))
	SignalBus.attack_happened.connect(_on_attack_happened)
	SignalBus.game_over.connect(_on_game_over)

	MatchNet.loaded()


func _on_set_locations(_locations):
	game_map.locations_spawn()
	pawn_layer.setup(game_map, GameState.players)
	pawn_layer.player_picked.connect(_on_player_picked)
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


func _on_set_character(_pl_id, character):
	player_hud.init(Global.field(character, "name"), character.species,
		Global.field(character, "goal"), Global.field(character, "ability"),
		character.health, GameState.local_player.dmg)


## Texts that are set once; re-run when the player switches language.
func _apply_language() -> void:
	roll_button.text = Global.text("dice.roll")
	end_turn_button.text = Global.text("match.end_turn")
	attack_button.text = Global.text("match.attack")
	$Hud/PlayerHud/AbilityButton.text = Global.text("match.use_ability")
	reveal_button.text = Global.text("match.reveal")
	reveal_button.tooltip_text = Global.text("match.reveal_tooltip")
	$Hud/PlayerHelp/Label.text = Global.text("hud.help")
	if not GameState.local_player.character.is_empty():
		_on_set_character(GameState.local_id, GameState.local_player.character)
	_refresh_my_cards()
	_queue_refresh()


# --- Turn flow UI ------------------------------------------------------------

func _on_begin_turn(pl_id):
	var my_turn: bool = pl_id == GameState.local_id
	playing_label.visible = my_turn
	roll_button.visible = my_turn
	if my_turn:
		moved_this_turn = false
		attack_used_this_turn = false


func _on_end_turn(pl_id):
	if pl_id == GameState.local_id:
		playing_label.hide()
		roll_button.hide()
		moved_this_turn = false
		attack_used_this_turn = false
		_context_card = {}
		_clear_action_bar()


func _on_pawn_moved(pl_id, _location_id):
	if pl_id == GameState.local_id and GameState.local_player.playing:
		roll_button.hide()
		moved_this_turn = true


## Rolled a 7: light up every other location and wait for a click.
func _on_choose_location(options: Array) -> void:
	choice_options = options
	roll_button.hide()
	prompt_label.text = Global.text("match.rolled_seven_prompt")
	prompt_label.show()
	game_map.set_choosable(options)


func _on_location_chosen(location_id: String) -> void:
	if not location_id in choice_options:
		return
	choice_options = []
	prompt_label.hide()
	game_map.set_choosable([])
	MatchNet.choose_location(location_id)


func _on_end_turn_button_pressed() -> void:
	MatchNet.end_turn()


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh_buttons.call_deferred()


## Shows/enables the turn buttons from what this computer knows (GameState).
## Uses the same Rules as the server, so a greyed button is one the server
## would refuse. Disabled buttons say why in their tooltip.
func _refresh_buttons() -> void:
	_refresh_queued = false
	var me: Dictionary = GameState.local_player
	var my_turn: bool = me.get("playing", false) and not game_finished and not me.get("dead", false)
	var others_deciding: Array = GameState.game_info.get("waiting_for", [])
	var waiting: bool = server_choice_open or question_to_give or question_waiting_on != 0 \
		or not choice_options.is_empty() or not others_deciding.is_empty()
	var wait_reason := _status_text(my_turn)

	# While picking a player, turn buttons step aside: they sit over the bottom
	# of the board, where pawns can be the ones to click.
	var picking := not pick_ids.is_empty()
	attack_button.visible = my_turn and moved_this_turn and not attack_used_this_turn and not picking
	if attack_button.visible:
		var targets := Rules.attack_targets(GameState.players, GameState.locations,
			GameState.game_info.players_turn, GameState.local_id)
		if waiting:
			_set_enabled(attack_button, false, wait_reason)
		else:
			_set_enabled(attack_button, not targets.is_empty(),
				Global.text("match.nobody_in_reach"))

	end_turn_button.visible = my_turn and moved_this_turn and not picking
	_set_enabled(end_turn_button, not waiting, wait_reason)

	var ability_button: Button = $Hud/PlayerHud/AbilityButton
	var reason := _ability_blocked_reason(me, my_turn, waiting)
	_set_enabled(ability_button, reason == "", reason)

	status_label.text = _status_text(my_turn)
	status_label.visible = not game_finished

	reveal_button.visible = me.get("hidden", true) and not me.get("character", {}).is_empty()
	_set_enabled(reveal_button, not me.get("dead", false), Global.text("match.you_are_out"))


## The status line: what you should do, or who everyone is waiting on.
func _status_text(my_turn: bool) -> String:
	if question_to_give:
		return Global.text("status.give_green_card")
	if question_from != 0:
		return Global.text("status.answer_green_card") \
			% _player_name(question_from)
	if not pick_ids.is_empty():
		return Global.text("status.pick_player")
	if server_choice_open:
		return Global.text("status.make_choice")
	if not choice_options.is_empty():
		return Global.text("status.rolled_seven")
	if question_waiting_on != 0:
		return Global.text("status.waiting_answer") \
			% _player_name(question_waiting_on)
	var deciding := (GameState.game_info.get("waiting_for", []) as Array).filter(func(id): return id != GameState.local_id)
	if not deciding.is_empty():
		return Global.text("status.waiting_decide") \
			% ", ".join(deciding.map(_player_name))
	if my_turn:
		if not moved_this_turn:
			return Global.text("status.your_turn_roll")
		if offered_action != "":
			return Global.text("status.use_location")
		return Global.text("status.attack_or_end")
	for id in GameState.game_info.players_turn:
		if GameState.players[id].get("playing", false):
			return Global.text("status.someones_turn") % _player_name(id)
	return ""


## Why the Use Ability button can't be used now ("" = it can). Mirrors
## Combat.use_ability() on the server.
func _ability_blocked_reason(me: Dictionary, my_turn: bool, waiting: bool) -> String:
	var character: Dictionary = me.get("character", {})
	if character.is_empty() or game_finished:
		return Global.text("ability.no_character")
	if me.get("dead", false):
		return Global.text("match.you_are_out")
	match character.get("timing", ""):
		"passive":
			return "" if me.get("hidden", true) else Global.text("ability.passive_revealed")
		"attack":
			return Global.text("ability.offered_on_attack")
		"reactive":
			return Global.text("ability.offered_when_attacked")
	if me.get("ability_used", false):
		return Global.text("ability.already_used")
	if character.get("ability_id", "") != "switch_side" and not my_turn:
		return Global.text("ability.your_turn_only")
	if waiting:
		return Global.text("ability.finish_choice")
	return ""


func _set_enabled(button: Button, on: bool, reason := "") -> void:
	button.disabled = not on
	button.tooltip_text = "" if on else reason
	# Disabled buttons still need hover for the tooltip.
	button.mouse_filter = Control.MOUSE_FILTER_STOP


# --- Location actions & cards ------------------------------------------------

func _player_name(id: int) -> String:
	return GameState.players.get(id, {}).get("name", "?")


func _player_color(id: int) -> Color:
	var pawn: String = GameState.players.get(id, {}).get("pawn", "")
	return Color(Global.pawns[pawn].hex) if Global.pawns.has(pawn) else Color.WHITE


## Announcements: small black boxes that stack near the top and fade out.
## `message` is text, or a Msg from the server (shown in this player's language).
func toast(message) -> void:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	style.border_color = Color("c8a85a")
	style.border_width_left = 3
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = Global.msg(message)
	label.add_theme_font_size_override("font_size", 19)
	box.add_child(label)
	toast_box.add_child(box)
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(box, "modulate:a", 0.0, 0.6)
	tween.tween_callback(box.queue_free)


## The turn ended (or the game): close the location offer if it's open.
func _clear_action_bar() -> void:
	_queue_refresh()
	offered_action = ""
	prompt_label.hide()
	if _offer_open:
		_offer_open = false
		choice_panel.hide()
	for deck in decks.values():
		deck.set_highlight(false)


## You arrived somewhere: the dialog offers what the location lets you do.
## Drawing shows the decks as packs to click.
func _on_location_action_offered(action: String) -> void:
	_clear_action_bar()
	offered_action = action
	var loc := GameState.location_index(GameState.local_player.location)
	var loc_name := Global.field(GameState.locations[loc], "label") if loc != -1 else ""
	var info: Dictionary = Global.LOCATION_ACTIONS[action]
	var options := []
	var draws: Array = Global.DRAW_ACTIONS.get(action, [])
	for card_type in draws:
		options.append({"value": card_type})  # shown as a pack
		decks[card_type].set_highlight(true)
	if draws.is_empty():
		options.append({"value": "use", "label": Global.text("match.use"), "color": info.color})
	options.append({"value": "skip", "label": Global.text("match.skip"), "color": "b0b0b0"})
	_open_choice("%s: %s" % [loc_name, Global.field(info, "text")], options, false, func(value):
		_clear_action_bar()
		if value == "skip":
			MatchNet.skip_action()
		elif value == "use":
			MatchNet.use_location()
		else:
			MatchNet.draw(value))
	_offer_open = true


func _on_deck_count_changed(card_type: String, count: int) -> void:
	if decks.has(card_type):
		decks[card_type].set_count(count)


## You drew a green question: read it, then pick who to ask.
func _on_question_drawn(card: Dictionary) -> void:
	question_to_give = true
	_context_card = card
	var others: Array = GameState.game_info.players_turn.filter(func(id):
		return id != GameState.local_id and not GameState.players[id].dead)
	CardView.open(self, card, Global.text("match.your_question"),
		[[Global.text("match.choose_who_to_ask"), func():
			_start_pick(Global.text("match.who_do_you_ask"), others, false, func(id):
				question_to_give = false
				_queue_refresh()
				MatchNet.give_question(id))]])


## Someone asked you a question.
func _on_question_asked(from_id: int, card: Dictionary) -> void:
	question_from = from_id
	_context_card = card
	CardView.open(self, card, Global.text("match.asks_you") % _player_name(from_id),
		[[Global.text("match.answer"), func():
			question_from = 0
			_queue_refresh()
			MatchNet.answer_question()]])


func _on_question_passed(from_id: int, to_id: int) -> void:
	if from_id == GameState.local_id:
		question_to_give = false
		question_waiting_on = to_id
		_context_card = {}
	if to_id != GameState.local_id:
		toast(Global.text("match.toast_gave_green")
			% [_player_name(from_id), _player_name(to_id)])


func _on_question_answered(from_id: int, to_id: int) -> void:
	if from_id == GameState.local_id:
		question_waiting_on = 0
	if to_id == GameState.local_id:
		question_from = 0
		_context_card = {}
	toast(Global.text("match.toast_answered")
		% [_player_name(to_id), _player_name(from_id)])


func _on_card_drawn_secretly(pl_id: int, card_type: String) -> void:
	if pl_id != GameState.local_id:
		toast(Global.text("match.toast_drew_secret")
			% [_player_name(pl_id), Global.field(Global.CARD_COLORS[card_type], "label").to_lower()])


## Red/blue cards are read aloud: everyone sees them. If it's yours and it
## asks you something next ("use it now?", "choose a player"), the dialog
## takes the card over, so no OK is needed first.
func _on_card_revealed(pl_id: int, card: Dictionary) -> void:
	var mine := pl_id == GameState.local_id
	if mine:
		_context_card = card
	var who := Global.text("match.you_drew") if mine else Global.text("match.someone_drew") % _player_name(pl_id)
	var view := CardView.open(self, card, who, [["OK", func(): pass]])
	if view and not pick_ids.is_empty():
		view.make_passive()  # don't block the player who's picking someone


# --- Choices & private info --------------------------------------------------

## The server asks you to pick (a player, a deck, a piece of equipment...).
func _on_choice_requested(prompt_msg: Dictionary, options: Array, allow_skip: bool) -> void:
	server_choice_open = true
	_queue_refresh()
	var answer := func(value):
		server_choice_open = false
		_queue_refresh()
		MatchNet.choose(value)
	var prompt := Global.msg(prompt_msg)
	var context := _context_for(prompt_msg)
	# Picking a player: click them on the list or the board, not a button.
	var ids := _player_ids_in(options)
	if not ids.is_empty():
		_start_pick(prompt, ids, allow_skip, answer)
	else:
		_open_choice(prompt, options, allow_skip, answer, context)


## The card a server question is about, to show beside the choices: the
## card you just drew (its name is in the prompt, e.g. "Swarm of Bats:
## choose a player"), or the green card you're answering.
func _context_for(prompt_msg: Dictionary) -> Dictionary:
	if _context_card.is_empty():
		return {}
	if _context_card.get("kind", "") == "question":
		return _context_card
	# The prompt names the card (Msg.named keeps its uid).
	for value in prompt_msg.get("p", {}).values():
		if value is Dictionary and value.get("uid", "") == _context_card.get("uid", "-"):
			return _context_card
	return {}


## Full card for an equipment uid anyone holds (equipment is public), or {}.
func _equipment_card(uid) -> Dictionary:
	if not uid is String:
		return {}
	for p in GameState.players.values():
		for card in p.get("equipment", []):
			if card.get("uid", "") == uid:
				return card
	return {}


## The player ids if every option is a player, else [].
func _player_ids_in(options: Array) -> Array:
	var ids := []
	for option in options:
		var value = option.value
		if not (value is int and GameState.players.has(value)):
			return []
		ids.append(value)
	return ids


## Let the player pick one of `ids` on the player list or on the board.
## The choice panel only shows the prompt (and Skip, if allowed), compact
## so it never covers pawns at the bottom of the board; the card it's about
## stays readable in the bottom-right corner (passive popup).
func _start_pick(prompt: String, ids: Array, allow_skip: bool, on_pick: Callable) -> void:
	pick_ids = ids
	pick_serial += 1
	_pick_callback = on_pick
	_passivate_cards()
	player_list.set_pickable(ids)
	pawn_layer.set_pickable(ids)
	var hint := Global.text("match.pick_hint")
	_open_choice("%s\n%s" % [prompt, hint], [], allow_skip, func(value):
		_end_pick()
		on_pick.call(value))
	_queue_refresh()


## Open card popups move aside so the list and the board can be clicked.
func _passivate_cards() -> void:
	for child in get_children():
		if child is CardView:
			child.make_passive()


func _on_player_picked(id: int) -> void:
	if not id in pick_ids:
		return
	var callback := _pick_callback
	choice_panel.hide()
	_end_pick()
	callback.call(id)


func _end_pick() -> void:
	pick_ids = []
	player_list.set_pickable([])
	if pawn_layer.game_map:
		pawn_layer.set_pickable([])
	_queue_refresh()


## The black dialog. Options become deck packs (value = a deck),
## whole cards (value = an equipment uid) or buttons. `context` = the card
## this is about, shown on the left so you can read it while choosing.
func _open_choice(prompt: String, options: Array, allow_skip: bool, on_pick: Callable, context := {}) -> void:
	_offer_open = false
	for child in choice_buttons.get_children():
		child.queue_free()
	for child in choice_card_slot.get_children():
		child.queue_free()
	choice_title.text = prompt
	asked_options = options.map(func(o): return o.value)

	if not context.is_empty():
		_close_card_views_of(context)  # the dialog shows it now: no OK needed
		choice_card_slot.add_child(CardView.card_face(context, 230.0, 80.0))
	choice_card_slot.visible = not context.is_empty()

	var entries := options.duplicate()
	if allow_skip:
		entries.append({"value": null, "label": Global.text("match.skip"), "color": "b0b0b0"})
	for option in entries:
		var value = option.value
		var pick := func():
			choice_panel.hide()
			asked_options = []
			on_pick.call(value)
		var equipment := _equipment_card(value)
		if value is String and value in Global.CARD_TYPES:
			var count: int = decks[value]._count if decks.has(value) else 0
			var pack := DeckPack.new(value, count)
			pack.pressed.connect(pick)
			choice_buttons.add_child(pack)
		elif not equipment.is_empty():
			choice_buttons.add_child(_card_button(equipment, pick))
		else:
			var button := Button.new()
			button.text = Global.msg(option.get("label", str(value)))
			button.custom_minimum_size = Vector2(140, 44)
			button.add_theme_font_size_override("font_size", 19)
			if option.has("color"):
				button.add_theme_color_override("font_color", Color(option.color).lightened(0.25))
			button.pressed.connect(pick)
			choice_buttons.add_child(button)
	choice_panel.reset_size()
	choice_panel.show()
	await get_tree().process_frame
	choice_panel.reset_size()
	choice_panel.position = Vector2(960 - choice_panel.size.x / 2.0,
		clampf(1072.0 - choice_panel.size.y, 20.0, 812.0))


## A whole card you can click (e.g. which equipment to steal).
func _card_button(card: Dictionary, on_click: Callable) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var face := CardView.card_face(card, 190.0, 0.0)
	face.position = Vector2(4, 4)
	button.add_child(face)
	face.resized.connect(func(): button.custom_minimum_size = face.size + Vector2(8, 8))
	button.pressed.connect(on_click)
	button.mouse_entered.connect(func(): face.modulate = Color(1.25, 1.2, 1.1))
	button.mouse_exited.connect(func(): face.modulate = Color.WHITE)
	return button


func _close_card_views_of(card: Dictionary) -> void:
	for child in get_children():
		if child is CardView and child.shown_card.get("uid", "?") == card.get("uid", "!") \
				and child.dismissable:
			child.close()


## A message only for you, with an OK button.
## `title` / `text`: text, or Msgs from the server.
func _show_info(title, text) -> void:
	_open_choice("%s\n%s" % [Global.msg(title), Global.msg(text)], [{"value": "ok", "label": Global.text("option.ok")}], false,
		func(_v): pass)


func _on_private_character(pl_id: int, character: Dictionary) -> void:
	_show_info(Global.text("match.peek_title") % _player_name(pl_id),
		Global.text("match.peek_text") % [Global.field(character, "name"),
			Global.species_name(character.get("species", "")), character.get("health", 0), Global.field(character, "goal")])


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
		none.text = Global.text("match.no_equipment_yet")
		list.add_child(none)
	for card in equipment:
		var line := Label.new()
		line.text = "%s — %s" % [Global.field(card, "name"), Global.field(card, "text")]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(panel.size.x - 48, 0)
		line.add_theme_color_override("font_color", Color(Global.CARD_COLORS[card.deck].color).lightened(0.35))
		list.add_child(line)


# --- Attacks & the end -------------------------------------------------------

func _on_attack_happened(attacker: int, target: int, damage: int) -> void:
	pawn_layer.play_attack(attacker, target, damage)


func _on_game_over(faction: String, winners: Array) -> void:
	game_finished = true
	_end_pick()
	_clear_action_bar()
	status_label.hide()
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
		"vampire": Global.text("match.the_vampires_win"),
		"werewolf": Global.text("match.the_werewolves_win"),
	}.get(faction, Global.text("match.nobody_s_side_survived"))
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override("font_size", 40)
	headline.add_theme_color_override("font_color", Color("ffd27a"))
	column.add_child(headline)

	var me_won := GameState.local_id in winners
	var verdict := Label.new()
	verdict.text = Global.text("match.you_win") if me_won else Global.text("match.you_lose")
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verdict.add_theme_font_size_override("font_size", 30)
	column.add_child(verdict)

	for id in GameState.game_info.players_turn:
		var p: Dictionary = GameState.players[id]
		var row := Label.new()
		row.text = "%s %s — %s (%s)%s" % ["★" if id in winners else "  ", p.name, Global.field(p.character, "name"),
			Global.species_name(p.character.get("species", "")), "  †" if p.dead else ""]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", _player_color(id))
		column.add_child(row)

	var back := Button.new()
	back.text = Global.text("match.back_to_menu")
	back.custom_minimum_size = Vector2(260, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): SignalBus.leave_match.emit())
	column.add_child(back)
