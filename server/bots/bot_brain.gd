class_name BotBrain extends RefCounted
## A bot's decisions. Server only, part of a BotSeat. Every choice point
## scores its legal options with weighted factors (BotWeights) and takes the
## best, with a little noise so bots aren't predictable. Beliefs come from
## the BotMind; everything else it reads is public (locations, damage,
## equipment, who's dead or protected).

## Tiny random tie-breaker added to every score.
const NOISE := 0.05

var s: MatchServer
var me: int
var mind: BotMind


func _init(server: MatchServer, my_id: int, bot_mind: BotMind) -> void:
	s = server
	me = my_id
	mind = bot_mind


# --- Helpers ----------------------------------------------------------------------

func _p(id: int) -> Dictionary:
	return s.state.players[id]


func _goal() -> String:
	return mind.own.get("goal_id", "")


func _is_fighter() -> bool:
	return _goal() in ["no_werewolves", "no_vampires", "hunter"]


func _others_alive() -> Array:
	return s.alive().filter(func(id): return id != me)


func _enmity(id: int) -> float:
	return -mind.relation(id)


func _noise() -> float:
	return randf() * NOISE


## The option whose value scores highest. `score` takes an option's value.
func _best(options: Array, score: Callable) -> Dictionary:
	var best := {"value": null, "score": -INF}
	var best_score := -INF
	for o in options:
		var sc: float = score.call(o.value) + _noise()
		if sc > best_score:
			best_score = sc
			best = {"value": o.value, "score": sc}
	return best


## Expected damage of my normal attack on `target`.
func _attack_damage(target: int) -> float:
	var m := Rules.mods(_p(me))
	var dmg := 3.5 if m.get("d6_attack", false) else 1.83  # E|d6 - d4| = 44/24
	dmg += m.get("attack_bonus", 0)
	if mind.own.get("ability_id", "") == "savage" and not _p(me).hidden:
		dmg += 1.0
	var tm := Rules.mods(_p(target))
	dmg = maxf(0.0, dmg - tm.get("damage_reduction", 0))
	if tm.has("max_attack_damage"):
		dmg = minf(dmg, tm.max_attack_damage)
	return dmg


# --- Attacking --------------------------------------------------------------------

func attack_score(target: int) -> float:
	var relation := mind.relation(target)
	if relation > BotWeights.NEVER_ATTACK_ABOVE:
		return -1.0
	var score := -relation
	score += BotWeights.AGGRESSION.get(_goal(), 0.0) + BotWeights.AGGRESSION_PER_ROUND * s.state.round
	var enmity := maxf(0.0, -relation)
	if mind.health_left(target) <= _attack_damage(target) + 1.0:
		score += BotWeights.KILL_BONUS * enmity
		if _goal() == "hunter":
			var odds := mind.species_odds(target)
			score += BotWeights.HUNTER_KILL_BONUS * (odds.vampire + odds.werewolf)
	return score


## Should I attack this turn? (The target is chosen when the server asks.)
func wants_attack() -> bool:
	var targets := s.combat.attack_targets(me)
	for t in targets:
		if attack_score(t) > BotWeights.ATTACK_THRESHOLD:
			return true
	return false


# --- Moving & location actions ----------------------------------------------------

func deck_value(card_type: String) -> float:
	var v: float = BotWeights.DECK_VALUE.get(card_type, 0.3)
	match card_type:
		"green_cards":
			var unknown := 0.0
			for id in _others_alive():
				unknown += mind.uncertainty(id)
			v += BotWeights.GREEN_PER_UNKNOWN * unknown / maxf(1.0, _others_alive().size())
		"red_cards":
			if _is_fighter():
				v += BotWeights.RED_FIGHTER_BONUS
		"blue_cards":
			v += BotWeights.BLUE_PER_DAMAGE * _p(me).dmg
	return v


