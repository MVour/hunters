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
	"questions": 0, "attacks": 0, "deaths": 0}
var _last_progress := 0
var _my_turn := false
var _done := false


func _init(p_role: String) -> void:
	role = p_role
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

	if role == "host":
		await _until(func(): return GameState.players.size() >= 2 \
			and GameState.players.values().all(func(p): return p.pawn != ""))
		await get_tree().create_timer(0.5).timeout
		_start_match(mc)


func _process(_delta: float) -> void:
	if _done:
		return
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
	SignalBus.choice_requested.connect(func(_prompt, options, _skip):
		stats.choices += 1
		await _think()
		MatchNet.choose(options[randi() % options.size()].value))
	SignalBus.question_drawn.connect(_on_question_drawn)
	SignalBus.question_asked.connect(func(_from, _card):
		stats.questions += 1
		await get_tree().create_timer(0.2).timeout
		MatchNet.answer_question())
	SignalBus.pawn_moved.connect(func(_id, _loc): stats.moves += 1)
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
	var draws: Array = Global.DRAW_ACTIONS.get(action, [])
	if not draws.is_empty():
		MatchNet.draw(draws[randi() % draws.size()])
	elif action in ["heal_or_damage", "steal_equipment"]:
		MatchNet.use_location()
	else:
		MatchNet.skip_action()
	await get_tree().create_timer(1.0).timeout
	if randf() < 0.6:
		MatchNet.attack()
	# Keep asking to end the turn; the server refuses while anything is pending.
	while _my_turn and not _done:
		await get_tree().create_timer(0.6).timeout
		MatchNet.end_turn()


func _on_question_drawn(_card: Dictionary) -> void:
	await _think()
	for id in GameState.game_info.players_turn:
		if id != GameState.local_id and not GameState.players[id].dead:
			MatchNet.give_question(id)
			return


# --- Helpers ------------------------------------------------------------------

func _think() -> void:
	if randf() < 0.5:
		await get_tree().create_timer(0.15).timeout


func _until(condition: Callable) -> void:
	while not condition.call():
		await get_tree().process_frame


func _finish(ok: bool, why: String, already_left := false) -> void:
	if _done:
		return
	_done = true
	print("AUTOTEST %s [%s] %s | %s" % ["PASS" if ok else "FAIL", role, why, stats])
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
