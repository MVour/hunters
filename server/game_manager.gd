class_name GameManager extends Node
## Runs the match.
##
## Rules of the road:
## - Only the server (peer 1) decides anything. Functions starting with _
##   that change game state only run there.
## - Clients ask via request_* RPCs. The server checks WHO sent it with
##   Network.sender_id() (never trust an id passed as an argument).
## - The server tells peers what happened via "authority" RPCs.

enum TurnPhase { ROLL, CHOOSE_LOCATION, ACTION }

@onready var players_slots: PlayersSlots = $"../PlayersSlots"
@onready var dices_container: DiceManager = $"../DicesContainer"

var game_started := false
var game_finished := false

## Server only: peers that have finished loading the play scene.
var _loaded_peers := {}

var current_turn := {
	"turn_count": 0,
	"playing_id": 0,
	"phase": TurnPhase.ROLL,
	"roll": {"val6": 0, "val4": 0},
}


# --- Starting the match ------------------------------------------------------

## Every peer calls this once its play scene is ready. The server starts the
## match when all players have loaded, so no RPC hits a scene that isn't
## there yet.
@rpc("any_peer", "call_local", "reliable")
func report_loaded() -> void:
	if not multiplayer.is_server():
		return
	_loaded_peers[Network.sender_id()] = true
	if game_started:
		return
	for id in GameState.players:
		if not _loaded_peers.has(id):
			return
	_start_game()


func _start_game() -> void:
	game_started = true
	game_finished = false
	GameState.prepare_deck()
	_deal_characters()
	_send_decks()
	set_locations.rpc(GameState.locations)
	_decide_turn_order()
	players_slots.sit_players.rpc(GameState.game_info.players_turn)
	_start_turn()


## Deals each player a secret character. Only the owner is told which one.
func _deal_characters() -> void:
	var chosen := []
	for settings_key in Global.SPECIES:
		var list_name: String = Global.SPECIES[settings_key].list
		var count: int = GameState.game_settings[settings_key]
		chosen.append_array(GameState.deck.characters[list_name].slice(0, count))
	chosen.shuffle()

	if chosen.size() < GameState.players.size():
		push_error("Not enough characters for %d players (lobby should have blocked this)." % GameState.players.size())
		return

	var i := 0
	for id in GameState.players:
		GameState.players[id].character = chosen[i]
		set_character.rpc_id(id, chosen[i])
		i += 1


@rpc("authority", "call_local", "reliable")
func set_character(character: Dictionary) -> void:
	GameState.local_player.character = character
	SignalBus._set_character.emit(GameState.local_id, character)


## Clients only learn how many cards each deck has, not their order.
func _send_decks() -> void:
	for card_type in Global.CARD_TYPES:
		attach_deck.rpc(card_type, GameState.deck[card_type].size())


@rpc("authority", "call_local", "reliable")
func attach_deck(card_type: String, count: int) -> void:
	SignalBus._attach_deck.emit(card_type, count)


@rpc("authority", "call_local", "reliable")
func set_locations(locations: Array) -> void:
	GameState.locations = locations
	SignalBus.set_locations.emit(locations)


func _decide_turn_order() -> void:
	var order: Array = GameState.players.keys()
	order.shuffle()
	GameState.game_info.players_turn = order


# --- Turns -------------------------------------------------------------------

func _start_turn() -> void:
	if game_finished:
		return
	var order: Array = GameState.game_info.players_turn
	# Skip players who are out.
	var playing_id: int = order[current_turn.turn_count % order.size()]
	for i in order.size():
		if not GameState.players[playing_id].dead:
			break
		current_turn.turn_count += 1
		playing_id = order[current_turn.turn_count % order.size()]
	current_turn.turn_count += 1
	current_turn.playing_id = playing_id
	current_turn.phase = TurnPhase.ROLL
	current_turn.action_used = false
	current_turn.pending_question = {}
	current_turn.attacked = false
	@warning_ignore("integer_division")
	GameState.game_info.round = (current_turn.turn_count - 1) / order.size() + 1

	print("Starting turn %d (round %d), player %d" % [current_turn.turn_count, GameState.game_info.round, playing_id])
	players_lock.rpc(playing_id, true)
	_turn_start_effects(playing_id)


