extends Node
## Dev tool: a bot that plays the game by itself, for headless smoke tests.
## Started by main.gd when Godot runs with `-- --autotest=host` or
## `-- --autotest=client`. See tools/run_autotest.sh.
##
## It goes through the real flow: host/join, pick an avatar, start, then on
## its turns rolls, moves, draws, answers, attacks and ends the turn, using
## the same MatchNet / LobbyNet actions the UI uses.
##
## Prints "AUTOTEST PASS ..." and exits 0, or "AUTOTEST FAIL ..." and exits 1.

var max_turns := 30             # host leaves after this many turns (--max-turns=N)
const STALL_SECONDS := 40.0     # no new turn for this long = stuck
const TIME_SCALE := 4.0
const PORT := 18080            # not the default, so a running game is left alone

var role := ""
var stats := {"turns": 0, "my_turns": 0, "moves": 0, "cards": 0, "choices": 0,
	"questions": 0, "attacks": 0, "deaths": 0, "ui_picks": 0, "chat_heard": 0, "dialog_clicks": 0}
var _last_progress := 0
var _my_turn := false
var _done := false
## Every distinct status line the match screen showed (printed with -- --show-status).
var _statuses := []


func _init(p_role: String) -> void:
	role = p_role
	Global.persist_settings = false  # never touch the player's saved settings
	# Our own language (English unless --lang=el), whatever the player picked.
	var language := "en"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			language = arg.get_slice("=", 1)
	Global.lang = language
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--max-turns="):
			max_turns = arg.get_slice("=", 1).to_int()
	name = "Autotest"


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	_last_progress = Time.get_ticks_msec()
	_connect_signals()
	await get_tree().process_frame
	var mc: MultiplayerController = get_tree().root.find_child("MultiplayerController", true, false)
	SignalBus._new_game.emit()  # main menu -> multiplayer menu
	if role == "host":
		mc._on_host_pressed({"port": PORT})
	else:
		await get_tree().create_timer(1.0).timeout  # give the host time to listen
		mc.line_edit.text = "127.0.0.1:%d" % PORT
		mc._on_connect_lobby_button_pressed()

	await _until(func(): return GameState.players.has(GameState.local_id))
	SignalBus._avatar_created.emit("Bot_" + role, "red" if role == "host" else "blue")
	ChatNet.say("hello from the %s" % role)

	if role == "host":
		await _until(func(): return GameState.players.size() >= 2 \
			and GameState.players.values().all(func(p): return p.pawn != ""))
		await get_tree().create_timer(0.5).timeout
		_start_match(mc)


func _process(_delta: float) -> void:
	if _done:
		return
	var scene := get_tree().root.find_child("PlayScene", true, false)
	if scene and scene.status_label and scene.status_label.visible:
		var text: String = scene.status_label.text.get_slice("  ·  ", 0)
		for id in GameState.players:
			text = text.replace(GameState.players[id].name, "<P>")
		if not text in _statuses:
			_statuses.append(text)
		for box in scene.toast_box.get_children():  # announcements (black boxes)
			var toast_text: String = "TOAST " + box.get_child(0).text
			for id in GameState.players:
				toast_text = toast_text.replace(GameState.players[id].name, "<P>")
			if not toast_text in _statuses:
				_statuses.append(toast_text)
	if (Time.get_ticks_msec() - _last_progress) / 1000.0 > STALL_SECONDS:
		_finish(false, "stalled: no new turn for %ds" % STALL_SECONDS)


func _start_match(mc: MultiplayerController) -> void:
	mc.lobby._on_start_game_pressed()


# --- Reacting to the game -----------------------------------------------------

