extends Node
## Static game data that never changes while playing: sprites, defaults,
## and the master card lists. Never modify these at runtime; the server
## copies them into its ServerState for each match.

const CARD_TYPES := ["red_cards", "green_cards", "blue_cards"]

var colors_sprites = {
	"white": preload("res://assets/pawns/white.png"),
	"blue": preload("res://assets/pawns/blue.png"),
	"red": preload("res://assets/pawns/red.png"),
	"green": preload("res://assets/pawns/green.png"),
	"light_blue": preload("res://assets/pawns/light_blue.png"),
	"yellow": preload("res://assets/pawns/yellow.png"),
	"purple": preload("res://assets/pawns/purple.png"),
	"orange": preload("res://assets/pawns/orange.png"),
}

var game_settings_default = {
	## Team presets per player count, as [vampires, werewolves, humans]. The
	## first one is the default; the lobby's Preset button cycles through them.
	## There are 3 vampires, 3 werewolves and 4 humans to deal from.
	"presets" : {
		2 : [[1, 1, 0]],
		3 : [[1, 1, 1]],
		4 : [[2, 2, 0], [1, 1, 2]],
		5 : [[2, 2, 1], [1, 1, 3]],
		6 : [[2, 2, 2], [3, 3, 0], [1, 1, 4]],
		7 : [[2, 2, 3], [3, 3, 1]],
		8 : [[3, 3, 2], [2, 2, 4]],
	},
	## Seats around the clearing, clockwise from you (slot1, bottom-left):
	## slot2 left (under the life track), slot3-5 top, slot6-8 right.
	"chairs_config" : {
		2 : ["slot1", "slot4"],
		3 : ["slot1", "slot3", "slot5"],
		4 : ["slot1", "slot3", "slot5", "slot7"],
		5 : ["slot1", "slot3", "slot4", "slot5", "slot7"],
		6 : ["slot1", "slot2", "slot3", "slot4", "slot5", "slot7"],
		7 : ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "slot8"],
		8 : ["slot1", "slot2", "slot3", "slot4", "slot5", "slot6", "slot7", "slot8"],
	}
}

## Rolling this total lets you move to any location except your current one.
## Full rules: docs/RULES.md
const ROLL_ANY_LOCATION := 7

## What each location lets you do: badge colour, icon, and hover text.
## Which decks a location action lets you draw from.
const DRAW_ACTIONS := {
	"draw_green": ["green_cards"],
	"draw_red": ["red_cards"],
	"draw_blue": ["blue_cards"],
	"draw_any": ["green_cards", "red_cards", "blue_cards"],
}

const LOCATION_ACTIONS := {
	"draw_green": {"color": "4fd08a", "icon": "res://assets/icons/icon_draw_green.png", "text": "Draw a green card.", "text_el": "Τράβηξε μια πράσινη κάρτα."},
	"draw_blue": {"color": "6a9af0", "icon": "res://assets/icons/icon_draw_blue.png", "text": "Draw a blue card.", "text_el": "Τράβηξε μια μπλε κάρτα."},
	"draw_red": {"color": "e8402e", "icon": "res://assets/icons/icon_draw_red.png", "text": "Draw a red card.", "text_el": "Τράβηξε μια κόκκινη κάρτα."},
	"draw_any": {"color": "e8c060", "icon": "res://assets/icons/icon_draw_any.png", "text": "Draw a card of any colour.", "text_el": "Τράβηξε μια κάρτα όποιου χρώματος θέλεις."},
	"steal_equipment": {"color": "b07ae8", "icon": "res://assets/icons/icon_steal_equipment.png", "text": "Steal an equipment card from any player.", "text_el": "Κλέψε έναν εξοπλισμό από όποιον παίκτη θέλεις."},
	"heal_or_damage": {"color": "4fe0d0", "icon": "res://assets/icons/icon_heal_or_damage.png", "text": "Heal 1 health on any player (yourself included), or deal 2 damage to any player.", "text_el": "Θεράπευσε 1 ζημιά σε όποιον παίκτη θέλεις (και σε σένα), ή κάνε 2 ζημιά σε όποιον παίκτη θέλεις."},
}

## Maps the lobby's settings keys to character lists and species names.
const SPECIES := {
	"vampires_count": {"list": "vampires", "species": "vampire"},
	"werewolves_count": {"list": "werewolves", "species": "werewolf"},
	"humans_count": {"list": "humans", "species": "human"},
}