## Protection wears off; always-on equipment that acts each turn.
func _turn_start_effects(player_id: int) -> void:
	if GameState.players[player_id].get("protected", false):
		sync_protected.rpc(player_id, false)
	var m := effects.mods(player_id)
	if m.get("heal_per_turn", 0) > 0 and GameState.players[player_id].dmg > 0:
		heal(player_id, m.heal_per_turn)
		notice.rpc("%s's Healer's Satchel heals %d." % [GameState.players[player_id].name, m.heal_per_turn])
	if m.get("upkeep_damage", 0) > 0:
		notice.rpc("%s's Cursed Ring bites." % GameState.players[player_id].name)
		apply_damage(player_id, m.upkeep_damage)


## After an effect finishes: if the current player died meanwhile, move on.
func _after_resolution() -> void:
	if busy() or game_finished:
		return
	if GameState.players[current_turn.playing_id].dead:
		players_lock.rpc(current_turn.playing_id, false)
		_start_turn()


func _is_current_player(id: int) -> bool:
	return game_started and not game_finished and id == current_turn.playing_id


@rpc("any_peer", "call_local", "reliable")
func request_roll() -> void:
	if not multiplayer.is_server():
		return
	if not _is_current_player(Network.sender_id()) or current_turn.phase != TurnPhase.ROLL or busy():
		return

	var player_id: int = current_turn.playing_id
	var here: String = GameState.players[player_id].location
	var result := _roll_move(here)
	var total: int = result.total
	var destination: String = result.destination

	# Old Map: may roll a second time and pick either result.
	if total != Global.ROLL_ANY_LOCATION and effects.mods(player_id).get("reroll_move", false):
		_busy += 1
		var first_label := _location_label(destination)
		var again = await ask(player_id, "Old Map: go to %s, or roll again?" % first_label, [
			{"value": "keep", "label": "Go to %s" % first_label},
			{"value": "reroll", "label": "Roll again"}], false)
		if again == "reroll":
			await get_tree().create_timer(1.0).timeout  # let the first roll land
			var second := _roll_move(here)
			if second.total == Global.ROLL_ANY_LOCATION:
				total = second.total
			elif second.destination != destination:
				var pick = await ask(player_id, "Old Map: pick where you go", [
					{"value": destination, "label": first_label},
					{"value": second.destination, "label": _location_label(second.destination)}], false)
				destination = pick
		_busy -= 1

	if total == Global.ROLL_ANY_LOCATION:
		current_turn.phase = TurnPhase.CHOOSE_LOCATION
		var options := []
		for loc in GameState.locations:
			if loc.id != here:
				options.append(loc.id)
		prompt_choose_location.rpc_id(player_id, options)
	else:
		_move_player(player_id, destination)


## Rolls the dice (shown to everyone) until they point somewhere new.
## A 7 means "your choice".
func _roll_move(here: String) -> Dictionary:
	var roll := {}
	var total := 0
	var destination := ""
	for attempt in 50:
		roll = dices_container.throw_dices()
		total = roll.val6 + roll.val4
		if total == Global.ROLL_ANY_LOCATION:
			break
		destination = GameState.location_for_total(total)
		if destination != here:
			break
	current_turn.roll = roll
	dices_container.roll_dices.rpc(roll.val6, roll.val4)
	return {"total": total, "destination": destination}


func _location_label(location_id: String) -> String:
	var i := GameState.location_index(location_id)
	return GameState.locations[i].label if i != -1 else "?"


## Server -> the player who rolled a 7: pick a location.
@rpc("authority", "call_local", "reliable")
func prompt_choose_location(options: Array) -> void:
	SignalBus.choose_location.emit(options)


