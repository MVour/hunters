class_name MatchServer extends Node
## Runs one match. Exists only on the server (MatchNet.create_server()).
##
## - Requests arrive from MatchNet with the sender's id already checked to be
##   the real sender; every function here still checks the sender is ALLOWED.
## - All truth lives in `state` (ServerState). Clients learn things only
##   through MatchNet messages (`MatchNet.xxx.rpc(...)`).
## - Anything that waits (choices, pauses) waits on signals/timers owned by
##   this node, so freeing it (MatchNet.stop()) cancels everything cleanly.
##
## Helpers: `cards` (drawing, questions, equipment), `combat` (health,
## attacks, reveal, abilities, winning), `effects` (card effect steps).

enum TurnPhase { ROLL, CHOOSE_LOCATION, ACTION }

signal choice_made(ask_id: int)

var state: ServerState
var cards: CardFlow
var combat: Combat
var effects: CardEffects

var started := false
var finished := false

var turn := {
	"count": 0,
	"player": 0,
	"phase": TurnPhase.ROLL,
	"roll": {"val6": 0, "val4": 0},
	"action_used": false,
	"attacked": false,
	"pending_question": {},
	"step": "",  # what everyone sees: roll, choose_location, location, attack_or_end, end
}

var _loaded := {}      # player ids whose match screen is ready
var _gone := {}        # player ids who left during the match (BUG-001)
var _busy := 0         # effects/attacks in progress; the turn can't end meanwhile
var _awaiting := {}    # player id -> {"id": ask id, "values": [...], "skip": bool}
var _answers := {}     # ask id -> chosen value
var _next_ask_id := 1
## Bot seats (player id -> BotSeat): players with no computer behind them.
var bots := {}


func _init(server_state: ServerState) -> void:
	name = "MatchServer"
	state = server_state
	effects = CardEffects.new(self)
	cards = CardFlow.new(self)
	combat = Combat.new(self)
	for id in state.players:
		if LobbyNet.is_bot(state.players[id]):
			bots[id] = BotSeat.new(self, id)
			_loaded[id] = true  # no screen to wait for


# --- Starting ------------------------------------------------------------------

## Every player reports when their match screen is ready. The match starts
## when all have, so no message hits a screen that isn't there yet.
func peer_loaded(player_id: int) -> void:
	if not state.players.has(player_id):
		return
	_loaded[player_id] = true
	if started:
		return
	for id in state.players:
		if not _loaded.has(id):
			return
	_start()


func _start() -> void:
	started = true
	state.prepare_deck()
	_deal_characters()
	for card_type in Global.CARD_TYPES:
		MatchNet.attach_deck.rpc(card_type, state.deck[card_type].size())
	MatchNet.set_locations.rpc(state.locations)
	state.turn_order = state.players.keys()
	state.turn_order.shuffle()
	MatchNet.set_turn_order.rpc(state.turn_order)
	for id in _gone:  # left while the match screens were loading
		_drop(id)
	_start_turn()


## Each player gets a secret character. Only the owner is told which one.
func _deal_characters() -> void:
	var chosen := []
	for settings_key in Global.SPECIES:
		var list_name: String = Global.SPECIES[settings_key].list
		var count: int = state.settings.get(settings_key, 0)
		chosen.append_array(state.deck.characters[list_name].slice(0, count))
	chosen.shuffle()
	if chosen.size() < state.players.size():
		push_error("Not enough characters for %d players (the lobby should have blocked this)." % state.players.size())
		return
	var i := 0
	for id in state.players:
		state.players[id].character = chosen[i]
		tell(id, &"set_character", [chosen[i]])
		i += 1


# --- Turns ---------------------------------------------------------------------

func _start_turn() -> void:
	if finished:
		return
	var order: Array = state.turn_order
	var player_id: int = order[turn.count % order.size()]
	for i in order.size():  # skip players who are out
		if not state.players[player_id].dead:
			break
		turn.count += 1
		player_id = order[turn.count % order.size()]
	turn.count += 1
	turn.player = player_id
	turn.phase = TurnPhase.ROLL
	turn.action_used = false
	turn.attacked = false
	turn.pending_question = {}
	@warning_ignore("integer_division")
	state.round = (turn.count - 1) / order.size() + 1

	print("Starting turn %d (round %d), player %d" % [turn.count, state.round, player_id])
	state.players[player_id].playing = true
	MatchNet.turn_changed.rpc(player_id, true, state.round)
	set_step("roll")
	combat.turn_start_effects(player_id)
	if bots.has(player_id):
		bots[player_id].take_turn()