var deck = {
	# Character data lives in scripts/characters.gd.
	"characters": {
		"humans" : Characters.HUMANS.duplicate(true),
		"vampires": Characters.VAMPIRES.duplicate(true),
		"werewolves": Characters.WEREWOLVES.duplicate(true),
	},
	## Shuffled around the board every game. "rolls" = the dice totals
	## (d6 + d4) that send you here; "action" keys into LOCATION_ACTIONS.
	"locations" : [
		{"id": "lone_cabin", "name": "lone_cabin", "label": "Lone Cabin", "label_el": "Μοναχική Καλύβα", "rolls": [2, 3], "action": "draw_green"},
		{"id": "widows_river", "name": "widows_river", "label": "Widow's River", "label_el": "Ποτάμι της Χήρας", "rolls": [4, 5], "action": "draw_any"},
		{"id": "old_chapel", "name": "old_chapel", "label": "Old Chapel", "label_el": "Παλιό Παρεκκλήσι", "rolls": [6], "action": "draw_blue"},
		{"id": "cemetery", "name": "cemetery", "label": "Cemetery", "label_el": "Νεκροταφείο", "rolls": [8], "action": "draw_red"},
		{"id": "magic_forest", "name": "magic_forest", "label": "Magic Forest", "label_el": "Μαγικό Δάσος", "rolls": [9], "action": "heal_or_damage"},
		{"id": "stone_circle", "name": "stone_circle", "label": "Stone Circle", "label_el": "Πέτρινος Κύκλος", "rolls": [10], "action": "steal_equipment"},
	],
	# The card designs live in scripts/cards.gd (see docs/CARDS.md).
	"green_cards" : Cards.build(Cards.GREEN),
	"red_cards" : Cards.build(Cards.RED),
	"blue_cards" : Cards.build(Cards.BLUE),
}

## Display info per deck.
const CARD_COLORS := {
	"green_cards": {"label": "green", "label_el": "Πράσινη", "color": "44b052"},
	"red_cards": {"label": "red", "label_el": "Κόκκινη", "color": "d83a42"},
	"blue_cards": {"label": "blue", "label_el": "Μπλε", "color": "3a7ae0"},
}


## Who owns which pawn is tracked in GameState.players, not here.
var pawns = {
	"white": {"color": "white", "hex": "d8dde3", "sprite": preload("res://assets/pawns/white.png")},
	"blue": {"color": "blue", "hex": "3a6ae0", "sprite": preload("res://assets/pawns/blue.png")},
	"red": {"color": "red", "hex": "d83a42", "sprite": preload("res://assets/pawns/red.png")},
	"green": {"color": "green", "hex": "44b052", "sprite": preload("res://assets/pawns/green.png")},
	"light_blue": {"color": "light_blue", "hex": "5cc4f0", "sprite": preload("res://assets/pawns/light_blue.png")},
	"yellow": {"color": "yellow", "hex": "f0c840", "sprite": preload("res://assets/pawns/yellow.png")},
	"purple": {"color": "purple", "hex": "9a5ad8", "sprite": preload("res://assets/pawns/purple.png")},
	"orange": {"color": "orange", "hex": "f08030", "sprite": preload("res://assets/pawns/orange.png")},
}


# --- Classic art ---------------------------------------------------------
## Swap between the ORIGINAL art (Feb 2025: path-tile board, chapel
## locations, stick-figure pawns, animated 38px portraits, first card backs)
## and the current art. Purely cosmetic and local to this computer; the
## rules and networking are the same either way. Toggled from the main menu.

signal art_style_changed(classic: bool)

const SETTINGS_PATH := "user://settings.cfg"

## Tests only (`-- --fast`): the server's pauses (dice landing, the attack
## wind-up, bots thinking) take one frame. Players never pass it.
var fast_mode := "--fast" in OS.get_cmdline_user_args()

## Off unless this computer saved "on" (new players, browsers: current art).
var classic_art := false:
	set(on):
		if on == classic_art:
			return
		classic_art = on
		_apply_pawn_art()
		_save_settings()
		art_style_changed.emit(on)

## Current pawn art, remembered so classic mode can be switched off again.
var _current_pawn_sprites := {}

const CLASSIC_CARD_BACKS := {
	"green_cards": "res://assets/legacy/cards/green_card_original.webp",
	"red_cards": "res://assets/legacy/cards/red_card_original.webp",
	"blue_cards": "res://assets/legacy/cards/blue_card_original.jpeg",
}
const CARD_BACKS := {
	"green_cards": "res://assets/cards/green_card.png",
	"red_cards": "res://assets/cards/red_card.png",
	"blue_cards": "res://assets/cards/blue_card.png",
}

## The old map used one chapel picture for every location; the Old Chapel
## gets the other chapel drawing so both originals are on the board.
const CLASSIC_LOCATION_ART := "res://assets/legacy/board/chapel_original2.png"
const CLASSIC_LOCATION_ART_OVERRIDES := {
	"old_chapel": "res://assets/legacy/board/chapel_original.png",
}

