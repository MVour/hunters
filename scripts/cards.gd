class_name Cards
## The card set (see docs/CARDS.md). Each entry is one card design;
## "copies" says how many are in the deck. "kind" is question / event /
## equipment. Effects are implemented per id in the game manager (step 3).

const GREEN := [
	{"id": "silver_coin", "name": "Silver Coin", "name_el": "Ασημένιο Νόμισμα", "kind": "question", "copies": 2,
		"text": "I think you are a werewolf.\nIf you are a werewolf, take 1 damage."},
	{"id": "garlic_bread", "name": "Garlic Bread", "name_el": "Σκορδόψωμο", "kind": "question", "copies": 2,
		"text": "I think you are a vampire.\nIf you are a vampire, take 1 damage."},
	{"id": "clean_hands", "name": "Clean Hands", "name_el": "Καθαρά Χέρια", "kind": "question", "copies": 2,
		"text": "If you are a human, heal 1 damage.\nOtherwise, take 1 damage."},
	{"id": "full_moon_rising", "name": "Full Moon Rising", "name_el": "Πανσέληνος", "kind": "question", "copies": 1,
		"text": "If you are a werewolf or a human, take 1 damage."},
	{"id": "cold_skin", "name": "Cold Skin", "name_el": "Παγωμένο Δέρμα", "kind": "question", "copies": 1,
		"text": "If you are a vampire or a human, take 1 damage."},
	{"id": "blood_debt", "name": "Blood Debt", "name_el": "Χρέος Αίματος", "kind": "question", "copies": 1,
		"text": "If you are a vampire, give the asker one equipment card, or take 1 damage if you have none."},
	{"id": "pack_tax", "name": "Pack Tax", "name_el": "Φόρος της Αγέλης", "kind": "question", "copies": 1,
		"text": "If you are a werewolf, give the asker one equipment card, or take 1 damage if you have none."},
	{"id": "night_watch", "name": "Night Watch", "name_el": "Νυχτερινή Σκοπιά", "kind": "question", "copies": 1,
		"text": "If you are not a human, take 1 damage."},
	{"id": "hunters_hunch", "name": "Hunter's Hunch", "name_el": "Προαίσθημα του Κυνηγού", "kind": "question", "copies": 1,
		"text": "If you are not a werewolf, heal 1 damage.\nOtherwise, take 2 damage."},
	{"id": "mirror_in_the_hall", "name": "Mirror in the Hall", "name_el": "Ο Καθρέφτης του Διαδρόμου", "kind": "question", "copies": 1,
		"text": "If you are a vampire, show your character card to the asker only."},
	{"id": "whispered_name", "name": "Whispered Name", "name_el": "Ψιθυριστό Όνομα", "kind": "question", "copies": 1,
		"text": "Tell the asker your character's starting health, truthfully."},
]

const RED := [
	{"id": "silver_dagger", "name": "Silver Dagger", "name_el": "Ασημένιο Στιλέτο", "kind": "equipment", "copies": 1,
		"text": "Your attacks deal +1 damage."},
	{"id": "hunters_crossbow", "name": "Hunter's Crossbow", "name_el": "Βαλλίστρα του Κυνηγού", "kind": "equipment", "copies": 1,
		"text": "You may attack players at any location (ignores reach)."},
	{"id": "wolfsbane_axe", "name": "Wolfsbane Axe", "name_el": "Τσεκούρι του Λυκοκτόνου", "kind": "equipment", "copies": 1,
		"text": "Your attacks deal +1 damage."},
	{"id": "barbed_gauntlet", "name": "Barbed Gauntlet", "name_el": "Αγκαθωτό Γάντι", "kind": "equipment", "copies": 1,
		"text": "When you attack, roll only the d6: the result is the damage."},
	{"id": "rusty_bear_trap", "name": "Rusty Bear Trap", "name_el": "Σκουριασμένη Παγίδα", "kind": "equipment", "copies": 1,
		"text": "Anyone who attacks you takes 1 damage."},
	{"id": "cursed_ring", "name": "Cursed Ring", "name_el": "Καταραμένο Δαχτυλίδι", "kind": "equipment", "copies": 1,
		"text": "Your attacks deal +2 damage, but you take 1 damage at the start of each of your turns."},
	{"id": "swarm_of_bats", "name": "Swarm of Bats", "name_el": "Σμήνος Νυχτερίδων", "kind": "event", "must": true, "copies": 2,
		"text": "Deal 2 damage to a player of your choice, and heal 1 yourself."},
	{"id": "forest_fire", "name": "Forest Fire", "name_el": "Φωτιά στο Δάσος", "kind": "event", "must": true, "copies": 1,
		"text": "Everyone at your location and the next one (including you) takes 2 damage."},
	{"id": "bad_mushrooms", "name": "Bad Mushrooms", "name_el": "Χαλασμένα Μανιτάρια", "kind": "event", "must": true, "copies": 1,
		"text": "You take 2 damage."},
	{"id": "blood_moon", "name": "Blood Moon", "name_el": "Ματωμένο Φεγγάρι", "kind": "event", "must": true, "copies": 1,
		"text": "Every player except you takes 1 damage."},
	{"id": "ambush", "name": "Ambush", "name_el": "Ενέδρα", "kind": "event", "copies": 2,
		"text": "Deal 3 damage to a player within reach; you take 1 damage."},
	{"id": "thief_in_the_night", "name": "Thief in the Night", "name_el": "Κλέφτης της Νύχτας", "kind": "event", "copies": 1,
		"text": "Steal one equipment card from any player."},
	{"id": "wolfs_bite", "name": "Wolf's Bite", "name_el": "Δάγκωμα Λύκου", "kind": "event", "must": true, "copies": 1,
		"text": "Choose a player: they take 2 damage. If they are a vampire, they take 3 instead."},
	{"id": "grave_robbery", "name": "Grave Robbery", "name_el": "Τυμβωρυχία", "kind": "event", "copies": 1,
		"text": "Take one equipment card of your choice from a dead player."},
]