func _finish_turn(player_id: int) -> void:
	state.players[player_id].playing = false
	MatchNet.turn_changed.rpc(player_id, false, state.round)


func end_turn(sender: int) -> void:
	# You have to move first, and an asked question has to be answered.
	if not is_current(sender) or turn.phase != TurnPhase.ACTION:
		return
	if not turn.pending_question.is_empty() or busy():
		return
	_finish_turn(sender)
	_start_turn()


## BUG-001: a player left during the match. They're out, like dying with no
## killer: their character is shown, anything waiting on them gets a default
## answer, and if it was their turn the next player goes. The match goes on.
func player_left(player_id: int) -> void:
	if not state.players.has(player_id) or _gone.has(player_id):
		return
	_gone[player_id] = true
	if not started:
		peer_loaded(player_id)  # don't wait for their screen; _start drops them
		return
	_drop(player_id)
	# Only bots left: nobody is watching, stop playing.
	if state.players.keys().all(func(id): return bots.has(id) or _gone.has(id)):
		finished = true
		LobbyNet.match_over()


func is_gone(player_id: int) -> bool:
	return _gone.has(player_id)


func _drop(player_id: int) -> void:
	if finished:
		return
	var p: Dictionary = state.players[player_id]
	notice(Msg.make("notice.player_left", {"player": p.name}))
	var q: Dictionary = turn.pending_question
	if not q.is_empty() and not q.get("answering", false) and player_id in [q.from, q.to]:
		state.discard(q.card)
		turn.pending_question = {}
		if q.to != 0:
			MatchNet.question_answered.rpc(q.from, q.to)
	if not p.dead:
		combat.leave(player_id)
	_answer_for_gone(player_id)
	if turn.player != 0:
		after_resolution()


## Whatever the server was asking a player who left: skip if allowed, else
## the first option (a dice throw just happens).
func _answer_for_gone(player_id: int) -> void:
	if not _awaiting.has(player_id):
		return
	var waiting: Dictionary = _awaiting[player_id]
	_awaiting.erase(player_id)
	_answers[waiting.id] = null if waiting.skip else waiting.values[0]
	_broadcast_waiting()
	choice_made.emit(waiting.id)


## After an effect finishes: if the current player died meanwhile, move on.
func after_resolution() -> void:
	if busy() or finished:
		return
	if state.players[turn.player].dead:
		_finish_turn(turn.player)
		_start_turn()


func is_current(player_id: int) -> bool:
	return started and not finished and player_id == turn.player


func can_act(player_id: int) -> bool:
	return is_current(player_id) and turn.phase == TurnPhase.ACTION \
		and not turn.action_used and not busy()


# --- Rolling & moving -------------------------------------------------------------

func roll(sender: int) -> void:
	# Someone is waiting on this player's throw (an attack, Old Map's second roll).
	if _awaiting.get(sender, {}).get("roll", false):
		choice(sender, "roll")
		return
	if not is_current(sender) or turn.phase != TurnPhase.ROLL or busy():
		return
	var here: String = state.players[sender].location
	var result := _roll_move(here)
	var total: int = result.total
	var destination: String = result.destination

	# Old Map: may roll a second time and pick either result.
	if total != Global.ROLL_ANY_LOCATION and effects.mods(sender).get("reroll_move", false):
		busy_begin()
		var first := _location_name(destination)
		var again = await ask(sender, Msg.make("prompt.old_map_keep", {"location": first}), [
			{"value": "keep", "label": Msg.make("option.go_to", {"location": first})},
			{"value": "reroll", "label": Msg.make("option.roll_again")}], false, {"destination": destination})
		if again == "reroll":
			await ask_roll(sender, Msg.make("prompt.roll_move_again"))
			var second := _roll_move(here)
			if second.total == Global.ROLL_ANY_LOCATION:
				total = second.total
			elif second.destination != destination:
				destination = await ask(sender, Msg.make("prompt.old_map_pick"), [
					{"value": destination, "label": first},
					{"value": second.destination, "label": _location_name(second.destination)}], false)
		busy_end()

	if total == Global.ROLL_ANY_LOCATION:
		turn.phase = TurnPhase.CHOOSE_LOCATION
		set_step("choose_location")
		var options := []
		for loc in state.locations:
			if loc.id != here:
				options.append(loc.id)
		tell(sender, &"prompt_choose_location", [options])
	else:
		_move_player(sender, destination)