func pick_deck(decks: Array) -> String:
	var best := ""
	var best_v := -INF
	for d in decks:
		var v := deck_value(d) + _noise()
		if v > best_v:
			best_v = v
			best = d
	return best


func action_value(action: String) -> float:
	match action:
		"draw_green", "draw_red", "draw_blue", "draw_any":
			var best := 0.0
			for d in Global.DRAW_ACTIONS[action]:
				best = maxf(best, deck_value(d))
			return best + (0.1 if action == "draw_any" else 0.0)
		"heal_or_damage":
			return BotWeights.MAGIC_FOREST_BASE + (0.5 if magic_forest_mode() != "" else 0.0) \
				+ 0.1 * _p(me).dmg
		"steal_equipment":
			return BotWeights.STEAL_BASE if not _steal_victims().is_empty() else 0.0
	return 0.0


## How good it is to stand at `location_id` (action + who's around).
func location_score(location_id: String) -> float:
	var i := s.state.location_index(location_id)
	if i == -1:
		return -INF
	var score := action_value(s.state.locations[i].action)
	var next := s.state.next_location(location_id)
	var prev := ""
	for loc in s.state.locations:
		if s.state.next_location(loc.id) == location_id:
			prev = loc.id
	var best_target := 0.0
	var threat := 0.0
	for id in _others_alive():
		var loc: String = _p(id).location
		var enmity := maxf(0.0, _enmity(id))
		if loc == location_id or loc == next:
			best_target = maxf(best_target, enmity)
		if loc == location_id or loc == prev:
			threat += enmity
	if _is_fighter():
		score += BotWeights.REACH_ENEMY * best_target
	else:
		score -= BotWeights.AVOID_ENEMY * threat
	return score


func pick_location(options: Array) -> String:
	var best := ""
	var best_v := -INF
	for loc in options:
		var v := location_score(loc) + _noise()
		if v > best_v:
			best_v = v
			best = loc
	return best


## Magic Forest: "heal", "damage", or "" (skip).
func magic_forest_mode() -> String:
	if _p(me).dmg >= 2:
		return "heal"
	for id in _others_alive():
		if mind.relation(id) > 0.4 and _p(id).dmg >= 2:
			return "heal"
	for id in _others_alive():
		if _enmity(id) > 0.25:
			return "damage"
	if _p(me).dmg > 0:
		return "heal"
	return ""


func _steal_victims() -> Array:
	return _others_alive().filter(func(id): return not _p(id).equipment.is_empty() and mind.relation(id) < 0.3)


func wants_location_action(action: String) -> bool:
	match action:
		"heal_or_damage":
			return magic_forest_mode() != ""
		"steal_equipment":
			return not _steal_victims().is_empty()
	return false


# --- Equipment --------------------------------------------------------------------

## How much an equipment card is worth to me.
func equipment_value(card: Dictionary) -> float:
	var m: Dictionary = card.get("mods", {})
	var v := 0.5
	v += 0.6 * m.get("attack_bonus", 0) * (1.0 if _is_fighter() else 0.4)
	v += 0.8 * m.get("damage_reduction", 0)
	v += 0.6 * m.get("heal_per_turn", 0)
	v -= 0.9 * m.get("upkeep_damage", 0)
	v += 0.4 * m.get("thorns", 0)
	if m.get("ignore_reach", false) or m.get("reach_back", false) or m.get("d6_attack", false):
		v += 0.5 if _is_fighter() else 0.1
	if m.has("max_attack_damage") or m.get("immune_red_events", false):
		v += 0.4
	return v


func _card_by_uid(uid) -> Dictionary:
	for p in s.state.players.values():
		for card in p.equipment:
			if card.uid == uid:
				return card
	return {}


# --- Questions --------------------------------------------------------------------