func _connect_signals() -> void:
	SignalBus.begin_turn.connect(_on_begin_turn)
	SignalBus.end_turn.connect(_on_end_turn)
	# Answers come either a moment later or instantly (same frame), to test
	# that the server never loses an early answer.
	SignalBus.choose_location.connect(func(options):
		await _think()
		MatchNet.choose_location(options[randi() % options.size()]))
	SignalBus.location_action_offered.connect(_on_location_action)
	# Attacks (and Old Map) wait for us to throw the dice. --ui: click the dice.
	SignalBus.roll_requested.connect(func(_prompt):
		await _think()
		var dice := get_tree().root.find_child("DicesContainer", true, false)
		if _ui_mode() and dice:
			await get_tree().process_frame  # let the screen show the dice first
			dice._on_roll_button_pressed()
		else:
			MatchNet.roll())
	SignalBus.choice_requested.connect(func(_prompt, options, _skip):
		stats.choices += 1
		await _think()
		# --ui: pick players by clicking them on the list / the board, like a person.
		if _ui_mode() and (await _click_pick() or await _press_dialog_option(false)):
			return
		MatchNet.choose(options[randi() % options.size()].value))
	SignalBus.question_drawn.connect(_on_question_drawn)
	SignalBus.question_asked.connect(func(_from, _card):
		stats.questions += 1
		await get_tree().create_timer(0.2).timeout
		MatchNet.answer_question())
	SignalBus.pawn_moved.connect(func(_id, _loc): stats.moves += 1)
	SignalBus.chat_message.connect(func(id, _n, _t):
		if id != GameState.local_id:
			stats.chat_heard += 1)
	SignalBus.card_revealed.connect(func(_id, _card): stats.cards += 1)
	SignalBus.card_drawn_secretly.connect(func(_id, _t): stats.cards += 1)
	SignalBus.attack_happened.connect(func(_a, _t, _d): stats.attacks += 1)
	SignalBus.player_died.connect(func(_id, _k): stats.deaths += 1)
	SignalBus.game_over.connect(func(faction, _winners): _finish(true, "game over, %s side won" % faction))
	Network.host_disconnected.connect(func():
		if role == "client":
			_finish(true, "host ended the session", true))


func _on_begin_turn(player_id: int) -> void:
	stats.turns += 1
	_last_progress = Time.get_ticks_msec()
	if role == "host" and stats.turns > max_turns:
		_finish(true, "left after %d turns" % max_turns)
		return
	_my_turn = player_id == GameState.local_id
	if not _my_turn:
		return
	stats.my_turns += 1
	await get_tree().create_timer(0.3).timeout
	MatchNet.roll()


func _on_end_turn(player_id: int) -> void:
	if player_id == GameState.local_id:
		_my_turn = false


func _on_location_action(action: String) -> void:
	await get_tree().create_timer(0.3).timeout
	if _ui_mode() and await _press_dialog_option(true):
		await _after_action()
		return
	var draws: Array = Global.DRAW_ACTIONS.get(action, [])
	if not draws.is_empty():
		MatchNet.draw(draws[randi() % draws.size()])
	elif action in ["heal_or_damage", "steal_equipment"]:
		MatchNet.use_location()
	else:
		MatchNet.skip_action()
	await _after_action()


func _after_action() -> void:
	await get_tree().create_timer(1.0).timeout
	if randf() < 0.6:
		MatchNet.attack()
	# Keep asking to end the turn; the server refuses while anything is pending.
	while _my_turn and not _done:
		await get_tree().create_timer(0.6).timeout
		MatchNet.end_turn()


func _on_question_drawn(_card: Dictionary) -> void:
	await _think()
	if _ui_mode():
		# Press "Choose who to ask" on the card, then click a player.
		await get_tree().process_frame
		var button := _find_button(get_tree().root, "Choose who to ask")
		if button:
			button.pressed.emit()
			if await _click_pick():
				return
	for id in GameState.game_info.players_turn:
		if id != GameState.local_id and not GameState.players[id].dead:
			MatchNet.give_question(id)
			return


# --- Clicking the screen (--ui) -----------------------------------------------

func _ui_mode() -> bool:
	return "--ui" in OS.get_cmdline_user_args()