## Server-side dice: d6 + d4 until they point somewhere new (7 = your choice).
## Everyone sees the final throw.
func _roll_move(here: String) -> Dictionary:
	var dice := {}
	var total := 0
	var destination := ""
	for attempt in 50:
		dice = throw_dice()
		total = dice.val6 + dice.val4
		if total == Global.ROLL_ANY_LOCATION:
			break
		destination = state.location_for_total(total)
		if destination != here:
			break
	turn.roll = dice
	MatchNet.dice_rolled.rpc(dice.val6, dice.val4)
	return {"total": total, "destination": destination}


func throw_dice() -> Dictionary:
	return {"val6": randi_range(1, 6), "val4": randi_range(1, 4)}


func choose_location(sender: int, location_id: String) -> void:
	if not is_current(sender) or turn.phase != TurnPhase.CHOOSE_LOCATION:
		return
	if location_id == state.players[sender].location or state.location_index(location_id) == -1:
		return
	_move_player(sender, location_id)


func _move_player(player_id: int, location_id: String) -> void:
	turn.phase = TurnPhase.ACTION
	turn.action_used = false
	move_pawn(player_id, location_id)
	set_step("location")
	var loc: Dictionary = state.locations[state.location_index(location_id)]
	tell(player_id, &"offer_location_action", [loc.action])


## Moves a pawn (turn moves and card effects like Shortcut).
func move_pawn(player_id: int, location_id: String) -> void:
	state.players[player_id].location = location_id
	MatchNet.move_pawn.rpc(player_id, location_id)


# --- Location actions ----------------------------------------------------------

func _location_action_of(player_id: int) -> String:
	var index := state.location_index(state.players[player_id].location)
	return state.locations[index].action if index != -1 else ""


func skip_action(sender: int) -> void:
	if is_current(sender) and turn.phase == TurnPhase.ACTION:
		_location_done()


## The location step is over (used or skipped): next, attack or end the turn.
func _location_done() -> void:
	turn.action_used = true
	if turn.step == "location":
		set_step("attack_or_end")


## Tell everyone which step of the turn we're at (the narrator's step strip,
## and what the turn player's buttons offer).
func set_step(step: String) -> void:
	turn.step = step
	MatchNet.turn_step.rpc(turn.player, step)


func draw(sender: int, card_type: String) -> void:
	if not can_act(sender):
		return
	if not card_type in Global.DRAW_ACTIONS.get(_location_action_of(sender), []):
		return
	_location_done()
	await cards.draw_for(sender, card_type)


## Magic Forest (heal 1 or deal 2) and Stone Circle (steal equipment).
func location_action(sender: int) -> void:
	if not can_act(sender):
		return
	var steps := []
	match _location_action_of(sender):
		"heal_or_damage":
			var mode = await ask(sender, Msg.make("prompt.magic_forest"), [
				{"value": "heal", "label": Msg.make("option.heal_1"), "color": "4fe0d0"},
				{"value": "damage", "label": Msg.make("option.deal_2"), "color": "e8402e"}])
			if mode == null:
				_location_done()  # skipped it after all
				return
			steps = [{"do": "heal", "amount": 1, "target": "chosen_any"}] if mode == "heal" \
				else [{"do": "damage", "amount": 2, "target": "chosen"}]
		"steal_equipment":
			steps = [{"do": "steal_equipment"}]
		_:
			return
	_location_done()
	var here: Dictionary = state.locations[state.location_index(state.players[sender].location)]
	await resolve({"name": here.label, "name_el": here.get("label_el", ""), "deck": "", "kind": "location",
		"effect": steps}, {"actor": sender})


## Runs a card effect while marking the game busy (no ending the turn meanwhile).
func resolve(card: Dictionary, ctx: Dictionary) -> void:
	busy_begin()
	await effects.run(card, ctx)
	busy_end()
	after_resolution()


# --- Questions, attacks, abilities: handled by the helpers ------------------------

func give_question(sender: int, target_id: int) -> void:
	cards.give_question(sender, target_id)

func answer_question(sender: int) -> void:
	await cards.answer_question(sender)

func attack(sender: int) -> void:
	await combat.attack(sender)

func reveal(sender: int) -> void:
	combat.request_reveal(sender)

func use_ability(sender: int) -> void:
	await combat.use_ability(sender)


# --- Choices ----------------------------------------------------------------------

func busy() -> bool:
	return _busy > 0 or not _awaiting.is_empty()


func busy_begin() -> void:
	_busy += 1


