class_name BotMind extends RefCounted
## What one bot believes about the other players. Server only, part of a
## BotSeat. It is fed ONLY what a person in that seat could know: public
## info (locations, damage, equipment, revealed cards, who attacked or
## healed whom) and what the server tells that seat privately (its own
## character, peeks, question results). It never reads a hidden character
## from ServerState.
##
## For each other player it keeps how likely each species is:
##   prior    = the characters still unaccounted for, per species
##   x hard   = species ruled out (question results, starting health)
##   x lean   = soft evidence (who hits / helps whom), capped
## and turns that into a relation (-1 enemy .. +1 friend) for its own goal.

const SPECIES := ["vampire", "werewolf", "human"]

var s: MatchServer
var me: int
var own := {}         # my character
var _known := {}      # id -> character learnt privately (peek, mirror)
var _ruled_out := {}  # id -> {species: true}
var _health := {}     # id -> starting health they told me
var _lean := {}       # id -> {species: multiplier}
var _grudge := {}     # id -> damage they did to me
var _thanks := {}     # id -> healing they gave me
## Learn from how others behave (who hits / helps whom)? Off for easy bots.
var reads_hints := true


func _init(server: MatchServer, my_id: int) -> void:
	s = server
	me = my_id


# --- Learning --------------------------------------------------------------------

func learn_character(player_id: int, character: Dictionary) -> void:
	if player_id != me:
		_known[player_id] = character


func learn_health(player_id: int, health: int) -> void:
	_health[player_id] = health


func rule_out(player_id: int, species: String) -> void:
	if not _ruled_out.has(player_id):
		_ruled_out[player_id] = {}
	_ruled_out[player_id][species] = true


## A green card I gave was answered. `before`/`after`: the receiver's public
## damage and equipment count; `shown`: whether they showed me their card.
## Whichever species would NOT have produced what happened is ruled out.
func learn_from_question(card: Dictionary, receiver: int, before: Dictionary, after: Dictionary, shown: bool) -> void:
	if character_of(receiver).size() > 0:
		return  # already known
	var observed := {"dmg": after.dmg - before.dmg, "equipment": after.equipment - before.equipment, "shown": shown}
	for sp in SPECIES:
		var expect := _expected_question_result(card, sp, before)
		if expect != observed:
			rule_out(receiver, sp)


## What a question card would visibly do to a receiver of species `sp`.
## (Damage stops at a character's health, but a kill reveals them anyway.)
func _expected_question_result(card: Dictionary, sp: String, before: Dictionary) -> Dictionary:
	var result := {"dmg": 0, "equipment": 0, "shown": false}
	for step in card.get("effect", []):
		if step.has("if_species") and not sp in step.if_species:
			continue
		if step.has("unless_species") and sp in step.unless_species:
			continue
		match step.do:
			"damage":
				result.dmg += step.amount
			"heal":
				result.dmg -= mini(step.amount, before.dmg + result.dmg)
			"give_equipment_or_damage":
				if before.equipment > 0:
					result.equipment -= 1
				else:
					result.dmg += step.amount
			"show_character_to_asker":
				result.shown = true
	return result


## Public event: `by` hurt (attack, card) or helped (heal) `to`.
func observe(event: String, by: int, to: int, amount: int) -> void:
	if by == me or by == 0 or by == to:
		return
	if not reads_hints:  # easy bots: only cards and reveals teach them
		return
	if to == me:
		var mine: String = own.get("species", "")
		if event == "harm":
			_grudge[by] = _grudge.get(by, 0) + maxi(amount, 1)
			_push(by, _enemies_of(mine), BotWeights.HIT_ME_ENEMY)
			_push(by, [mine], BotWeights.HIT_ME_FRIEND)
		elif event == "help":
			_thanks[by] = _thanks.get(by, 0) + amount
			_push(by, [mine], BotWeights.HELP_FRIEND)
		return
	# Someone else was the target: only telling if their side is fairly clear.
	var side := clear_species(to)
	if side == "" or side == "human":
		return
	if event == "harm":
		_push(by, _enemies_of(side), BotWeights.HIT_OTHER_ENEMY)
		_push(by, [side], BotWeights.HIT_OTHER_FRIEND)
	elif event == "help":
		_push(by, [side], BotWeights.HELP_FRIEND)
		_push(by, _enemies_of(side), BotWeights.HELP_ENEMY)


func _push(player_id: int, species_list: Array, factor: float) -> void:
	if not _lean.has(player_id):
		_lean[player_id] = {"vampire": 1.0, "werewolf": 1.0, "human": 1.0}
	for sp in species_list:
		_lean[player_id][sp] = clampf(_lean[player_id][sp] * factor, BotWeights.LEAN_MIN, BotWeights.LEAN_MAX)


static func _enemies_of(species: String) -> Array:
	match species:
		"vampire":
			return ["werewolf"]
		"werewolf":
			return ["vampire"]
	return []


# --- Beliefs ----------------------------------------------------------------------

## A character this bot is allowed to know ({} if not): its own, a revealed
## one (public), or one it saw privately.
func character_of(player_id: int) -> Dictionary:
	if player_id == me:
		return own
	var p: Dictionary = s.state.players.get(player_id, {})
	if not p.is_empty() and not p.hidden:
		return p.character
	return _known.get(player_id, {})