## If the screen is in "pick a player" mode, click a highlighted player:
## alternately their row in the list and their pawn on the board.
## Returns true if it clicked (and the screen took it).
func _click_pick() -> bool:
	await get_tree().process_frame
	var scene := get_tree().root.find_child("PlayScene", true, false)
	if scene == null or scene.pick_ids.is_empty():
		return false
	var serial: int = scene.pick_serial
	var id: int = scene.pick_ids[randi() % scene.pick_ids.size()]
	var target: Control
	var on_board: bool = stats.ui_picks % 2 == 1
	if on_board:
		target = scene.pawn_layer._pick_areas[id]
	else:
		target = scene.player_list._rows[id]._card
	var centre: Vector2 = target.get_global_transform_with_canvas() * (target.size / 2.0)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = centre
		e.global_position = centre
		get_viewport().push_input(e)
		await get_tree().process_frame
	# Still the same pick open = the click didn't land (a new pick may follow
	# right away, e.g. a card that targets twice: that's fine).
	if not scene.pick_ids.is_empty() and scene.pick_serial == serial:
		var motion := InputEventMouseMotion.new()
		motion.position = centre
		motion.global_position = centre
		get_viewport().push_input(motion)
		await get_tree().process_frame
		var under: Control = get_viewport().gui_get_hovered_control()
		var owner_id := -1
		for pid in scene.pawn_layer._pick_areas:
			if scene.pawn_layer._pick_areas[pid] == under:
				owner_id = pid
		var now: Vector2 = target.get_global_transform_with_canvas() * (target.size / 2.0)
		_finish(false, ("clicked %s of player %d at %s but the pick didn't register; under the mouse: %s"
			+ " (pawn of %d, pickable %s, filter %s); target now at %s; pick ids %s") % ["pawn" if on_board else "row", id,
			centre, under.get_path() if under else "nothing", owner_id, owner_id in scene.pick_ids,
			under.mouse_filter if under else -1, now, scene.pick_ids])
		return true
	stats.ui_picks += 1
	return true


## --ui: press an option in the black dialog (a deck pack, a whole card or
## a button). prefer_pack: pick a deck pack when there is one.
func _press_dialog_option(prefer_pack: bool) -> bool:
	await get_tree().process_frame
	var scene := get_tree().root.find_child("PlayScene", true, false)
	if scene == null or not scene.choice_panel.visible:
		return false
	var options: Array = scene.choice_buttons.get_children().filter(func(c): return c is BaseButton and not c.is_queued_for_deletion())
	if options.is_empty():
		return false
	var packs := options.filter(func(c): return c is DeckPack)
	var button: BaseButton = (packs if prefer_pack and not packs.is_empty() else options).pick_random()
	stats.dialog_clicks += 1
	button.pressed.emit()
	return true


func _find_button(node: Node, text_start: String) -> Button:
	if node is Button and node.visible and (node as Button).text.begins_with(text_start):
		return node
	for child in node.get_children():
		var found := _find_button(child, text_start)
		if found:
			return found
	return null


# --- Helpers ------------------------------------------------------------------

func _think() -> void:
	if "--slow" in OS.get_cmdline_user_args():
		await get_tree().create_timer(3.0).timeout  # long enough to see "waiting for…"
	elif randf() < 0.5:
		await get_tree().create_timer(0.15).timeout


func _until(condition: Callable) -> void:
	while not condition.call():
		await get_tree().process_frame


func _finish(ok: bool, why: String, already_left := false) -> void:
	if _done:
		return
	_done = true
	if ok and stats.chat_heard == 0:
		ok = false
		why += " — but never heard the other bot in the chat"
	print("AUTOTEST %s [%s] %s | %s" % ["PASS" if ok else "FAIL", role, why, stats])
	if "--show-status" in OS.get_cmdline_user_args():
		for s in _statuses:
			print("STATUS [%s] %s" % [role, s])
	if not ok:
		print("AUTOTEST DEBUG ", _debug_state())
	# Leave the match the normal way first: quitting with the match still
	# running (paused coroutines, open connection) crashes Godot on exit.
	# Not in the middle of a signal the UI is still handling (like a click would).
	await get_tree().process_frame
	if not already_left:
		SignalBus.leave_match.emit()
	await get_tree().create_timer(0.5, true, false, true).timeout
	get_tree().quit(0 if ok else 1)


## What the server is waiting on (only meaningful on the host).
func _debug_state() -> String:
	var s: MatchServer = MatchNet.server
	if s == null:
		return "my_turn=%s" % _my_turn
	return "turn=%s busy=%s awaiting=%s" % [s.turn, s._busy, s._awaiting]