func busy_end() -> void:
	_busy -= 1


## Ask a player to pick one option; returns its value, or null if they skip.
## options: [{"value", "label", "color" (hex, optional)}]. Always `await` it.
## prompt and option labels are Msg dicts (or names): each screen shows
## them in its own language. `hint`: what the pick is for (e.g. a target to
## help or to hurt); only bots get it, it never goes over the network.
func ask(player_id: int, prompt: Dictionary, options: Array, allow_skip := true, hint := {}):
	return await _await_answer(player_id, options.map(func(o): return o.value), allow_skip, false,
		func():
			if bots.has(player_id):
				bots[player_id].on_choice(prompt, options, allow_skip, hint)
			else:
				MatchNet.present_choice.rpc_id(player_id, prompt, options, allow_skip))


## Wait until a player presses Roll (the dice by the campfire): dice throws
## are something players do, not something that happens to them.
func ask_roll(player_id: int, prompt: Dictionary) -> void:
	await _await_answer(player_id, ["roll"], false, true,
		func():
			if bots.has(player_id):
				bots[player_id].on_roll()
			else:
				MatchNet.prompt_roll.rpc_id(player_id, prompt))


func _await_answer(player_id: int, values: Array, allow_skip: bool, is_roll: bool, send: Callable):
	if _gone.has(player_id):  # left the match: answer for them (BUG-001)
		return null if allow_skip else values[0]
	var ask_id := _next_ask_id
	_next_ask_id += 1
	# Already asked something else (e.g. a kill's equipment pick that runs
	# alongside the rest of an attack): wait for that answer first, or the
	# first question would be overwritten and wait forever.
	while _awaiting.has(player_id):
		await choice_made
	if _gone.has(player_id):
		return null if allow_skip else values[0]
	_awaiting[player_id] = {"id": ask_id, "values": values, "skip": allow_skip, "roll": is_roll}
	send.call()
	_broadcast_waiting()
	# The answer may already be here (the host answers within the same call).
	while not _answers.has(ask_id):
		await choice_made
	var value = _answers[ask_id]
	_answers.erase(ask_id)
	return value


func choice(sender: int, value) -> void:
	if not _awaiting.has(sender):
		return
	var waiting: Dictionary = _awaiting[sender]
	if value == null and not waiting.skip:
		return
	if value != null and not value in waiting.values:
		return
	_awaiting.erase(sender)
	_answers[waiting.id] = value
	_broadcast_waiting()
	choice_made.emit(waiting.id)


## Tell everyone WHO is deciding something (not what), so screens can say
## "waiting for Bob…".
func _broadcast_waiting() -> void:
	MatchNet.waiting_for.rpc(_awaiting.keys())


## Pause for a moment (e.g. let dice land). Stops forever if the match is freed.
## In tests (Global.fast_mode) every pause is one frame.
func wait(seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(0.001 if Global.fast_mode else seconds)
	await timer.timeout
	timer.queue_free()


# --- Messages used by every helper -----------------------------------------------

## A Msg everyone sees as an announcement.
func notice(message: Dictionary) -> void:
	MatchNet.notice.rpc(message)


func private_info(player_id: int, title: Dictionary, text: Dictionary) -> void:
	tell(player_id, &"private_info", [title, text])


## A MatchNet message for ONE player only (secret info, prompts). Goes over
## the network to a person, or straight to a bot's seat (never rpc_id a bot
## id). Players who left get nothing.
func tell(player_id: int, method: StringName, args := []) -> void:
	if bots.has(player_id):
		bots[player_id].receive(method, args)
	elif not _gone.has(player_id):
		MatchNet.callv("rpc_id", [player_id, method] + args)


## A public event bots learn from (everyone saw it happen): `by` hurt or
## helped `to` ("harm" / "help"), or a question was answered.
func observe(event: String, by: int, to: int, amount := 0) -> void:
	for seat in bots.values():
		seat.observe(event, by, to, amount)


## A location's name, shown in each player's language.
func _location_name(location_id: String) -> Dictionary:
	var i := state.location_index(location_id)
	return Msg.named(state.locations[i]) if i != -1 else Msg.named({"name": "?"})


func player_option(id: int) -> Dictionary:
	var p: Dictionary = state.players[id]
	return {"value": id, "label": p.name, "color": Global.pawns.get(p.pawn, {}).get("hex", "ffffff")}


## Living players in turn order.
func alive() -> Array:
	return state.turn_order.filter(func(id): return not state.players[id].dead)
