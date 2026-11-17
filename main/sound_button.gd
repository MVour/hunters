class_name SoundButton extends Button
## Bottom-left, next to the language button, on every screen. Opens a small
## popup: music on/off + volume, rain on/off + volume (Audio autoload).

const POPUP_WIDTH := 300

var _popup: PopupPanel
var _music_toggle: CheckButton
var _music_slider: HSlider
var _rain_toggle: CheckButton
var _rain_slider: HSlider


func _ready() -> void:
	custom_minimum_size = Vector2(110, 40)
	add_theme_font_size_override("font_size", 17)
	_build_popup()
	pressed.connect(_open)
	Global.language_changed.connect(_apply_language)
	Audio.settings_changed.connect(_sync)
	_apply_language()
	_sync()


func _build_popup() -> void:
	_popup = PopupPanel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.94)
	style.border_color = Color(1, 1, 1, 0.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_popup.add_theme_stylebox_override("panel", style)
	add_child(_popup)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	column.add_theme_constant_override("separation", 6)
	_popup.add_child(column)

	_music_toggle = _toggle(column, Audio.set_music_on)
	_music_slider = _slider(column, Audio.set_music_volume)
	column.add_child(HSeparator.new())
	_rain_toggle = _toggle(column, Audio.set_rain_on)
	_rain_slider = _slider(column, Audio.set_rain_volume)


func _toggle(parent: Control, setter: Callable) -> CheckButton:
	var t := CheckButton.new()
	t.add_theme_font_size_override("font_size", 18)
	t.toggled.connect(setter)
	parent.add_child(t)
	return t


func _slider(parent: Control, setter: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(POPUP_WIDTH, 24)
	s.value_changed.connect(setter)
	parent.add_child(s)
	return s


func _open() -> void:
	_popup.reset_size()
	var above := global_position + Vector2(0, -_popup.size.y - 8)
	_popup.popup(Rect2i(Vector2i(above), _popup.size))


func _apply_language() -> void:
	text = Global.text("sound.button")
	tooltip_text = Global.text("sound.tooltip")
	_music_toggle.text = Global.text("sound.music")
	_rain_toggle.text = Global.text("sound.rain")
	_music_slider.tooltip_text = Global.text("sound.volume")
	_rain_slider.tooltip_text = Global.text("sound.volume")


## Show the saved settings (without firing the setters again).
func _sync() -> void:
	_music_toggle.set_pressed_no_signal(Audio.music_on)
	_rain_toggle.set_pressed_no_signal(Audio.rain_on)
	_music_slider.set_value_no_signal(Audio.music_volume)
	_rain_slider.set_value_no_signal(Audio.rain_volume)
	_music_slider.editable = Audio.music_on
	_rain_slider.editable = Audio.rain_on
