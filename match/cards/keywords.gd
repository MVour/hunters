class_name Keywords
## Card and ability texts with their keywords marked: a small icon before
## the keyword and the keyword in its colour ("take [drop]2 damage", "if you
## are a [bat]vampire"), so a card reads at a glance. Found by patterns
## (English and Greek, both always: a text may fall back to English; Greek
## capitals are spelled out: the regex ignores case for Latin letters only), so
## the card data stays plain text. Icons: assets/icons/kw_*.png
## (tools/make_keyword_icons.gd), steal uses the board's steal icon.

const ICON_DIR := "res://assets/icons/"

## [group, colour, icon file, pattern]. Order matters where two could start
## at the same place (heal before damage: "heal 1 damage" is healing).
const KINDS := [
	["heal", "7ae08a", "kw_heal.png",
		"heal\\p{L}*(?: (?:\\d+|all your) damage| \\d+)?|[θΘ]ερ[αά]π\\p{L}*(?: (?:\\d+|όλες τις) ζημι\\p{L}+| \\d+)?"],
	["damage", "ff6a5a", "kw_damage.png", "\\+?\\d+ (?:damage|ζημι\\p{L}+)"],
	["attack", "e8e4dc", "kw_attack.png", "attack\\p{L}*|[εΕ]π[ιί]θ[εέ]σ\\p{L}*|[εΕ]πιτ[ιίε]θ\\p{L}*"],
	["vampire", "e06a6a", "kw_vampire.png", "vampires?|[βΒ]ρικόλακ\\p{L}*"],
	["werewolf", "e0a84c", "kw_werewolf.png", "werewol(?:f|ves)|[λΛ]υκάνθρωπ\\p{L}*"],
	["human", "8fb8e0", "kw_human.png", "humans?|[άαΆΑ]νθρ[ωώ]π\\p{L}*"],
	["steal", "c79af0", "icon_steal_equipment.png", "steal\\p{L}*|[κΚ]λ[έε][ψβ]\\p{L}*"],
	["equipment", "e8c060", "kw_equipment.png", "equipment(?: cards?)?|[εΕ]ξοπλισμ\\p{L}*"],
	["reach", "8fd4f5", "kw_reach.png", "within reach|reach|any location|[εΕ]μβέλει\\p{L}*|[οΟ]ποιαδήποτε τοποθεσία"],
	["dice", "f0ece0", "kw_dice.png", "\\d-sided die|d6|d4|\\p{L}*πλευρο ζάρι|ζάρι\\p{L}*"],
	["secret", "c79af0", "kw_secret.png", "character card|[κΚ]άρτα χαρακτήρα"],
]

static var _regex: RegEx


static func _pattern() -> RegEx:
	if _regex == null:
		var parts := []
		for kind in KINDS:
			parts.append("(?<%s>%s)" % [kind[0], kind[3]])
		_regex = RegEx.create_from_string("(?i)(?<!\\p{L})(?:%s)(?!\\p{L})" % "|".join(parts))
	return _regex


## The icon size for text of this font size: a bit taller than the letters.
## (The whole screen is scaled to the window anyway, so whole multiples of
## the 12 px drawing wouldn't stay whole.)
static func icon_px(font_px: int) -> int:
	return roundi(font_px * 1.2)


## `text` as BBCode for a RichTextLabel, keywords marked.
static func bbcode(text: String, font_px := 16) -> String:
	var size := icon_px(font_px)
	var out := ""
	var at := 0
	for m in _pattern().search_all(text):
		out += _escape(text.substr(at, m.get_start() - at))
		var kind: Array = KINDS[0]
		for k in KINDS:
			if m.get_string(k[0]) != "":
				kind = k
				break
		out += "[img=%dx%d]%s%s[/img][color=#%s]%s[/color]" % [size, size, ICON_DIR, kind[2], kind[1],
			_escape(m.get_string())]
		at = m.get_end()
	return out + _escape(text.substr(at))


static func _escape(s: String) -> String:
	return s.replace("[", "[lb]")


## A label for card / ability text with keywords marked: wraps, grows with
## its text, lets clicks through (it sits inside clickable cards).
static func label(text: String, font_px: int, centred := false, colour := Color(0.9, 0.88, 0.84)) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_size_override("normal_font_size", font_px)
	rich.add_theme_color_override("default_color", colour)
	set_text(rich, text, font_px, centred)
	return rich


static func set_text(rich: RichTextLabel, text: String, font_px: int, centred := false) -> void:
	var body := bbcode(text, font_px)
	rich.text = "[center]%s[/center]" % body if centred else body
