class_name BotSeat extends RefCounted
## One bot player. Lives on the server inside the MatchServer (no computer,
## no connection). It plays through the same MatchServer entry points that a
## person's requests reach (roll, draw, attack, choice, end_turn...), and
## knows only what a person in its seat would (see BotMind):
##   - receive(): the private messages a person's screen would get, routed
##     here by MatchServer.tell() instead of an RPC;
##   - on_choice()/on_roll(): the server asking this seat something;
##   - observe(): public events (who hurt or helped whom, answered questions);
##   - take_turn(): its own turn, step by step.
## Everything waits on MatchServer.wait(), so freeing the match stops it.

var s: MatchServer
var id: int
var mind: BotMind
var brain: BotBrain
## The green card I hold or gave: {"card", "to", "before", "shown"}.
var _question := {}


## `level`: BotWeights.EASY / NORMAL / HARD (the lobby's "Bots" setting).
func _init(server: MatchServer, player_id: int, level := BotWeights.DEFAULT_LEVEL) -> void:
	s = server
	id = player_id
	var skill := BotWeights.level(level)
	mind = BotMind.new(s, id)
	mind.reads_hints = skill.hints
	brain = BotBrain.new(s, id, mind, skill)


## `-- --bot-log` on the server's command line prints what bots decide.
static var _logging: bool = "--bot-log" in OS.get_cmdline_user_args()


func _log(text: String) -> void:
	if _logging:
		var c := mind.own
		print("BOT %s (%s): %s" % [s.state.name_of(id), c.get("name", "?"), text])


## One line of what this bot believes about everyone (for the log).
func beliefs() -> String:
	var parts := []
	for other in s.alive():
		if other == id:
			continue
		var o := mind.species_odds(other)
		parts.append("%s v%.2f w%.2f h%.2f rel%+.2f" % [s.state.name_of(other), o.vampire, o.werewolf, o.human, mind.relation(other)])
	return " | ".join(parts)


func _think(extra := 0.0) -> void:
	await s.wait(randf_range(BotWeights.THINK_MIN, BotWeights.THINK_MAX) + extra)


func _alive() -> bool:
	return not s.finished and not s.state.players[id].dead


# --- What the server tells this seat ---------------------------------------------

## The private messages a person's screen would get (MatchServer.tell()).
func receive(method: StringName, args: Array) -> void:
	match method:
		&"set_character":
			mind.own = args[0]
		&"prompt_choose_location":
			_choose_location(args[0])
		&"question_drawn":
			_give_question(args[0])
		&"question_asked":
			_answer_question()
		&"private_character":
			mind.learn_character(args[0], args[1])
			if _question.get("to", 0) == args[0]:
				_question.shown = true
		&"private_info":
			var text: Dictionary = args[1] if args[1] is Dictionary else {}
			if text.get("k", "") == "info.starts_with_health" and _question.has("to"):
				mind.learn_health(_question.to, int(text.p.health))
		_:
			pass  # offer_location_action: take_turn() handles the action


## The server asks this seat to pick an option (MatchServer.ask()).
func on_choice(prompt: Dictionary, options: Array, allow_skip: bool, hint: Dictionary) -> void:
	await _think()
	var value = brain.choose(prompt.get("k", ""), options, allow_skip, hint)
	_log("%s -> %s" % [prompt.get("k", ""), s.state.name_of(value) if value is int else str(value)])
	s.choice(id, value)


## The server waits for this seat to throw the dice.
func on_roll() -> void:
	await _think()
	s.roll(id)


## A public event (MatchServer.observe()).
func observe(event: String, by: int, to: int, amount: int) -> void:
	if event == "question_answered":
		if by == id and _question.get("to", 0) == to:
			var p: Dictionary = s.state.players[to]
			mind.learn_from_question(_question.card, to, _question.before,
				{"dmg": p.dmg, "equipment": p.equipment.size()}, _question.get("shown", false))
			_question = {}
		return
	mind.observe(event, by, to, amount)


