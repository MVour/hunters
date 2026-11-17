class_name Combat extends RefCounted
## Server only. Health, death, attacks, revealing, abilities and winning.
## Part of MatchServer (`s`); see docs/RULES.md.

var s: MatchServer


func _init(server: MatchServer) -> void:
	s = server


# --- Health ------------------------------------------------------------------------

func apply_damage(target_id: int, amount: int, source_id := 0) -> void:
	if not s.state.players.has(target_id):
		return
	var target: Dictionary = s.state.players[target_id]
	if target.dead or amount <= 0:
		return
	target.dmg = mini(target.dmg + amount, target.character.health)
	MatchNet.set_damage.rpc(target_id, target.dmg)
	if target.dmg >= target.character.health:
		_kill(target_id, source_id)


func heal(target_id: int, amount: int) -> void:
	if not s.state.players.has(target_id):
		return
	var target: Dictionary = s.state.players[target_id]
	if target.dead or amount <= 0:
		return
	target.dmg = maxi(0, target.dmg - amount)
	MatchNet.set_damage.rpc(target_id, target.dmg)


## Out of health: the player is out and their card is revealed to everyone.
func _kill(player_id: int, killer_id: int) -> void:
	var dead: Dictionary = s.state.players[player_id]
	dead.dead = true
	dead.hidden = false
	MatchNet.reveal_character.rpc(player_id, dead.character)
	MatchNet.player_died.rpc(player_id, killer_id)
	if killer_id != 0 and killer_id != player_id:
		var kills: Array = s.state.players[killer_id].get("kills", [])
		kills.append(dead.character.species)
		s.state.players[killer_id].kills = kills
	if check_win():
		return
	# The killer takes one of the dead player's equipment cards.
	if killer_id != 0 and killer_id != player_id and not dead.equipment.is_empty() \
			and not s.state.players[killer_id].dead:
		s.busy_begin()
		var uid = await s.cards.pick_equipment(killer_id, player_id,
			Msg.make("prompt.killed_take", {"player": dead.name}), false)
		s.cards.transfer_equipment(player_id, killer_id, uid)
		s.busy_end()
	s.after_resolution()


## A player left the match (BUG-001): out, card shown, nobody gets the kill.
func leave(player_id: int) -> void:
	var p: Dictionary = s.state.players[player_id]
	p.dead = true
	p.hidden = false
	MatchNet.reveal_character.rpc(player_id, p.character)
	MatchNet.player_died.rpc(player_id, 0)
	check_win()


## Protection wears off; always-on equipment that acts each turn.
func turn_start_effects(player_id: int) -> void:
	var p: Dictionary = s.state.players[player_id]
	if p.get("protected", false):
		s.cards.set_protected(player_id, false)
	var m := s.effects.mods(player_id)
	if m.get("heal_per_turn", 0) > 0 and p.dmg > 0:
		heal(player_id, m.heal_per_turn)
		s.notice(Msg.make("notice.satchel_heals", {"player": p.name, "amount": m.heal_per_turn}))
	if m.get("upkeep_damage", 0) > 0:
		s.notice(Msg.make("notice.ring_bites", {"player": p.name}))
		apply_damage(player_id, m.upkeep_damage)


# --- Attacks -----------------------------------------------------------------------

## Who `attacker` may attack right now.
func attack_targets(attacker: int) -> Array:
	return Rules.attack_targets(s.state.players, s.state.locations, s.state.turn_order, attacker)


func attack(sender: int) -> void:
	if not s.is_current(sender) or s.turn.phase != MatchServer.TurnPhase.ACTION \
			or s.turn.attacked or s.busy():
		return
	var targets := attack_targets(sender)
	if targets.is_empty():
		s.private_info(sender, Msg.make("info.attack_title"), Msg.make("info.nobody_in_reach"))
		return
	s.busy_begin()
	var target = await s.ask(sender, Msg.make("prompt.attack_whom"), targets.map(s.player_option))
	if target != null:
		s.turn.attacked = true
		await _attack(sender, target, true)
	s.busy_end()
	s.after_resolution()


## Roll both dice: the difference is the damage, adjusted by equipment and
## abilities. `allow_counter` lets the target strike back (Mel).
func _attack(attacker: int, target: int, allow_counter: bool) -> void:
	var a: Dictionary = s.state.players[attacker]
	var character: Dictionary = a.character
	var mode := "d6" if s.effects.mods(attacker).get("d6_attack", false) else "difference"

	# Frederick / Gregor: once per game, the damage is one die alone.
	if character.get("timing", "") == "attack" and not a.get("ability_used", false):
		var die := "6" if character.ability_id == "d6_attack" else "4"
		var reveal_note = Msg.make("note.reveals") if a.hidden else ""
		var use = await s.ask(attacker, Msg.make("prompt.ability_die",
				{"character": Msg.named(character), "die": die, "note": reveal_note}),
			[{"value": "use", "label": Msg.make("option.use_ability"), "color": "c8a85a"}], true,
			{"target": target})
		if use == "use":
			_mark_ability_used(attacker)
			mode = "d" + die

	var t: Dictionary = s.state.players[target]
	await s.ask_roll(attacker, Msg.make("prompt.roll_attack", {"player": t.name}))
	var dice := s.throw_dice()
	MatchNet.dice_rolled.rpc(dice.val6, dice.val4)
	await s.wait(1.2)  # let the dice land

	var dmg := absi(dice.val6 - dice.val4)
	match mode:
		"d6":
			dmg = dice.val6
		"d4":
			dmg = dice.val4
	if dmg > 0:
		dmg += s.effects.mods(attacker).get("attack_bonus", 0)
		if character.get("ability_id", "") == "savage" and not a.hidden:
			dmg += 1
	var tm := s.effects.mods(target)
	if dmg > 0:
		dmg = maxi(0, dmg - tm.get("damage_reduction", 0))
		if tm.has("max_attack_damage"):
			dmg = mini(dmg, tm.max_attack_damage)

	s.notice(Msg.make("notice.attack", {"attacker": a.name, "target": t.name, "d6": dice.val6,
		"d4": dice.val4, "dmg": dmg}))
	MatchNet.attack_fx.rpc(attacker, target, dmg)
	s.observe("harm", attacker, target, dmg)
	apply_damage(target, dmg, attacker)

	if tm.get("thorns", 0) > 0 and not a.dead:
		s.notice(Msg.make("notice.trap_snaps", {"player": t.name}))
		apply_damage(attacker, tm.thorns, target)
	if dmg > 0 and character.get("ability_id", "") == "lifesteal" and not a.hidden and not a.dead:
		heal(attacker, 2)
		s.notice(Msg.make("notice.drinks", {"player": a.name}))

	# Mel: strike back (not against the attack that killed her).
	if allow_counter and not t.dead and not a.dead and not s.finished \
			and t.character.get("ability_id", "") == "strike_back":
		var reveal_note = Msg.make("note.reveals") if t.hidden else ""
		var back = await s.ask(target, Msg.make("prompt.strike_back", {"attacker": a.name, "note": reveal_note}),
			[{"value": "yes", "label": Msg.make("option.strike_back"), "color": "e8402e"}], true,
			{"attacker": attacker})
		if back == "yes":
			if t.hidden:
				reveal(target)
			await _attack(target, attacker, false)