@rpc("any_peer", "call_local", "reliable")
func request_choose_location(location_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	if not _is_current_player(sender) or current_turn.phase != TurnPhase.CHOOSE_LOCATION:
		return
	if location_id == GameState.players[sender].location or GameState.location_index(location_id) == -1:
		return
	_move_player(sender, location_id)


func _move_player(player_id: int, location_id: String) -> void:
	current_turn.phase = TurnPhase.ACTION
	current_turn.action_used = false
	move_pawn.rpc(player_id, location_id)
	var loc: Dictionary = GameState.locations[GameState.location_index(location_id)]
	offer_location_action.rpc_id(player_id, loc.action)


# --- Location actions & drawing cards ----------------------------------------

## Which decks a location action lets you draw from.
const DRAW_ACTIONS := {
	"draw_green": ["green_cards"],
	"draw_red": ["red_cards"],
	"draw_blue": ["blue_cards"],
	"draw_any": ["green_cards", "red_cards", "blue_cards"],
}


## Server -> the player who just arrived: what this location offers.
@rpc("authority", "call_local", "reliable")
func offer_location_action(action: String) -> void:
	SignalBus.location_action_offered.emit(action)


func _location_action_of(player_id: int) -> String:
	var index := GameState.location_index(GameState.players[player_id].location)
	return GameState.locations[index].action if index != -1 else ""


@rpc("any_peer", "call_local", "reliable")
func request_skip_action() -> void:
	if multiplayer.is_server() and _is_current_player(Network.sender_id()):
		current_turn.action_used = true


func _can_act(sender: int) -> bool:
	return _is_current_player(sender) and current_turn.phase == TurnPhase.ACTION \
		and not current_turn.action_used and not busy()


@rpc("any_peer", "call_local", "reliable")
func request_draw(card_type: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	if not _can_act(sender):
		return
	if not card_type in DRAW_ACTIONS.get(_location_action_of(sender), []):
		return
	current_turn.action_used = true
	await draw_for(sender, card_type)


## Magic Forest (heal 1 or deal 2) and Stone Circle (steal equipment).
@rpc("any_peer", "call_local", "reliable")
func request_location_action() -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	if not _can_act(sender):
		return
	var action := _location_action_of(sender)
	var steps := []
	match action:
		"heal_or_damage":
			var mode = await ask(sender, "Magic Forest: heal or harm?", [
				{"value": "heal", "label": "Heal 1", "color": "4fe0d0"},
				{"value": "damage", "label": "Deal 2", "color": "e8402e"}])
			if mode == null:
				return
			steps = [{"do": "heal", "amount": 1, "target": "chosen_any"}] if mode == "heal" \
				else [{"do": "damage", "amount": 2, "target": "chosen"}]
		"steal_equipment":
			steps = [{"do": "steal_equipment"}]
		_:
			return
	current_turn.action_used = true
	var label: String = GameState.locations[GameState.location_index(GameState.players[sender].location)].label
	await _resolve({"name": label, "deck": "", "kind": "location", "effect": steps}, {"actor": sender})


## Server only. A player draws a card (location action, or a card effect).
func draw_for(player_id: int, card_type: String) -> void:
	var card := GameState.draw_card(card_type)
	if card.is_empty():
		return
	deck_count.rpc(card_type, GameState.deck[card_type].size())
	if card.kind == "question":
		# Green: secret. Only the drawer sees it, then picks who to ask.
		var waiting: Dictionary = current_turn.get("pending_question", {})
		if not waiting.is_empty():
			GameState.discard(waiting.card)  # never lose a card from the deck
		current_turn.pending_question = {"card": card, "from": player_id, "to": 0}
		question_drawn.rpc_id(player_id, card)
		card_drawn_secretly.rpc(player_id, card_type)
		return

	# Red/blue: read aloud. Everyone sees it.
	card_revealed.rpc(player_id, card)
	if card.kind == "equipment":
		GameState.players[player_id].equipment.append(card)
		set_equipment.rpc(player_id, GameState.players[player_id].equipment)
		return
	# Events: "must" ones happen; the others the player may decline.
	if not card.get("must", false):
		var use = await ask(player_id, "%s: use it now?" % card.name,
			[{"value": "use", "label": "Use it", "color": Global.CARD_COLORS[card.deck].color}])
		if use == null:
			GameState.discard(card)
			return
	await _resolve(card, {"actor": player_id})
	GameState.discard(card)


## Runs an effect while marking the game busy (no ending the turn meanwhile).
func _resolve(card: Dictionary, ctx: Dictionary) -> void:
	_busy += 1
	await effects.run(card, ctx)
	_busy -= 1
	_after_resolution()


# --- Choices, messages, equipment -------------------------------------------

signal choice_made(player_id: int, value)

var effects: CardEffects
var _busy := 0
var _awaiting := {}  # player id -> {"values": [...], "skip": bool}


func _ready() -> void:
	effects = CardEffects.new(self)


func busy() -> bool:
	return _busy > 0 or not _awaiting.is_empty()


## Server only. Ask a player to pick one option; returns its value, or null
## if they skip. options: [{"value", "label", "color" (hex, optional)}].
func ask(player_id: int, prompt: String, options: Array, allow_skip := true):
	_awaiting[player_id] = {"values": options.map(func(o): return o.value), "skip": allow_skip}
	present_choice.rpc_id(player_id, prompt, options, allow_skip)
	while true:
		var result: Array = await choice_made
		if result[0] == player_id:
			return result[1]
	return null


@rpc("authority", "call_local", "reliable")
func present_choice(prompt: String, options: Array, allow_skip: bool) -> void:
	SignalBus.choice_requested.emit(prompt, options, allow_skip)


@rpc("any_peer", "call_local", "reliable")
func request_choice(value) -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	if not _awaiting.has(sender):
		return
	var waiting: Dictionary = _awaiting[sender]
	if value == null and not waiting.skip:
		return
	if value != null and not value in waiting.values:
		return
	_awaiting.erase(sender)
	choice_made.emit(sender, value)


## Server -> everyone: a short public message.
@rpc("authority", "call_local", "reliable")
func notice(text: String) -> void:
	SignalBus.notice.emit(text)


## Server -> one player: something only they get to know.
@rpc("authority", "call_local", "reliable")
func private_info(title: String, text: String) -> void:
	SignalBus.private_info.emit(title, text)


## Server -> one player: a look at someone's character card.
@rpc("authority", "call_local", "reliable")
func private_character(player_id: int, character: Dictionary) -> void:
	SignalBus.private_character.emit(player_id, character)


@rpc("authority", "call_local", "reliable")
func set_equipment(player_id: int, equipment: Array) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].equipment = equipment
	SignalBus.equipment_changed.emit(player_id)


## Server only.
func transfer_equipment(from_id: int, to_id: int, uid) -> void:
	var from_list: Array = GameState.players[from_id].equipment
	for i in from_list.size():
		if from_list[i].uid == uid:
			var card: Dictionary = from_list.pop_at(i)
			GameState.players[to_id].equipment.append(card)
			set_equipment.rpc(from_id, from_list)
			set_equipment.rpc(to_id, GameState.players[to_id].equipment)
			notice.rpc("%s takes %s from %s" % [GameState.players[to_id].name, card.name, GameState.players[from_id].name])
			return


## Guardian Spirit: can't be attacked until their next turn.
func set_protected(player_id: int, on: bool) -> void:
	sync_protected.rpc(player_id, on)
	if on:
		notice.rpc("%s is protected until their next turn." % GameState.players[player_id].name)


@rpc("authority", "call_local", "reliable")
func sync_protected(player_id: int, on: bool) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].protected = on
	SignalBus.equipment_changed.emit(player_id)