## Characters not yet accounted for, per species (what the unknown players
## could be). Only counts as many of each species as the match deals.
func _unknown_characters() -> Dictionary:
	var taken := {}
	var known_count := {"vampire": 0, "werewolf": 0, "human": 0}
	for id in s.state.players:
		var c := character_of(id)
		if not c.is_empty():
			taken[c.id] = true
			known_count[c.species] += 1
	var result := {}
	for key in Global.SPECIES:
		var sp: String = Global.SPECIES[key].species
		var dealt: int = s.state.settings.get(key, 0)
		var pool: Array = Global.deck.characters[Global.SPECIES[key].list].filter(func(c): return not taken.has(c.id))
		result[sp] = {"slots": maxi(0, dealt - known_count[sp]), "pool": pool}
	return result


## How likely each species is for this player: {"vampire": p, ...}, sums to 1.
func species_odds(player_id: int) -> Dictionary:
	var c := character_of(player_id)
	if not c.is_empty():
		var sure := {"vampire": 0.0, "werewolf": 0.0, "human": 0.0}
		sure[c.species] = 1.0
		return sure
	var unknown := _unknown_characters()
	var odds := {}
	var total := 0.0
	for sp in SPECIES:
		var w: float = unknown[sp].slots
		if _ruled_out.get(player_id, {}).has(sp):
			w = 0.0
		if w > 0.0 and _health.has(player_id):
			if not unknown[sp].pool.any(func(ch): return ch.health == _health[player_id]):
				w = 0.0
		w *= _lean.get(player_id, {}).get(sp, 1.0)
		odds[sp] = w
		total += w
	if total <= 0.0:  # contradictory evidence: fall back to the plain counts
		for sp in SPECIES:
			odds[sp] = float(unknown[sp].slots)
			total += odds[sp]
	for sp in SPECIES:
		odds[sp] = odds[sp] / total if total > 0.0 else 1.0 / 3.0
	return odds


## The species this player most likely is, if it's fairly clear ("" if not).
func clear_species(player_id: int) -> String:
	var odds := species_odds(player_id)
	for sp in SPECIES:
		if odds[sp] >= BotWeights.CLEAR_SIDE:
			return sp
	return ""


## How unsure the bot is about this player: 0 (known) .. ~1.1 (no idea).
func uncertainty(player_id: int) -> float:
	var h := 0.0
	for p in species_odds(player_id).values():
		if p > 0.0:
			h -= p * log(p)
	return h


## Expected starting health (exact if the character is known).
func health_of(player_id: int) -> float:
	var c := character_of(player_id)
	if not c.is_empty():
		return float(c.health)
	if _health.has(player_id):
		return float(_health[player_id])
	var unknown := _unknown_characters()
	var odds := species_odds(player_id)
	var expected := 0.0
	for sp in SPECIES:
		var pool: Array = unknown[sp].pool
		if pool.is_empty() or odds[sp] == 0.0:
			continue
		var avg := 0.0
		for ch in pool:
			avg += ch.health
		expected += odds[sp] * avg / pool.size()
	return expected if expected > 0.0 else 11.0


func health_left(player_id: int) -> float:
	return health_of(player_id) - s.state.players[player_id].dmg


## -1 (enemy) .. +1 (friend), for this bot's own goal.
func relation(player_id: int) -> float:
	if player_id == me:
		return 1.0
	var r := _goal_relation(own, player_id, [])
	r -= minf(BotWeights.GRUDGE_MAX, BotWeights.GRUDGE_PER_DAMAGE * _grudge.get(player_id, 0))
	r += minf(BotWeights.THANKS_MAX, BotWeights.THANKS_PER_HEAL * _thanks.get(player_id, 0))
	return clampf(r, -1.0, 1.0)


## How someone with `character`'s goal feels about `other`, by species odds.
func _goal_relation(character: Dictionary, other: int, visited: Array) -> float:
	var odds := species_odds(other)
	match character.get("goal_id", ""):
		"no_werewolves":
			return odds.vampire - odds.werewolf
		"no_vampires":
			return odds.werewolf - odds.vampire
		"hunter":
			return 0.3 * odds.human - 0.7 * (odds.vampire + odds.werewolf)
		"survive":
			return 0.2 * odds.human
		"neighbour_wins":
			var backed := backed_player()
			if other == backed:
				return 1.0
			if backed == 0 or backed in visited:
				return 0.0
			# Side with whatever the backed player's side would want.
			var b_odds := species_odds(backed)
			var b_char := character_of(backed)
			if not b_char.is_empty():
				return _goal_relation(b_char, other, visited + [me])
			var o := species_odds(other)
			return b_odds.vampire * (o.vampire - o.werewolf) + b_odds.werewolf * (o.werewolf - o.vampire)
	return 0.0


## Hope: the player whose win is hers (right = plays after her).
func backed_player() -> int:
	var order: Array = s.state.turn_order
	if order.is_empty() or not me in order:
		return 0
	var step := -1 if s.state.players[me].get("hope_side", "right") == "left" else 1
	return order[(order.find(me) + step + order.size()) % order.size()]
