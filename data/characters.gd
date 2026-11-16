class_name Characters
## Every playable character (see docs/RULES.md). English + Greek texts.
##
## "ability_id" is what the game manager runs; "timing" says when:
##   once    - once per game, from the HUD's Use Ability button
##   passive - always on, but only while revealed
##   attack  - once per game, offered when you attack
##   reactive- offered when something happens to you (e.g. being attacked)
## Using an ability reveals your character. "goal_id" is checked at the end.

const HUMANS := [
	{"id": "ada", "species": "human", "name": "Ada", "name_el": "Άντα", "health": 8,
		"ability_id": "full_heal", "timing": "once",
		"ability": "Once per game: heal all your damage.",
		"ability_el": "Μία φορά ανά παιχνίδι: θεράπευσε όλες τις ζημιές σου.",
		"goal_id": "survive", "goal": "Survive until the end of the game.",
		"goal_el": "Να επιβιώσεις μέχρι το τέλος του παιχνιδιού."},
	{"id": "hope", "species": "human", "name": "Hope", "name_el": "Ελπίδα", "health": 8,
		"ability_id": "switch_side", "timing": "once",
		"ability": "Once per game: switch from backing the player on your right to the player on your left.",
		"ability_el": "Μία φορά ανά παιχνίδι: άλλαξε από τον παίχτη στα δεξιά σου στον παίχτη στα αριστερά σου.",
		"goal_id": "neighbour_wins", "goal": "You win if the player on your RIGHT wins.",
		"goal_el": "Κερδίζεις αν κερδίσει ο παίχτης στα ΔΕΞΙΑ σου."},
	{"id": "elias", "species": "human", "name": "Elias", "name_el": "Ηλίας", "health": 10,
		"ability_id": "peek", "timing": "once",
		"ability": "Once per game: secretly look at another player's character.",
		"ability_el": "Μία φορά ανά παιχνίδι: δες κρυφά τον χαρακτήρα ενός άλλου παίχτη.",
		"goal_id": "hunter", "goal": "Kill a vampire or a werewolf.",
		"goal_el": "Σκότωσε έναν βρικόλακα ή έναν λυκάνθρωπο."},
	{"id": "iris", "species": "human", "name": "Iris", "name_el": "Ίρις", "health": 9,
		"ability_id": "heal_other", "timing": "once",
		"ability": "Once per game: heal 3 damage on any player.",
		"ability_el": "Μία φορά ανά παιχνίδι: θεράπευσε 3 ζημιές σε όποιον παίχτη θέλεις.",
		"goal_id": "survive", "goal": "Survive until the end of the game.",
		"goal_el": "Να επιβιώσεις μέχρι το τέλος του παιχνιδιού."},
]

const VAMPIRES := [
	{"id": "volco", "species": "vampire", "name": "Volco", "name_el": "Βόλκο", "health": 13,
		"ability_id": "lifesteal", "timing": "passive",
		"ability": "Heal 2 whenever your attack deals damage.",
		"ability_el": "Θεράπευσε 2 κάθε φορά που η επίθεσή σου κάνει ζημιά.",
		"goal_id": "no_werewolves", "goal": "No werewolves left standing.",
		"goal_el": "Να μη μείνει κανένας λυκάνθρωπος όρθιος."},
	{"id": "mel", "species": "vampire", "name": "Mel", "name_el": "Μελ", "health": 14,
		"ability_id": "strike_back", "timing": "reactive",
		"ability": "When attacked, you may attack back right away, even outside your turn. Not against the attack that kills you.",
		"ability_el": "Όταν δέχεσαι επίθεση, μπορείς να ανταποδώσεις αμέσως, ακόμα και εκτός σειράς. Όχι στην επίθεση που σε σκοτώνει.",
		"goal_id": "no_werewolves", "goal": "No werewolves left standing.",
		"goal_el": "Να μη μείνει κανένας λυκάνθρωπος όρθιος."},
	{"id": "selene", "species": "vampire", "name": "Selene", "name_el": "Σελήνη", "health": 11,
		"ability_id": "drain", "timing": "once",
		"ability": "Once per game, on your turn: deal 1 damage to a player within reach and heal 1.",
		"ability_el": "Μία φορά ανά παιχνίδι, στη σειρά σου: κάνε 1 ζημιά σε παίχτη εντός εμβέλειας και θεράπευσε 1.",
		"goal_id": "no_werewolves", "goal": "No werewolves left standing.",
		"goal_el": "Να μη μείνει κανένας λυκάνθρωπος όρθιος."},
]

const WEREWOLVES := [
	{"id": "frederick", "species": "werewolf", "name": "Frederick", "name_el": "Φρειδερίκος", "health": 12,
		"ability_id": "d6_attack", "timing": "attack",
		"ability": "Once per game: attack using only the 6-sided die as the damage.",
		"ability_el": "Μία φορά ανά παιχνίδι: επίθεση με ζημιά μόνο την ένδειξη του εξάπλευρου ζαριού.",
		"goal_id": "no_vampires", "goal": "No vampires left standing.",
		"goal_el": "Να μη μείνει κανένας βρικόλακας όρθιος."},
	{"id": "gregor", "species": "werewolf", "name": "Gregor", "name_el": "Γρηγόρης", "health": 14,
		"ability_id": "d4_attack", "timing": "attack",
		"ability": "Once per game: attack using only the 4-sided die as the damage.",
		"ability_el": "Μία φορά ανά παιχνίδι: επίθεση με ζημιά μόνο την ένδειξη του τετράπλευρου ζαριού.",
		"goal_id": "no_vampires", "goal": "No vampires left standing.",
		"goal_el": "Να μη μείνει κανένας βρικόλακας όρθιος."},
	{"id": "bran", "species": "werewolf", "name": "Bran", "name_el": "Μπραν", "health": 13,
		"ability_id": "savage", "timing": "passive",
		"ability": "Your attacks deal +1 damage.",
		"ability_el": "Οι επιθέσεις σου κάνουν +1 ζημιά.",
		"goal_id": "no_vampires", "goal": "No vampires left standing.",
		"goal_el": "Να μη μείνει κανένας βρικόλακας όρθιος."},
]