## Who gets my green card: whoever I learn most about, or hurt the right way.
func question_target(card: Dictionary) -> int:
	var best := 0
	var best_v := -INF
	for id in _others_alive():
		var odds := mind.species_odds(id)
		var v := BotWeights.QUESTION_INFO * mind.uncertainty(id)
		for step in card.get("effect", []):
			var chance := 0.0
			for sp in BotMind.SPECIES:
				if step.has("if_species") and not sp in step.if_species:
					continue
				if step.has("unless_species") and sp in step.unless_species:
					continue
				chance += odds[sp]
			match step.do:
				"damage", "give_equipment_or_damage":
					v += BotWeights.QUESTION_HARM * chance * step.get("amount", 1) * _enmity(id)
				"heal":
					v -= BotWeights.QUESTION_HARM * chance * step.amount * _enmity(id)
		v += _noise()
		if v > best_v:
			best_v = v
			best = id
	return best


# --- Cards --------------------------------------------------------------------------

## Should I play this optional event card now?
func card_worth_using(card: Dictionary) -> bool:
	var worth := 0.0
	for step in card.get("effect", []):
		match step.do:
			"damage":
				match step.get("target", "self"):
					"self":
						worth -= 0.4 * step.amount if mind.health_left(me) > step.amount + 2 else 2.0 * step.amount
					"chosen", "chosen_in_reach":
						var pool := _others_alive()
						if step.target == "chosen_in_reach":
							pool = pool.filter(func(id): return s.effects.in_reach(me, id))
						var best := 0.0
						for id in pool:
							best = maxf(best, _enmity(id))
						worth += best * step.amount - 0.1
					_:
						worth += 0.1
			"heal":
				match step.get("target", "self"):
					"self":
						worth += 0.5 if _p(me).dmg > 0 else 0.0
					"here":
						for id in s.alive():
							if _p(id).location == _p(me).location and _p(id).dmg > 0:
								worth += 0.3 * mind.relation(id)
					_:
						worth += 0.3
			"steal_equipment", "take_from_dead":
				worth += 0.5
			"move_anywhere":
				var here: String = _p(me).location
				var best_elsewhere := -INF
				for loc in s.state.locations:
					if loc.id != here:
						best_elsewhere = maxf(best_elsewhere, location_score(loc.id))
				worth += 0.3 if best_elsewhere > location_score(here) else -0.3
			"peek_character", "draw_any":
				worth += 0.5
			"give_equipment_and_heal":
				var friend := _others_alive().any(func(id): return mind.relation(id) > 0.3)
				worth += 0.4 if friend and not _p(me).equipment.is_empty() else -1.0
	return worth > 0.0


# --- Abilities ----------------------------------------------------------------------

## The HUD's ability button at this point of my turn: "use", "reveal" or "".
func ability_now(moment: String) -> String:
	var c := mind.own
	var p := _p(me)
	if p.dead or c.is_empty():
		return ""
	if c.timing == "passive":
		if p.hidden and moment == "attack" and s.state.round >= BotWeights.REVEAL_PASSIVE_ROUND:
			return "reveal"
		return ""
	if c.timing != "once" or p.get("ability_used", false):
		return ""
	match c.ability_id:
		"full_heal":
			if p.dmg >= BotWeights.FULL_HEAL_AT and moment == "start":
				return "use"
		"heal_other":
			if moment == "main":
				if p.dmg >= BotWeights.HEAL_OTHER_AT:
					return "use"
				for id in _others_alive():
					if mind.relation(id) > 0.4 and _p(id).dmg >= BotWeights.HEAL_OTHER_AT:
						return "use"
		"peek":
			if moment == "main" and s.state.round >= BotWeights.PEEK_ROUND \
					and _others_alive().any(func(id): return mind.uncertainty(id) > 0.3):
				return "use"
		"drain":
			# It reveals her: only on a clear enemy, or a likely one later on.
			if moment == "main":
				for id in _others_alive():
					var enmity := _enmity(id)
					if s.effects.in_reach(me, id) and (enmity > 0.6 \
							or (enmity > 0.3 and s.state.round >= BotWeights.DRAIN_ROUND)):
						return "use"
		"switch_side":
			# Switch when the player I back can no longer win (a dead human).
			if p.get("hope_side", "right") == "right":
				var backed := mind.backed_player()
				var bc := mind.character_of(backed)
				if backed != 0 and _p(backed).dead and bc.get("species", "") == "human":
					return "use"
	return ""