@rpc("authority", "call_local", "reliable")
func deck_count(card_type: String, count: int) -> void:
	SignalBus.deck_count_changed.emit(card_type, count)


## Server -> the drawer of a green card.
@rpc("authority", "call_local", "reliable")
func question_drawn(card: Dictionary) -> void:
	SignalBus.question_drawn.emit(card)


## Server -> everyone: someone drew a card nobody else gets to see.
@rpc("authority", "call_local", "reliable")
func card_drawn_secretly(player_id: int, card_type: String) -> void:
	SignalBus.card_drawn_secretly.emit(player_id, card_type)


@rpc("authority", "call_local", "reliable")
func card_revealed(player_id: int, card: Dictionary) -> void:
	SignalBus.card_revealed.emit(player_id, card)


## The asker hands their green card to another player.
@rpc("any_peer", "call_local", "reliable")
func request_give_question(target_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	var q: Dictionary = current_turn.get("pending_question", {})
	if q.is_empty() or q.from != sender or q.to != 0:
		return
	if target_id == sender or not GameState.players.has(target_id) or GameState.players[target_id].dead:
		return
	q.to = target_id
	question_asked.rpc_id(target_id, sender, q.card)
	question_passed.rpc(sender, target_id)


## Server -> the player being asked.
@rpc("authority", "call_local", "reliable")
func question_asked(from_id: int, card: Dictionary) -> void:
	SignalBus.question_asked.emit(from_id, card)


## Server -> everyone: who asked whom (not what).
@rpc("authority", "call_local", "reliable")
func question_passed(from_id: int, to_id: int) -> void:
	SignalBus.question_passed.emit(from_id, to_id)


## The asked player has read the card; the server applies it.
@rpc("any_peer", "call_local", "reliable")
func request_answer_question() -> void:
	if not multiplayer.is_server():
		return
	var q: Dictionary = current_turn.get("pending_question", {})
	if q.is_empty() or q.to == 0 or Network.sender_id() != q.to or q.get("answering", false):
		return
	q.answering = true
	# The server knows everyone's species, so the answer is always truthful.
	await _resolve(q.card, {"actor": q.to, "receiver": q.to, "asker": q.from})
	GameState.discard(q.card)
	current_turn.pending_question = {}
	question_answered.rpc(q.from, q.to)
	_after_resolution()


@rpc("authority", "call_local", "reliable")
func question_answered(from_id: int, to_id: int) -> void:
	SignalBus.question_answered.emit(from_id, to_id)


## Server -> everyone: this player's pawn is now at this location.
@rpc("authority", "call_local", "reliable")
func move_pawn(player_id: int, location_id: String) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].location = location_id
	SignalBus.pawn_moved.emit(player_id, location_id)