## Old animated portraits; animations are named after the species, with
## extra variants ("vampire_rain", "werewolf_light", ...) to click through.
const CLASSIC_PORTRAITS := "res://assets/legacy/portraits/classic_portraits.tres"


func _ready() -> void:
	for color in pawns:
		_current_pawn_sprites[color] = pawns[color].sprite
	var config := ConfigFile.new()
	var saving := persist_settings
	persist_settings = false  # just loading: don't write the same values back
	if config.load(SETTINGS_PATH) == OK:
		classic_art = config.get_value("art", "classic", classic_art)
		lang = config.get_value("ui", "lang", lang)
	TranslationServer.set_locale(lang)
	persist_settings = saving
	_apply_pawn_art()


func card_back(card_type: String) -> Texture2D:
	return load((CLASSIC_CARD_BACKS if classic_art else CARD_BACKS)[card_type])


func classic_location_art(location_name: String) -> Texture2D:
	return load(CLASSIC_LOCATION_ART_OVERRIDES.get(location_name, CLASSIC_LOCATION_ART))


## Everything that shows a pawn reads Global.pawns / colors_sprites, so
## swapping the textures here changes the lobby, seats, life track and board.
func _apply_pawn_art() -> void:
	for color in pawns:
		var sprite: Texture2D = _current_pawn_sprites.get(color, pawns[color].sprite)
		if classic_art:
			var old := "res://assets/legacy/pawns/%s.png" % color
			if ResourceLoader.exists(old):
				sprite = load(old)
		pawns[color].sprite = sprite
		colors_sprites[color] = sprite


## Map figures (tools/make_figures.gd): <kind>_<colour>.png, kind = a species
## or "grave".
const FIGURES := "res://assets/pawns/figures/%s_%s.png"


## What stands for a player on the board and the life track: their pawn
## while their character is hidden, their species' figure once revealed, a
## gravestone once dead. Classic art keeps the old pawns throughout.
func player_sprite(player: Dictionary) -> Texture2D:
	var color: String = player.get("pawn", "")
	if not pawns.has(color):
		return null
	var pawn: Texture2D = pawns[color].sprite
	if classic_art:
		return pawn
	var kind := ""
	if player.get("dead", false):
		kind = "grave"
	elif not player.get("hidden", true):
		kind = player.get("character", {}).get("species", "")
	var path := FIGURES % [kind, color]
	if kind == "" or not ResourceLoader.exists(path):
		return pawn
	return load(path)


## Tests switch this off so they never change the player's saved settings.
var persist_settings := true


func _save_settings() -> void:
	if not persist_settings:
		return
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("art", "classic", classic_art)
	config.set_value("ui", "lang", lang)
	config.save(SETTINGS_PATH)


# --- Language ------------------------------------------------------------
## Every player-facing text lives in i18n/strings.csv (keys,en,el), like a
## front-end i18n file. Godot imports it as translations; the player sees
## one language, switched with the language button (bottom-left) and saved
## in user://settings.cfg.
##   Global.text("status.your_turn_roll")                  a key
##   Global.text("notice.attack", {"attacker": "Bob"})      {named} blanks
##   Global.msg(m)          a message from the server: {"k": key, "p": params}
##   Global.field(card, "name")    card/character data: name or name_el
## Scene-file texts (Labels, Buttons) are keys too and switch by themselves.
## UI that builds text in code listens to language_changed.

signal language_changed

## "en" or "el".
var lang := "en":
	set(value):
		if value == lang or not value in ["en", "el"]:
			return
		lang = value
		TranslationServer.set_locale(lang)
		_save_settings()
		language_changed.emit()


## The text for a key, with {named} blanks filled in. Values may be plain,
## a server message (see Msg) or a name dict (Msg.named), shown localized.
func text(key: String, params := {}) -> String:
	var s := TranslationServer.translate(key)
	return s.format(_resolve(params)) if not params.is_empty() else s


## A message from the server: {"k": key, "p": params}, a name dict
## ({"name", "name_el"}), or plain text.
func msg(m) -> String:
	if m is Dictionary:
		if m.has("k"):
			return text(m.k, m.get("p", {}))
		if m.has("name"):
			return field(m, "name")
		return ""
	return str(m)


func _resolve(params: Dictionary) -> Dictionary:
	var out := {}
	for key in params:
		out[key] = msg(params[key])
	return out


## A data field in the current language: field(card, "name") gives
## card.name_el in Greek (when it exists), else card.name.
## A species id ("vampire") in the current language.
func species_name(species_id: String) -> String:
	return text("species." + species_id) if species_id != "" else "?"


func field(data: Dictionary, key: String) -> String:
	if lang == "el" and str(data.get(key + "_el", "")) != "":
		return str(data[key + "_el"])
	return str(data.get(key, ""))
