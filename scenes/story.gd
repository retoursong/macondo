extends Control
## 《百年孤独》V1 —— 两分钟，一条支线，一个结局。
##
## 铁律没变：屏幕上的正文一个字都不是我写的，全是范晔译本原文
## （tools/verify_verbatim.py 逐字校验）。我只做减法和排布。
##
## 流程：开场一句 → 共同开头四屏 → 羊皮卷上选一条 → 那个人的一生 → 他的结局。
## 玩家不参与剧情（那是 V2）。图铺满，字很短，慢慢淡。

const DATA_PATH := "res://data/game.json"
const ART_DIR := "res://art/"
const SERIF := "res://assets/fonts/NotoSerifSC-VF.ttf"
const SANS := "res://assets/fonts/NotoSansSC-VF.ttf"

const C_PAPER := Color("efe4cf")
const C_DIM := Color("a08b6b")
const C_ACCENT := Color("d99a52")
const C_OFF := Color("6b5b45")

const FADE := 0.65      # 换图淡入淡出
const TEXT_FADE := 0.5  # 文字淡入

enum Phase { STORY, CHOICE, ENDING }

var _data: Dictionary = {}
var _seq: Array = []
var _i: int = 0
var _phase: int = Phase.STORY
var _branch_key: String = ""
var _in_branch: bool = false
var _art_cache: Dictionary = {}
var _choice_buttons: Array = []

var _serif: FontFile
var _sans: FontFile

var _bg: TextureRect
var _bg_old: TextureRect
var _scrim: TextureRect
var _dark: ColorRect
var _text: RichTextLabel
var _sub: Label
var _hint: Label
var _choice_box: VBoxContainer
var _prompt: Label
var _again: Button


