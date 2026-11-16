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
	"players" : {
		2 : {"vampires_count": 1, "werewolves_count": 1, "humans_count": 0},
		3 : {"vampires_count": 1, "werewolves_count": 1, "humans_count": 1},
		4 : {"vampires_count": 2, "werewolves_count": 2, "humans_count": 0},
		5 : {"vampires_count": 2, "werewolves_count": 2, "humans_count": 1},
		6 : {"vampires_count": 2, "werewolves_count": 2, "humans_count": 2},
		7 : {"vampires_count": 2, "werewolves_count": 2, "humans_count": 3},
		8 : {"vampires_count": 3, "werewolves_count": 3, "humans_count": 2}
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
	"draw_green": {"color": "4fd08a", "icon": "res://assets/icons/icon_draw_green.png", "text": "Draw a green card."},
	"draw_blue": {"color": "6a9af0", "icon": "res://assets/icons/icon_draw_blue.png", "text": "Draw a blue card."},
	"draw_red": {"color": "e8402e", "icon": "res://assets/icons/icon_draw_red.png", "text": "Draw a red card."},
	"draw_any": {"color": "e8c060", "icon": "res://assets/icons/icon_draw_any.png", "text": "Draw a card of any colour."},
	"steal_equipment": {"color": "b07ae8", "icon": "res://assets/icons/icon_steal_equipment.png", "text": "Steal an equipment card from any player."},
	"heal_or_damage": {"color": "4fe0d0", "icon": "res://assets/icons/icon_heal_or_damage.png", "text": "Heal 1 health on any player (yourself included), or deal 2 damage to any player."},
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
		{"id": "lone_cabin", "name": "lone_cabin", "label": "Lone Cabin", "rolls": [2, 3], "action": "draw_green"},
		{"id": "widows_river", "name": "widows_river", "label": "Widow's River", "rolls": [4, 5], "action": "draw_any"},
		{"id": "old_chapel", "name": "old_chapel", "label": "Old Chapel", "rolls": [6], "action": "draw_blue"},
		{"id": "cemetery", "name": "cemetery", "label": "Cemetery", "rolls": [8], "action": "draw_red"},
		{"id": "magic_forest", "name": "magic_forest", "label": "Magic Forest", "rolls": [9], "action": "heal_or_damage"},
		{"id": "stone_circle", "name": "stone_circle", "label": "Stone Circle", "rolls": [10], "action": "steal_equipment"},
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

var classic_art := true:
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
	if config.load(SETTINGS_PATH) == OK:
		classic_art = config.get_value("art", "classic", classic_art)
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


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("art", "classic", classic_art)
	config.save(SETTINGS_PATH)