@rpc("any_peer", "call_local", "reliable")
func request_end_turn() -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	# You have to move before you can end your turn, and an asked question
	# has to be answered first.
	if not _is_current_player(sender) or current_turn.phase != TurnPhase.ACTION:
		return
	if not current_turn.get("pending_question", {}).is_empty() or busy():
		return
	players_lock.rpc(sender, false)
	_start_turn()


@rpc("authority", "call_local", "reliable")
func players_lock(playing_id: int, val: bool) -> void:
	if GameState.players.has(playing_id):
		GameState.players[playing_id].playing = val

	if val:
		SignalBus.begin_turn.emit(playing_id)
	else:
		SignalBus.end_turn.emit(playing_id)


# --- Health ------------------------------------------------------------------
# Server only. Cards, locations and attacks all go through these.

func apply_damage(target_id: int, amount: int, source_id := 0) -> void:
	if not multiplayer.is_server() or not GameState.players.has(target_id):
		return
	var target: Dictionary = GameState.players[target_id]
	if target.dead or amount <= 0:
		return
	target.dmg = mini(target.dmg + amount, target.character.health)
	set_damage.rpc(target_id, target.dmg)
	if target.dmg >= target.character.health:
		_kill(target_id, source_id)


func heal(target_id: int, amount: int) -> void:
	if not multiplayer.is_server() or not GameState.players.has(target_id):
		return
	var target: Dictionary = GameState.players[target_id]
	if target.dead or amount <= 0:
		return
	target.dmg = maxi(0, target.dmg - amount)
	set_damage.rpc(target_id, target.dmg)


@rpc("authority", "call_local", "reliable")
func set_damage(player_id: int, damage: int) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].dmg = damage
	SignalBus.damage_changed.emit(player_id, damage)


## Out of health: the player is out and their card is revealed to everyone.
func _kill(player_id: int, killer_id: int) -> void:
	GameState.players[player_id].dead = true
	GameState.players[player_id].hidden = false
	reveal_character.rpc(player_id, GameState.players[player_id].character)
	player_died.rpc(player_id, killer_id)
	if killer_id != 0 and killer_id != player_id:
		var kills: Array = GameState.players[killer_id].get("kills", [])
		kills.append(GameState.players[player_id].character.species)
		GameState.players[killer_id].kills = kills
	if _check_win():
		return
	# The killer takes one of the dead player's equipment cards.
	if killer_id != 0 and killer_id != player_id and not GameState.players[player_id].equipment.is_empty() \
			and not GameState.players[killer_id].dead:
		_busy += 1
		var uid = await effects._pick_equipment(killer_id, player_id,
			"You killed %s! Take one of their equipment cards." % GameState.players[player_id].name, false)
		transfer_equipment(player_id, killer_id, uid)
		_busy -= 1
	_after_resolution()


## Makes a character public (on death, or when a player reveals it).
@rpc("authority", "call_local", "reliable")
func reveal_character(player_id: int, character: Dictionary) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].character = character
		GameState.players[player_id].hidden = false
	SignalBus.character_revealed.emit(player_id, character)


@rpc("authority", "call_local", "reliable")
func player_died(player_id: int, killer_id: int) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].dead = true
	SignalBus.player_died.emit(player_id, killer_id)


# --- Attacks -----------------------------------------------------------------

## Who `attacker` may attack right now.
func attack_targets(attacker: int) -> Array:
	return effects.alive().filter(func(id):
		return id != attacker and effects.in_reach(attacker, id) \
			and not GameState.players[id].get("protected", false))