func _ready() -> void:
	PauseMenu.enabled = true
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("找不到 %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("game.json 不是合法 JSON")
		return
	_data = parsed
	_serif = load(SERIF)
	_sans = load(SANS)
	_build_ui()
	_play_bgm()
	_start()


## assets/audio/ 里放了曲子就自动循环播放，没放就安静。
func _play_bgm() -> void:
	var dir := DirAccess.open("res://assets/audio")
	if dir == null:
		return
	for f in dir.get_files():
		var clean := f.trim_suffix(".import")
		if not clean.get_extension().to_lower() in ["ogg", "mp3", "wav"]:
			continue
		var stream: AudioStream = load("res://assets/audio/" + clean)
		if stream == null:
			continue
		if "loop" in stream:
			stream.set("loop", true)
		AudioMan.play_bgm(stream, 2.5)
		return


func _start() -> void:
	_phase = Phase.STORY
	_in_branch = false
	_branch_key = ""
	_seq = [_data.get("opening", {})]
	for s in _data.get("prologue", []):
		_seq.append(s)
	_i = 0
	_render()


# ---------- 渲染 ----------

func _art(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _art_cache.has(path):
		return _art_cache[path]
	# 插画统一存 jpg（铜版画用 png 太占地方），老的 png 也认
	for ext in [".jpg", ".png"]:
		var full: String = ART_DIR + path + String(ext)
		if ResourceLoader.exists(full):
			var tex: Texture2D = load(full)
			_art_cache[path] = tex
			return tex
	return null


## 换图：淡入淡出，别硬切
func _set_art(tex: Texture2D) -> void:
	if tex == null or tex == _bg.texture:
		return
	_bg_old.texture = _bg.texture
	_bg_old.modulate.a = 1.0 if _bg_old.texture != null else 0.0
	_bg.texture = tex
	if _bg_old.texture != null:
		create_tween().tween_property(_bg_old, "modulate:a", 0.0, FADE)


func _font_size_for(n: int) -> int:
	if n <= 16:
		return 46
	elif n <= 26:
		return 40
	elif n <= 40:
		return 34
	return 29


func _show_line(line: String) -> void:
	_text.clear()
	if line.strip_edges().is_empty():
		_text.modulate.a = 0.0
		return
	_text.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	_text.push_font(_serif)
	_text.push_font_size(_font_size_for(line.length()))
	_text.push_color(C_PAPER)
	_text.append_text(line)
	_text.pop(); _text.pop(); _text.pop(); _text.pop()
	_text.modulate.a = 0.0
	create_tween().tween_property(_text, "modulate:a", 1.0, TEXT_FADE)


func _render() -> void:
	_phase = Phase.STORY
	_choice_box.visible = false
	_prompt.visible = false
	_again.visible = false
	_sub.visible = false
	_dark.color = Color(0.04, 0.03, 0.02, 0.28)
	var screen: Dictionary = _seq[_i]
	_set_art(_art(String(screen.get("art", ""))))
	_show_line(String(screen.get("text", "")))
	_hint.visible = _i == 0 and not _in_branch
	_hint.text = "点一下"


func _advance() -> void:
	if _phase != Phase.STORY:
		return
	if _i < _seq.size() - 1:
		_i += 1
		_render()
	elif _in_branch:
		_show_ending()
	else:
		_show_choice()


func _back() -> void:
	if _phase == Phase.STORY and _i > 0:
		_i -= 1
		_render()


# ---------- 选择 ----------

func _show_choice() -> void:
	_phase = Phase.CHOICE
	var c: Dictionary = _data.get("choice", {})
	_set_art(_art(String(c.get("art", ""))))
	_dark.color = Color(0.04, 0.03, 0.02, 0.62)
	_show_line(String(c.get("quote", "")))
	_hint.visible = false
	_prompt.visible = true
	_prompt.text = String(c.get("prompt", ""))
	_choice_box.visible = true
	for ch in _choice_box.get_children():
		ch.queue_free()
	_choice_buttons.clear()

	var branches: Dictionary = _data.get("branches", {})
	var n := 0
	for opt in c.get("options", []):
		var key := String(opt.get("key", ""))
		var ready_: bool = branches.has(key)
		n += 1
		var b := Button.new()
		b.text = "%d　%s%s" % [n, String(opt.get("label", "")), "" if ready_ else "　（还没画完）"]
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.flat = true
		b.disabled = not ready_
		b.focus_mode = Control.FOCUS_ALL if ready_ else Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(520, 40)
		b.add_theme_font_override("font", _serif)
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_color_override("font_color", C_PAPER if ready_ else C_OFF)
		b.add_theme_color_override("font_hover_color", C_ACCENT)
		b.add_theme_color_override("font_focus_color", C_ACCENT)
		b.add_theme_color_override("font_disabled_color", C_OFF)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.35)
		box.border_color = C_ACCENT
		box.border_width_left = 3
		box.content_margin_left = 8
		b.add_theme_stylebox_override("focus", box)
		b.add_theme_stylebox_override("hover", box)
		if ready_:
			b.pressed.connect(_pick.bind(key))
			_choice_buttons.append(b)
		_choice_box.add_child(b)
	if not _choice_buttons.is_empty():
		(_choice_buttons[0] as Button).call_deferred("grab_focus")


func _pick(key: String) -> void:
	_branch_key = key
	var br: Dictionary = _data.get("branches", {}).get(key, {})
	_seq = br.get("screens", [])
	_i = 0
	_in_branch = true
	_render()


# ---------- 结局 ----------

func _show_ending() -> void:
	_phase = Phase.ENDING
	var br: Dictionary = _data.get("branches", {}).get(_branch_key, {})
	var e: Dictionary = br.get("ending", {})
	_set_art(_art(String(e.get("art", ""))))
	_dark.color = Color(0.04, 0.03, 0.02, 0.55)
	_show_line(String(e.get("text", "")))
	_hint.visible = false
	_choice_box.visible = false
	_prompt.visible = false
	_sub.visible = true
	_sub.text = "你活成了他。\n%s　·　%s" % [String(br.get("who", "")), String(br.get("tag", ""))]
	_sub.modulate.a = 0.0
	create_tween().tween_property(_sub, "modulate:a", 1.0, 1.0).set_delay(0.9)
	_again.visible = true
	_again.modulate.a = 0.0
	create_tween().tween_property(_again, "modulate:a", 1.0, 0.8).set_delay(1.6)
	_again.call_deferred("grab_focus")


# ---------- 输入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.CHOICE:
		if event is InputEventKey:
			var k := event as InputEventKey
			if k.pressed and not k.echo and k.keycode >= KEY_1 and k.keycode <= KEY_7:
				var idx: int = k.keycode - KEY_1
				var opts: Array = _data.get("choice", {}).get("options", [])
				if idx < opts.size():
					var key := String(opts[idx].get("key", ""))
					if _data.get("branches", {}).has(key):
						get_viewport().set_input_as_handled()
						_pick(key)
		return
	if _phase == Phase.ENDING:
		return

	var fwd: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right")
	var back: bool = event.is_action_pressed("ui_left")
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				fwd = true
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				back = true
	if event is InputEventKey:
		var kb := event as InputEventKey
		if kb.pressed and not kb.echo and kb.keycode == KEY_BACKSPACE:
			back = true

	if fwd:
		get_viewport().set_input_as_handled()
		_advance()
	elif back:
		get_viewport().set_input_as_handled()
		_back()


# ---------- 界面 ----------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var base := ColorRect.new()
	base.color = Color("0a0806")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_bg = _full_image()
	add_child(_bg)
	_bg_old = _full_image()
	_bg_old.modulate.a = 0.0
	add_child(_bg_old)

	_dark = ColorRect.new()
	_dark.color = Color(0.04, 0.03, 0.02, 0.28)
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dark)

	# 底部渐变，保证压在画上的字读得出来
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 4
	gt.height = 256
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_scrim = TextureRect.new()
	_scrim.texture = gt
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_scrim.anchor_top = 0.42
	_scrim.offset_top = 0
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 150)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 56)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_constant_override("line_separation", 16)
	_text.add_theme_constant_override("outline_size", 8)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)

	# 羊皮卷那屏的说明字：黑体、暖灰，跟原文明显不是一路
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font", _sans)
	_prompt.add_theme_font_size_override("font_size", 15)
	_prompt.add_theme_color_override("font_color", C_DIM)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.visible = false
	col.add_child(_prompt)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 4)
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.visible = false
	col.add_child(_choice_box)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_override("font", _sans)
	_sub.add_theme_font_size_override("font_size", 16)
	_sub.add_theme_color_override("font_color", C_ACCENT)
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_sub.add_theme_constant_override("outline_size", 6)
	_sub.visible = false
	col.add_child(_sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	_again = Button.new()
	_again.text = "再来一次"
	_again.flat = true
	_again.custom_minimum_size = Vector2(220, 40)
	_again.add_theme_font_override("font", _sans)
	_again.add_theme_font_size_override("font_size", 16)
	_again.add_theme_color_override("font_color", C_PAPER)
	_again.add_theme_color_override("font_hover_color", C_ACCENT)
	_again.add_theme_color_override("font_focus_color", C_ACCENT)
	_again.visible = false
	_again.pressed.connect(_start)
	row.add_child(_again)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", _sans)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", C_OFF)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -34
	_hint.offset_bottom = -14
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _full_image() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