# --- Answering the server's questions ----------------------------------------------

## Pick a value for a server choice (prompt key + options), or null to skip.
## `hint` is server-side context only bots get (what the pick is for).
func choose(key: String, options: Array, allow_skip: bool, hint: Dictionary):
	var pick = _choose(key, options, allow_skip, hint)
	var values := options.map(func(o): return o.value)
	if pick == null and allow_skip:
		return null
	if pick == null or not pick in values:
		return values[0] if not values.is_empty() else null
	return pick


func _choose(key: String, options: Array, allow_skip: bool, hint: Dictionary):
	match key:
		"prompt.attack_whom":
			var best := _best(options, attack_score)
			return best.value if best.score > BotWeights.ATTACK_THRESHOLD or not allow_skip else null
		"prompt.ability_die":
			var t: int = hint.get("target", 0)
			if t != 0 and (_enmity(t) > BotWeights.ABILITY_DIE_ENMITY or mind.health_left(t) <= 4.0):
				return "use"
			return null
		"prompt.strike_back":
			return "yes" if mind.relation(hint.get("attacker", 0)) < 0.3 else null
		"prompt.choose_player":
			return _choose_player(options, allow_skip, hint)
		"prompt.magic_forest":
			var mode := magic_forest_mode()
			return mode if mode != "" else null
		"prompt.take_from_whom":
			return _best(options, func(id):
				var gear := 0.0
				for card in _p(id).equipment:
					gear = maxf(gear, equipment_value(card))
				return _enmity(id) + gear).value
		"prompt.which_one", "prompt.killed_take":
			return _best(options, func(uid): return equipment_value(_card_by_uid(uid))).value
		"prompt.give_equipment_to":
			return _best(options, func(uid): return -equipment_value(_card_by_uid(uid))).value
		"prompt.which_to_give":
			if not _others_alive().any(func(id): return mind.relation(id) > 0.3):
				return null
			return _best(options, func(uid): return -equipment_value(_card_by_uid(uid))).value
		"prompt.give_to_whom":
			return _best(options, func(id): return mind.relation(id)).value
		"prompt.peek_whom":
			return _best(options, func(id): return mind.uncertainty(id) + 0.2 * _enmity(id)).value
		"prompt.which_deck":
			return pick_deck(options.map(func(o): return o.value))
		"prompt.where_go", "prompt.old_map_pick":
			return pick_location(options.map(func(o): return o.value))
		"prompt.old_map_keep":
			var dest: String = hint.get("destination", "")
			var avg := 0.0
			for loc in s.state.locations:
				avg += location_score(loc.id)
			avg /= maxf(1.0, s.state.locations.size())
			return "keep" if location_score(dest) >= avg else "reroll"
		"prompt.use_now":
			return "use" if card_worth_using(hint.get("card", {})) else null
	# Something new: any option.
	return options.pick_random().value if not options.is_empty() else null


## A card or ability asks for a player: help a friend or hurt an enemy.
func _choose_player(options: Array, allow_skip: bool, hint: Dictionary):
	if hint.get("intent", "harm") == "help":
		var best := _best(options, func(id):
			var need := minf(float(_p(id).dmg), float(hint.get("amount", 1)))
			return mind.relation(id) * (0.5 + need))
		return best.value if best.score > 0.0 or not allow_skip else null
	var amount: float = hint.get("amount", 1)
	var best := _best(options, func(id):
		var score := _enmity(id)
		if mind.health_left(id) <= amount:
			score += BotWeights.KILL_BONUS * maxf(0.0, _enmity(id))
		return score)
	return best.value if best.score > -0.3 or not allow_skip else null
