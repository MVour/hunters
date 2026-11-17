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
## Not the default, so a running game is left alone (--port=N for a second test at once).
var port := 18080

var role := ""
## --leave-after=N: this bot leaves the match after N turns (BUG-001 test).
var leave_after := 0
## --join=wss://…/play/ROOM/TICKET: an online room (both bots join; "host"
## is then the room's owner and starts the match).
var join_link := ""
var stats := {"turns": 0, "my_turns": 0, "moves": 0, "cards": 0, "choices": 0,
	"questions": 0, "attacks": 0, "deaths": 0, "ui_picks": 0, "chat_heard": 0, "dialog_clicks": 0,
	"ui_attacks": 0, "ui_ends": 0}
var _last_progress := 0
var _my_turn := false
var _done := false
## --games=N: play N matches on the same table (Play again, BUG-009).
var _games_played := 0
var _table_size := 0  # players (bots too) the host waits for before starting
var _shots_taken := []
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
		elif arg.begins_with("--leave-after="):
			leave_after = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--join="):
			join_link = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			port = arg.get_slice("=", 1).to_int()
	name = "Autotest"


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	_last_progress = Time.get_ticks_msec()
	_connect_signals()
	await get_tree().process_frame
	var mc: MultiplayerController = get_tree().root.find_child("MultiplayerController", true, false)
	SignalBus._new_game.emit()  # main menu -> multiplayer menu
	if join_link != "":
		mc.line_edit.text = join_link
		mc._on_connect_lobby_button_pressed()
	elif role == "host":
		mc._on_host_pressed({"port": port})
	else:
		await get_tree().create_timer(1.0).timeout  # give the host time to listen
		mc.line_edit.text = "127.0.0.1:%d" % port
		mc._on_connect_lobby_button_pressed()

	await _until(func(): return GameState.players.has(GameState.local_id))
	var pawn := _arg("--pawn=", "red" if role == "host" else "blue")
	SignalBus._avatar_created.emit("Bot_%s_%s" % [role, pawn], pawn)
	ChatNet.say("hello from the %s" % role)

	if role == "host":
		var wanted := _arg("--players=", "2").to_int()
		await _until(func(): return GameState.players.size() >= wanted \
			and GameState.players.values().all(func(p): return p.pawn != ""))
		# --bots=N: the lobby's Players + Fill with bots buttons add N bots.
		var total := mini(wanted + _arg("--bots=", "0").to_int(), LobbyNet.MAX_PLAYERS)
		if total > wanted:
			for attempt in 10:  # the room may allow fewer players: it stops there
				if LobbyNet.team_total(GameState.game_settings) == total:
					break
				LobbyNet.change_player_count(signi(total - LobbyNet.team_total(GameState.game_settings)))
				await get_tree().create_timer(0.2).timeout
			total = LobbyNet.team_total(GameState.game_settings)
			LobbyNet.change_preset(1)  # also try the presets button
			await get_tree().create_timer(0.1).timeout
			LobbyNet.fill_with_bots()
			await _until(func(): return GameState.players.size() >= total)
		await get_tree().create_timer(0.5).timeout
		# --shot-lobby=PATH (not headless): save a picture of the lobby.
		var shot := _arg("--shot-lobby=", "")
		if shot != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot)
		_table_size = GameState.players.size()
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


## Dev pictures (not headless): `-- --shot-pick=PATH` the first time this bot
## picks a player, `--shot-end=PATH` the end screen. Once each.
func _shot_once(flag: String, wanted: Callable) -> void:
	var path := _arg(flag, "")
	var scene := get_tree().root.find_child("PlayScene", true, false)
	if path == "" or flag in _shots_taken or scene == null or not wanted.call(scene):
		return
	_shots_taken.append(flag)
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _on_game_over(faction: String, _winners: Array) -> void:
	# The result appears after the last blow has played out (END_PAUSE).
	for i in 120:
		if get_tree().root.find_child("PlayAgainButton", true, false):
			break
		await get_tree().create_timer(0.1).timeout
	if get_tree().root.find_child("PlayAgainButton", true, false) == null:
		_finish(false, "the end screen never appeared")
		return
	await get_tree().create_timer(1.0).timeout  # it fades in
	await _shot_once("--shot-end=", func(_scene): return true)
	_games_played += 1
	if _games_played >= _arg("--games=", "1").to_int():
		_finish(true, "game over, %s side won (game %d)" % [faction, _games_played])
		return
	print("AUTOTEST [%s] game %d over, %s side won: Play again" % [role, _games_played, faction])
	# Press the end screen's Play again, like a person (the client first).
	await get_tree().create_timer(0.5 if role == "client" else 1.0).timeout
	var again: Button = get_tree().root.find_child("PlayAgainButton", true, false)
	if again == null:
		_finish(false, "no Play again button on the end screen")
		return
	again.pressed.emit()
	_last_progress = Time.get_ticks_msec()
	if role == "host":
		await _until(func(): return GameState.phase == GameState.Phase.LOBBY \
			and GameState.players.size() >= _table_size)
		await get_tree().create_timer(1.0).timeout
		var mc: MultiplayerController = get_tree().root.find_child("MultiplayerController", true, false)
		_start_match(mc)


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
		await _shot_once("--shot-pick=", func(scene): return not scene.pick_ids.is_empty())
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
	# --shot-hit=PATH (not headless): a picture just after you take damage.
	SignalBus.damage_changed.connect(func(id, dmg):
		if id == GameState.local_id and dmg > 0:
			await get_tree().create_timer(0.35).timeout
			await _shot_once("--shot-hit=", func(_scene): return true))
	SignalBus.game_over.connect(_on_game_over)
	Network.host_disconnected.connect(func():
		if role == "client":
			_finish(true, "host ended the session", true))