func _choose_location(options: Array) -> void:
	await _think()
	s.choose_location(id, brain.pick_location(options))


## Hand my green card to someone. Retries until the server takes it, so a
## card can never stay pending (and block the turn) because of a bot.
func _give_question(card: Dictionary) -> void:
	await _think()
	for attempt in 20:
		var q: Dictionary = s.turn.pending_question
		if s.finished or q.is_empty() or q.card.uid != card.uid or q.to != 0:
			return  # handed over (or gone)
		var target := brain.question_target(card)
		if target == 0:
			return
		var p: Dictionary = s.state.players[target]
		_question = {"card": card, "to": target, "before": {"dmg": p.dmg, "equipment": p.equipment.size()}}
		_log("gives %s to %s" % [card.id, p.name])
		s.give_question(id, target)
		await s.wait(0.5)


func _answer_question() -> void:
	await _think()
	s.answer_question(id)  # the server applies it truthfully


# --- My turn ------------------------------------------------------------------------

## Roll → (move) → location action → abilities → maybe attack → end turn.
## Each step waits until the server isn't busy (choices, dice, questions).
func take_turn() -> void:
	var serial: int = s.turn.count
	await _think(BotWeights.TURN_START)
	if not _my_turn(serial):
		return
	_log("turn, round %d. %s" % [s.state.round, beliefs()])
	await _ability(serial, "start")
	# Roll (again, if the server was busy and refused); a 7 or Old Map comes
	# back through receive() / on_choice().
	var rolled := false
	while _my_turn(serial) and s.turn.phase == MatchServer.TurnPhase.ROLL:
		if not s.busy() and not rolled:
			s.roll(id)
			rolled = s.turn.phase != MatchServer.TurnPhase.ROLL or s.busy()
		await s.wait(0.25)
	if not await _until(serial, func(): return s.turn.phase == MatchServer.TurnPhase.ACTION and not s.busy()):
		return
	await _think()
	if not _my_turn(serial):
		return
	_location_action()
	if not await _until_idle(serial):
		return
	await _ability(serial, "main")
	if not await _until_idle(serial):
		return
	if brain.wants_attack():
		await _ability(serial, "attack")
		if not await _until_idle(serial):
			return
		await _think()
		if _my_turn(serial) and brain.wants_attack():
			s.attack(id)
			if not await _until_idle(serial):
				return
	await _think()
	# Keep asking until the turn moves on: the server refuses while anything
	# (a choice, a dice throw, a green card) is still open.
	while _my_turn(serial):
		if not s.busy() and s.turn.pending_question.is_empty():
			s.end_turn(id)
		await s.wait(0.5)


func _my_turn(serial: int) -> bool:
	return _alive() and s.is_current(id) and s.turn.count == serial


## Waits until `ready` is true; false if my turn ended meanwhile (or I died).
func _until(serial: int, ready: Callable) -> bool:
	while _my_turn(serial):
		if ready.call():
			return true
		await s.wait(0.25)
	return false


func _until_idle(serial: int) -> bool:
	return await _until(serial, func(): return not s.busy() and s.turn.pending_question.is_empty())


func _location_action() -> void:
	var action := s._location_action_of(id)
	var decks: Array = Global.DRAW_ACTIONS.get(action, [])
	if not decks.is_empty():
		var deck := brain.pick_deck(decks)
		_log("draws %s" % deck)
		s.draw(id, deck)
	elif brain.wants_location_action(action):
		_log("uses %s" % action)
		s.location_action(id)
	else:
		_log("skips %s" % action)
		s.skip_action(id)


func _ability(serial: int, moment: String) -> void:
	if not _my_turn(serial):
		return
	match brain.ability_now(moment):
		"use":
			await _think()
			if _my_turn(serial) and not s.busy():
				_log("uses ability %s" % mind.own.ability_id)
				s.use_ability(id)
		"reveal":
			await _think()
			if _my_turn(serial):
				_log("reveals")
				s.reveal(id)
