extends Control
## 书封面。第一眼就得是那本书，不是一个 Godot 模板。

const SERIF := "res://assets/fonts/NotoSerifSC-VF.ttf"
const SANS := "res://assets/fonts/NotoSansSC-VF.ttf"
const COVER := "res://art/scenes/ch01_s11_ice.png"

const C_PAPER := Color("efe2c9")
const C_DIM := Color("a08b6b")
const C_ACCENT := Color("c98b4b")


func _ready() -> void:
	PauseMenu.enabled = false
	for c in get_children():
		c.queue_free()
	_build()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var serif: FontFile = load(SERIF)
	var sans: FontFile = load(SANS)

	var base := ColorRect.new()
	base.color = Color("0b0907")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)

	if ResourceLoader.exists(COVER):
		var bg := TextureRect.new()
		bg.texture = load(COVER)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.modulate.a = 0.5
		add_child(bg)

	var dark := ColorRect.new()
	dark.color = Color(0.04, 0.03, 0.02, 0.55)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dark)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	center.add_child(col)

	var title := Label.new()
	title.text = "百年孤独"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", serif)
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", C_PAPER)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)

	var by := Label.new()
	by.text = "加西亚·马尔克斯　·　范晔 译"
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	by.add_theme_font_override("font", sans)
	by.add_theme_font_size_override("font_size", 14)
	by.add_theme_color_override("font_color", C_DIM)
	col.add_child(by)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 44)
	col.add_child(gap)

	var play := _menu_button("翻　开", sans)
	play.pressed.connect(func() -> void: SceneRouter.change_to(SceneRouter.STORY))
	col.add_child(play)

	var quit := _menu_button("退出", sans)
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)

	var foot := Label.new()
	foot.text = "屏幕上的每一个字都是马尔克斯写的　·　两分钟"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_override("font", sans)
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", C_DIM)
	foot.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	foot.add_theme_constant_override("outline_size", 6)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 28)
	col.add_child(gap2)
	col.add_child(foot)

	play.grab_focus()


func _menu_button(text: String, sans: FontFile) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.custom_minimum_size = Vector2(300, 44)
	b.add_theme_font_override("font", sans)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", C_ACCENT)
	b.add_theme_color_override("font_hover_color", C_PAPER)
	b.add_theme_color_override("font_focus_color", C_PAPER)
	# 去掉 Godot 默认那个方框，只留字
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	return b