func _on_begin_turn(player_id: int) -> void:
	stats.turns += 1
	_last_progress = Time.get_ticks_msec()
	# --shot-match=PATH (not headless): a picture of the match at turn 8.
	var shot := _arg("--shot-match=", "")
	if shot != "" and stats.turns == 8:
		_match_shot(shot)  # not awaited: the turn goes on meanwhile
	if role == "host" and stats.turns > max_turns:
		_finish(true, "left after %d turns" % max_turns)
		return
	if leave_after > 0 and stats.turns > leave_after:
		_finish(true, "left mid-match after %d turns" % leave_after)
		return
	# Online room: the other bot may have left (the room goes on); stop too.
	if join_link != "" and stats.turns > max_turns + 6:
		_finish(true, "kept playing after the other bot left")
		return
	_my_turn = player_id == GameState.local_id
	if not _my_turn:
		return
	stats.my_turns += 1
	await get_tree().create_timer(0.3).timeout
	MatchNet.roll()


## A little into turn 8 (its cards are out). --shot-drawer: one player's
## drawer open; --shot-key: the life track's "Who's who" open.
func _match_shot(path: String) -> void:
	await get_tree().create_timer(2.5).timeout
	var scene := get_tree().root.find_child("PlayScene", true, false)
	if scene == null:
		return
	if "--shot-drawer" in OS.get_cmdline_user_args():
		scene.player_list._rows.values()[2].toggle_drawer()
	if "--shot-key" in OS.get_cmdline_user_args():
		scene.damage_board._key_button.pressed.emit()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


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
	if _ui_mode():
		await _ui_attack_and_end()
		return
	if randf() < 0.6:
		MatchNet.attack()
	# Keep asking to end the turn; the server refuses while anything is pending.
	while _my_turn and not _done:
		await get_tree().create_timer(0.6).timeout
		MatchNet.end_turn()


## --ui: press the screen's Attack / End Turn buttons, only when they're shown
## and enabled, like a person. A turn that never offers End Turn stalls (and fails).
func _ui_attack_and_end() -> void:
	var scene := get_tree().root.find_child("PlayScene", true, false)
	var tried_attack := false
	while _my_turn and not _done and is_instance_valid(scene):
		await get_tree().create_timer(0.6).timeout
		if not is_instance_valid(scene) or not _my_turn:
			return
		if not tried_attack and scene.attack_button.is_visible_in_tree() and not scene.attack_button.disabled:
			tried_attack = true
			if randf() < 0.6:
				scene.attack_button.pressed.emit()
				stats.ui_attacks += 1
				continue
		if scene.end_turn_button.is_visible_in_tree() and not scene.end_turn_button.disabled:
			scene.end_turn_button.pressed.emit()
			stats.ui_ends += 1


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
	# Input arrives in window pixels; the game is drawn at 1920x1080 and scaled
	# to the window (stretch), so convert like a real mouse position would be.
	var at: Vector2 = get_viewport().get_final_transform() * centre
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		get_viewport().push_input(e)
		await get_tree().process_frame
	# Still the same pick open = the click didn't land (a new pick may follow
	# right away, e.g. a card that targets twice: that's fine).
	if not is_instance_valid(scene):
		return true  # the match ended meanwhile
	if not scene.pick_ids.is_empty() and scene.pick_serial == serial:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
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
	var text := "my_turn=%s" % _my_turn
	var scene := get_tree().root.find_child("PlayScene", true, false)
	if scene:
		text += " step=%s end=%s/%s attack=%s/%s status='%s' picking=%s choice_open=%s offer=%s" % [
			GameState.game_info.get("step"), scene.end_turn_button.is_visible_in_tree(), scene.end_turn_button.disabled,
			scene.attack_button.is_visible_in_tree(), scene.attack_button.disabled, scene.status_label.text,
			scene.pick_ids, scene.server_choice_open, scene.offered_action]
	if s:
		text += " | turn=%s busy=%s awaiting=%s" % [s.turn, s._busy, s._awaiting]
	return text


## A command-line value: `-- --name=value` (or the default).
func _arg(prefix: String, default: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return default