const BLUE := [
	{"id": "lucky_rabbit_foot", "name": "Lucky Rabbit Foot", "name_el": "Γούρικο Ποδαράκι Λαγού", "kind": "equipment", "copies": 1,
		"text": "Attacks against you deal 1 less damage."},
	{"id": "holy_amulet", "name": "Holy Amulet", "name_el": "Ιερό Φυλαχτό", "kind": "equipment", "copies": 1,
		"text": "Red events can't damage you."},
	{"id": "healers_satchel", "name": "Healer's Satchel", "name_el": "Σακίδιο του Θεραπευτή", "kind": "equipment", "copies": 1,
		"text": "At the start of your turn, heal 1 damage."},
	{"id": "widows_lantern", "name": "Widow's Lantern", "name_el": "Το Φανάρι της Χήρας", "kind": "equipment", "copies": 1,
		"text": "Your reach extends to the location before yours too."},
	{"id": "old_map", "name": "Old Map", "name_el": "Παλιός Χάρτης", "kind": "equipment", "copies": 1,
		"text": "When you roll to move, you may roll a second time and pick either result."},
	{"id": "iron_shield", "name": "Iron Shield", "name_el": "Σιδερένια Ασπίδα", "kind": "equipment", "copies": 1,
		"text": "You can't take more than 3 damage from a single attack."},
	{"id": "healing_spring", "name": "Healing Spring", "name_el": "Ιαματική Πηγή", "kind": "event", "copies": 2,
		"text": "Heal 2 damage."},
	{"id": "campfire_rest", "name": "Campfire Rest", "name_el": "Ανάπαυση στη Φωτιά", "kind": "event", "copies": 1,
		"text": "Every player at your location heals 1 damage."},
	{"id": "second_wind", "name": "Second Wind", "name_el": "Δεύτερη Ανάσα", "kind": "event", "copies": 1,
		"text": "If you have 5 or more damage, heal 3. Otherwise heal 1."},
	{"id": "guardian_spirit", "name": "Guardian Spirit", "name_el": "Πνεύμα Φύλακας", "kind": "event", "must": true, "copies": 1,
		"text": "Until your next turn, nobody can attack you."},
	{"id": "shortcut", "name": "Shortcut", "name_el": "Κρυφό Μονοπάτι", "kind": "event", "copies": 1,
		"text": "Move to any location (like rolling a 7)."},
	{"id": "moonlit_insight", "name": "Moonlit Insight", "name_el": "Φεγγαρόφωτη Ματιά", "kind": "event", "copies": 1,
		"text": "Secretly look at another player's character card."},
	{"id": "lucky_find", "name": "Lucky Find", "name_el": "Τυχερό Εύρημα", "kind": "event", "copies": 1,
		"text": "Draw a card of any colour."},
	{"id": "peace_offering", "name": "Peace Offering", "name_el": "Δώρο Ειρήνης", "kind": "event", "copies": 1,
		"text": "Give one of your equipment cards to another player; both of you heal 1."},
	{"id": "sanctuary", "name": "Sanctuary", "name_el": "Καταφύγιο", "kind": "event", "copies": 1,
		"text": "Heal 1 damage on any player of your choice."},
]


## One deck: every design repeated "copies" times, each with a unique uid.
static func build(designs: Array) -> Array:
	var deck := []
	for design in designs:
		for i in design.get("copies", 1):
			var card: Dictionary = design.duplicate(true)
			card.uid = "%s#%d" % [design.id, i + 1]
			card.erase("copies")
			deck.append(card)
	return deck