@rpc("any_peer", "call_local", "reliable")
func request_attack() -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	if not _is_current_player(sender) or current_turn.phase != TurnPhase.ACTION \
			or current_turn.get("attacked", false) or busy():
		return
	var targets := attack_targets(sender)
	if targets.is_empty():
		private_info.rpc_id(sender, "Attack  ·  Επίθεση", "Nobody is within reach.")
		return
	_busy += 1
	var target = await ask(sender, "Attack whom?  ·  Σε ποιον επιτίθεσαι;", targets.map(effects._player_option))
	if target != null:
		current_turn.attacked = true
		await _attack(sender, target, true)
	_busy -= 1
	_after_resolution()


## Roll both dice: the difference is the damage, adjusted by equipment and
## abilities. `allow_counter` lets the target strike back (Mel).
func _attack(attacker: int, target: int, allow_counter: bool) -> void:
	var a: Dictionary = GameState.players[attacker]
	var character: Dictionary = a.character
	var mode := "d6" if effects.mods(attacker).get("d6_attack", false) else "difference"

	# Frederick / Gregor: once per game, the damage is one die alone.
	if character.get("timing", "") == "attack" and not a.get("ability_used", false):
		var die := "6" if character.ability_id == "d6_attack" else "4"
		var reveal_note := "\n(This reveals your character.)" if a.hidden else ""
		var use = await ask(attacker, "%s: use your ability (damage = the d%s alone)?%s" % [character.name, die, reveal_note],
			[{"value": "use", "label": "Use ability", "color": "c8a85a"}], true)
		if use == "use":
			_mark_ability_used(attacker)
			mode = "d" + die

	var roll := dices_container.throw_dices()
	dices_container.roll_dices.rpc(roll.val6, roll.val4)
	await get_tree().create_timer(0.8).timeout

	var dmg := absi(roll.val6 - roll.val4)
	match mode:
		"d6":
			dmg = roll.val6
		"d4":
			dmg = roll.val4
	if dmg > 0:
		dmg += effects.mods(attacker).get("attack_bonus", 0)
		if character.get("ability_id", "") == "savage" and not a.hidden:
			dmg += 1
	var tm := effects.mods(target)
	if dmg > 0:
		dmg = maxi(0, dmg - tm.get("damage_reduction", 0))
		if tm.has("max_attack_damage"):
			dmg = mini(dmg, tm.max_attack_damage)

	var t: Dictionary = GameState.players[target]
	notice.rpc("%s attacks %s: rolled %d and %d → %d damage" % [a.name, t.name, roll.val6, roll.val4, dmg])
	attack_fx.rpc(attacker, target, dmg)
	apply_damage(target, dmg, attacker)

	if tm.get("thorns", 0) > 0 and not a.dead:
		notice.rpc("%s's Rusty Bear Trap snaps!" % t.name)
		apply_damage(attacker, tm.thorns, target)
	if dmg > 0 and character.get("ability_id", "") == "lifesteal" and not a.hidden and not a.dead:
		heal(attacker, 2)
		notice.rpc("%s drinks: heals 2." % a.name)

	# Mel: strike back (not against the attack that killed her).
	if allow_counter and not t.dead and not a.dead and not game_finished \
			and t.character.get("ability_id", "") == "strike_back":
		var reveal_note := "\n(This reveals your character.)" if t.hidden else ""
		var back = await ask(target, "%s attacked you. Strike back?%s" % [a.name, reveal_note],
			[{"value": "yes", "label": "Strike back", "color": "e8402e"}], true)
		if back == "yes":
			if t.hidden:
				_reveal(target)
			await _attack(target, attacker, false)


## Everyone: play the attack animation.
@rpc("authority", "call_local", "reliable")
func attack_fx(attacker: int, target: int, damage: int) -> void:
	SignalBus.attack_happened.emit(attacker, target, damage)


# --- Revealing & abilities ---------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_reveal() -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	var p: Dictionary = GameState.players.get(sender, {})
	if p.is_empty() or p.dead or not p.hidden:
		return
	_reveal(sender)


func _reveal(player_id: int) -> void:
	var p: Dictionary = GameState.players[player_id]
	p.hidden = false
	reveal_character.rpc(player_id, p.character)
	notice.rpc("%s reveals: %s the %s!" % [p.name, p.character.name, p.character.species])