# --- Revealing & abilities -----------------------------------------------------------

func request_reveal(sender: int) -> void:
	var p: Dictionary = s.state.players.get(sender, {})
	if p.is_empty() or p.dead or not p.hidden:
		return
	reveal(sender)


func reveal(player_id: int) -> void:
	var p: Dictionary = s.state.players[player_id]
	p.hidden = false
	MatchNet.reveal_character.rpc(player_id, p.character)
	s.notice(Msg.make("notice.reveals", {"player": p.name, "character": Msg.named(p.character),
		"species": Msg.species(p.character.species)}))


func _mark_ability_used(player_id: int) -> void:
	s.state.players[player_id].ability_used = true
	if s.state.players[player_id].hidden:
		reveal(player_id)
	MatchNet.ability_used.rpc(player_id)


## The HUD's Use Ability button.
func use_ability(sender: int) -> void:
	var p: Dictionary = s.state.players.get(sender, {})
	if p.is_empty() or p.dead or s.busy() or s.finished:
		return
	var character: Dictionary = p.character
	match character.get("timing", ""):
		"passive":
			if p.hidden:
				reveal(sender)  # passive abilities work once you're revealed
			return
		"attack":
			s.private_info(sender, Msg.named(character), Msg.make("info.ability_on_attack"))
			return
		"reactive":
			s.private_info(sender, Msg.named(character), Msg.make("info.ability_when_attacked"))
			return
	if p.get("ability_used", false):
		s.private_info(sender, Msg.named(character), Msg.make("info.ability_used_already"))
		return
	if character.ability_id != "switch_side" and not s.is_current(sender):
		s.private_info(sender, Msg.named(character), Msg.make("info.ability_your_turn_only"))
		return

	s.busy_begin()
	var completed := true
	match character.ability_id:
		"full_heal":
			heal(sender, p.dmg)
		"switch_side":
			p.hope_side = "left"
			s.private_info(sender, Msg.named(character), Msg.make("info.backing_left"))
		"peek":
			completed = await s.effects.run({"name": character.name, "name_el": character.get("name_el", ""), "effect": [{"do": "peek_character"}]}, {"actor": sender})
		"heal_other":
			completed = await s.effects.run({"name": character.name, "name_el": character.get("name_el", ""),
				"effect": [{"do": "heal", "amount": 3, "target": "chosen_any"}]}, {"actor": sender})
		"drain":
			completed = await s.effects.run({"name": character.name, "name_el": character.get("name_el", ""), "effect": [
				{"do": "damage", "amount": 1, "target": "chosen_in_reach"},
				{"do": "heal", "amount": 1, "target": "self"}]}, {"actor": sender})
	if completed:
		_mark_ability_used(sender)
	s.busy_end()
	s.after_resolution()


# --- Winning -----------------------------------------------------------------------

## Ends the game when one side is wiped out. Returns true if it ended.
func check_win() -> bool:
	if s.finished:
		return true
	var total := {"vampire": 0, "werewolf": 0}
	var alive := {"vampire": 0, "werewolf": 0}
	for p in s.state.players.values():
		var species: String = p.character.get("species", "")
		if total.has(species):
			total[species] += 1
			if not p.dead:
				alive[species] += 1
	var faction := ""
	if total.werewolf > 0 and alive.werewolf == 0:
		faction = "vampire"
	if total.vampire > 0 and alive.vampire == 0:
		faction = "werewolf" if faction == "" else "none"  # both gone at once
	if faction == "":
		return false

	s.finished = true
	var winners := []
	for id in s.state.players:
		if _goal_met(id, alive, []):
			winners.append(id)
	var characters := {}
	for id in s.state.players:
		characters[id] = s.state.players[id].character
	MatchNet.game_over.rpc(faction, winners, characters)
	return true


func _goal_met(id: int, alive: Dictionary, visited: Array) -> bool:
	var p: Dictionary = s.state.players[id]
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
			var order: Array = s.state.turn_order
			var step := -1 if p.get("hope_side", "right") == "left" else 1
			var neighbour: int = order[(order.find(id) + step + order.size()) % order.size()]
			if neighbour == id or neighbour in visited:
				return false
			return _goal_met(neighbour, alive, visited + [id])
	return false