func _mark_ability_used(player_id: int) -> void:
	GameState.players[player_id].ability_used = true
	if GameState.players[player_id].hidden:
		_reveal(player_id)
	ability_used.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func ability_used(player_id: int) -> void:
	if GameState.players.has(player_id):
		GameState.players[player_id].ability_used = true
	SignalBus.ability_used.emit(player_id)


## The HUD's Use Ability button.
@rpc("any_peer", "call_local", "reliable")
func request_ability() -> void:
	if not multiplayer.is_server():
		return
	var sender := Network.sender_id()
	var p: Dictionary = GameState.players.get(sender, {})
	if p.is_empty() or p.dead or busy() or game_finished:
		return
	var character: Dictionary = p.character
	match character.get("timing", ""):
		"passive":
			if p.hidden:
				_reveal(sender)  # passive abilities work once you're revealed
			return
		"attack":
			private_info.rpc_id(sender, character.name, "You'll be offered your ability when you attack.")
			return
		"reactive":
			private_info.rpc_id(sender, character.name, "You'll be offered your ability when you're attacked.")
			return
	if p.get("ability_used", false):
		private_info.rpc_id(sender, character.name, "You've already used your ability.")
		return
	if character.ability_id != "switch_side" and not _is_current_player(sender):
		private_info.rpc_id(sender, character.name, "You can only use this on your turn.")
		return

	_busy += 1
	var completed := true
	match character.ability_id:
		"full_heal":
			heal(sender, p.dmg)
		"switch_side":
			p.hope_side = "left"
			private_info.rpc_id(sender, character.name, "You now back the player on your LEFT.")
		"peek":
			completed = await effects.run({"name": character.name, "effect": [{"do": "peek_character"}]}, {"actor": sender})
		"heal_other":
			completed = await effects.run({"name": character.name,
				"effect": [{"do": "heal", "amount": 3, "target": "chosen_any"}]}, {"actor": sender})
		"drain":
			completed = await effects.run({"name": character.name, "effect": [
				{"do": "damage", "amount": 1, "target": "chosen_in_reach"},
				{"do": "heal", "amount": 1, "target": "self"}]}, {"actor": sender})
	if completed:
		_mark_ability_used(sender)
	_busy -= 1
	_after_resolution()


# --- Winning -----------------------------------------------------------------

## Ends the game when one side is wiped out. Returns true if it ended.
func _check_win() -> bool:
	if game_finished:
		return true
	var total := {"vampire": 0, "werewolf": 0}
	var alive := {"vampire": 0, "werewolf": 0}
	for p in GameState.players.values():
		var s: String = p.character.get("species", "")
		if total.has(s):
			total[s] += 1
			if not p.dead:
				alive[s] += 1
	var faction := ""
	if total.werewolf > 0 and alive.werewolf == 0:
		faction = "vampire"
	if total.vampire > 0 and alive.vampire == 0:
		faction = "werewolf" if faction == "" else "none"  # both gone at once
	if faction == "":
		return false

	game_finished = true
	var winners := []
	for id in GameState.players:
		if _goal_met(id, alive, []):
			winners.append(id)
	var characters := {}
	for id in GameState.players:
		characters[id] = GameState.players[id].character
	game_over.rpc(faction, winners, characters)
	return true


func _goal_met(id: int, alive: Dictionary, visited: Array) -> bool:
	var p: Dictionary = GameState.players[id]
	match p.character.get("goal_id", ""):
		"no_werewolves":
			return alive.werewolf == 0
		"no_vampires":
			return alive.vampire == 0
		"survive":
			return not p.dead
		"hunter":
			var kills: Array = p.get("kills", [])
			return "vampire" in kills or "werewolf" in kills
		"neighbour_wins":
			# Right = the player after you in turn order; left = before you.
			var order: Array = GameState.game_info.players_turn
			var step := -1 if p.get("hope_side", "right") == "left" else 1
			var neighbour: int = order[(order.find(id) + step + order.size()) % order.size()]
			if neighbour == id or neighbour in visited:
				return false
			return _goal_met(neighbour, alive, visited + [id])
	return false


@rpc("authority", "call_local", "reliable")
func game_over(faction: String, winners: Array, characters: Dictionary) -> void:
	game_finished = true
	for id in characters:
		if GameState.players.has(id):
			GameState.players[id].character = characters[id]
			GameState.players[id].hidden = false
	SignalBus.game_over.emit(faction, winners)
