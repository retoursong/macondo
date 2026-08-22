extends Control
## 故事播放器 —— 古籍插图页布局。
##
## 铁律没变：原文是剧本、是权威；AI 只回应你的自由输入。
## 但视觉上改成了"书"：插画铺底，文字在羊皮纸面板里，正文用宋体。
##
## 两个状态：
##   READING —— 读原文，一页 150 字左右，空格/点击翻页
##   TALKING —— 原文读完，出现 3 个可点的话 + 自己说

const SCENES_PATH := "res://data/scenes_ch01.json"
const CHARS_PATH := "res://data/characters.json"
const ART_DIR := "res://art/scenes/"
const POV := "何塞·阿尔卡蒂奥·布恩迪亚"

const SERIF := "res://assets/fonts/NotoSerifSC-VF.ttf"
const SANS := "res://assets/fonts/NotoSansSC-VF.ttf"

const PAGE_CHARS := 150

# 羊皮纸配色，跟铜版画的褐色调对齐
const C_PAPER   := Color("f2e7d2")
const C_INK     := Color("2a2118")
const C_ACCENT  := Color("8c5a2b")
const C_DIM     := Color("796b56")
const C_YOU     := Color("4a5f6b")
const C_ERR     := Color("9c3a2c")

enum State { READING, TALKING }

var _scenes: Array = []
var _chars: Dictionary = {}
var _rules: Array = []

var _index: int = 0
var _state: State = State.READING
var _pages: Array = []
var _page: int = 0
var _target: String = ""
var _history: Dictionary = {}
var _choices: Array = []
var _busy: bool = false

var _serif: FontFile
var _sans: FontFile

var _bg: TextureRect
var _vignette: ColorRect
var _title: Label
var _place: Label
var _text: RichTextLabel
var _pager: Label
var _hint: Label
var _talk: VBoxContainer
var _who_label: Label
var _choice_box: VBoxContainer
var _log: RichTextLabel
var _input: LineEdit
var _next: Button


func _ready() -> void:
	PauseMenu.enabled = true
	if not _load_data():
		return
	_serif = load(SERIF)
	_sans = load(SANS)
	_build_ui()
	_show_scene(0)


func _load_data() -> bool:
	var s: Variant = _read_json(SCENES_PATH)
	var c: Variant = _read_json(CHARS_PATH)
	if s == null or c == null:
		return false
	_scenes = s.get("scenes", [])
	_chars = c.get("characters", {})
	_rules = c.get("_shared_rules", [])
	return not _scenes.is_empty()


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("找不到 %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else null


# ---------- 分页 ----------

func _split_sentences(text: String) -> Array:
	var out: Array = []
	var buf := ""
	var i := 0
	while i < text.length():
		buf += text[i]
		if text[i] in ["。", "！", "？"]:
			while i + 1 < text.length() and text[i + 1] in ["”", "」", "’"]:
				i += 1
				buf += text[i]
			out.append(buf)
			buf = ""
		i += 1
	if not buf.is_empty():
		out.append(buf)
	return out


func _paginate(paras: Array) -> Array:
	## 按句子边界切页，绝不切断句子
	var pages: Array = []
	var buf := ""
	for para in paras:
		for s in _split_sentences(String(para)):
			if not buf.is_empty() and buf.length() + s.length() > PAGE_CHARS:
				pages.append(buf)
				buf = ""
			buf += s
		if buf.length() >= int(PAGE_CHARS * 0.55):
			pages.append(buf)
			buf = ""
	if not buf.strip_edges().is_empty():
		pages.append(buf)
	return pages


# ---------- 场景 ----------

func _show_scene(index: int) -> void:
	_index = clampi(index, 0, _scenes.size() - 1)
	var scene: Dictionary = _scenes[_index]

	_history.clear()
	_choices.clear()
	_log.clear()
	# 一条 beat = 一页。没有 beats 才退回去切原文。
	_pages = scene.get("beats", [])
	if _pages.is_empty():
		_pages = _paginate(scene.get("narration", []))
	_page = 0
	_state = State.READING

	_title.text = "%s" % scene.get("title", "")
	_place.text = "%d / %d　·　%s" % [_index + 1, _scenes.size(), scene.get("place", "")]

	# 插画（没有就留空，不报错）
	var art := ART_DIR + "%s_*.png" % scene.get("id", "")
	_bg.texture = _find_art(String(scene.get("id", "")))

	# 挑一个可对话的人
	_target = ""
	for name in scene.get("cast", []):
		if String(name) != POV and _chars.has(name):
			_target = String(name)
			break

	_render_page()
	if not _target.is_empty():
		_prefetch_choices()


func _find_art(scene_id: String) -> Texture2D:
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		return null
	for f in dir.get_files():
		if f.begins_with(scene_id) and f.ends_with(".png"):
			return load(ART_DIR + f)
	return null


func _render_page() -> void:
	_text.clear()
	_text.push_font(_serif)
	_text.push_font_size(30)
	_text.push_color(C_INK)
	_text.append_text(String(_pages[_page]) if _page < _pages.size() else "")
	_text.pop()
	_text.pop()
	_text.pop()

	var dots := ""
	for i in _pages.size():
		dots += "●" if i == _page else "○"
	_pager.text = "%s　%d/%d" % [dots, _page + 1, _pages.size()]

	var last := _page >= _pages.size() - 1
	_hint.visible = true
	_hint.text = "空格 / 点击　继续读" if not last else "空格 / 点击　读完了"
	_talk.visible = false
	_next.visible = false


func _enter_talking() -> void:
	_state = State.TALKING
	_hint.visible = false
	_pager.text = ""
	_text.clear()
	_text.push_font(_serif)
	_text.push_font_size(17)
	_text.push_color(C_DIM)
	_text.append_text(String(_pages[-1]) if not _pages.is_empty() else "")
	_text.pop(); _text.pop(); _text.pop()

	_talk.visible = true
	_next.visible = true
	_next.text = "第一章完" if _index >= _scenes.size() - 1 else "继续 →"
	_next.disabled = _index >= _scenes.size() - 1
	_who_label.text = ("对　%s　说" % _target) if not _target.is_empty() else "这一段只有你自己"
	_render_choices()


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.READING:
		return
	var go: bool = event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		go = go or (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT)
	if not go:
		return
	get_viewport().set_input_as_handled()
	if _page < _pages.size() - 1:
		_page += 1
		_render_page()
	else:
		_enter_talking()


# ---------- 选项 ----------

func _prefetch_choices() -> void:
	## 你在读原文的时候后台就把选项生成好了，读完正好是现成的
	if not LLM.has_key():
		return
	var scene: Dictionary = _scenes[_index]
	var prompt := "下面是《百年孤独》第一章的一段原文。玩家正在扮演%s，此刻要对%s说话。\n\n" % [POV, _target]
	prompt += "原文：\n%s\n\n" % "\n".join(PackedStringArray(scene.get("narration", [])))
	prompt += "请写出玩家此刻可能想说的 3 句话。要求：\n"
	prompt += "1. 每句 8~18 字，是口语，是这个时代的人会说的话\n"
	prompt += "2. 三句朝不同方向：一句问事实，一句带情绪，一句推动行动\n"
	prompt += "3. 必须贴着上面这段原文，不要问原文里没有的事\n"
	prompt += "只输出 3 行，每行一句，不要编号、不要引号、不要任何解释。"

	var res: Dictionary = await LLM.chat([{"role": "user", "content": prompt}], 200, 1.0)
	if not res["ok"]:
		return
	var got: Array = []
	for line in String(res["text"]).split("\n"):
		var t := String(line).strip_edges().lstrip("0123456789.、) ").strip_edges()
		if t.length() >= 4:
			got.append(t)
	_choices = got.slice(0, 3)
	if _state == State.TALKING:
		_render_choices()


func _render_choices() -> void:
	for c in _choice_box.get_children():
		c.queue_free()
	if _target.is_empty():
		return

	for line in _choices:
		_choice_box.add_child(_make_choice(String(line), func() -> void: _say(String(line))))

	if _choices.is_empty():
		var wait := Label.new()
		wait.text = "……（正在想你可能会说什么）"
		wait.add_theme_color_override("font_color", C_DIM)
		wait.add_theme_font_override("font", _sans)
		wait.add_theme_font_size_override("font_size", 14)
		_choice_box.add_child(wait)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_input = LineEdit.new()
	_input.placeholder_text = "…或者自己说点什么"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.add_theme_font_override("font", _sans)
	_input.add_theme_font_size_override("font_size", 15)
	_input.text_submitted.connect(func(t: String) -> void: _say(t))
	row.add_child(_input)
	_choice_box.add_child(row)


func _make_choice(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "──　" + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_font_override("font", _sans)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", C_ACCENT)
	b.add_theme_color_override("font_hover_color", C_INK)
	b.pressed.connect(cb)
	return b


# ---------- 说话 ----------

func _say(said: String) -> void:
	said = said.strip_edges()
	if said.is_empty() or _target.is_empty() or _busy:
		return
	_busy = true
	if is_instance_valid(_input):
		_input.text = ""
		_input.editable = false

	_log.push_font(_sans); _log.push_font_size(15)
	_log.push_color(C_YOU)
	_log.append_text("\n你：%s\n" % said)
	_log.pop(); _log.pop(); _log.pop()

	var res: Dictionary = await LLM.chat(_build_messages(_target, said))

	_log.push_font(_sans); _log.push_font_size(15)
	if res["ok"]:
		_remember(_target, said, String(res["text"]))
		_log.push_color(C_ACCENT); _log.append_text("%s：" % _target); _log.pop()
		_log.push_color(C_INK); _log.append_text(String(res["text"]) + "\n"); _log.pop()
	else:
		_log.push_color(C_ERR)
		_log.append_text("[ 说不出话：%s ]\n" % res["error"])
		_log.pop()
	_log.pop(); _log.pop()

	_busy = false
	if is_instance_valid(_input):
		_input.editable = true
		_input.grab_focus()


func _build_messages(who: String, said: String) -> Array:
	var card: Dictionary = _chars[who]
	var scene: Dictionary = _scenes[_index]
	var sys := "你在扮演《百年孤独》里的%s。\n\n【你是谁】\n%s\n\n【你怎么说话】\n%s\n\n" % [
		who,
		"\n".join(PackedStringArray(card.get("brief", []))),
		String(card.get("voice", "")),
	]
	sys += "【此刻】\n地点：%s。下面是描写此刻情形的原文，一切以它为准，不要脑补原文里没有的事：\n\n%s\n\n" % [
		String(scene.get("place", "")),
		"\n".join(PackedStringArray(scene.get("narration", []))),
	]
	sys += "【硬规则】\n"
	for i in _rules.size():
		sys += "%d. %s\n" % [i + 1, String(_rules[i])]
	sys += "\n跟你说话的是%s。" % POV

	var msgs: Array = [{"role": "system", "content": sys}]
	for turn in _history.get(who, []):
		msgs.append({"role": "user", "content": "（%s说）%s" % [POV, turn["said"]]})
		msgs.append({"role": "assistant", "content": turn["reply"]})
	msgs.append({"role": "user", "content": "（%s说）%s" % [POV, said]})
	return msgs


func _remember(who: String, said: String, reply: String) -> void:
	if not _history.has(who):
		_history[who] = []
	_history[who].append({"said": said, "reply": reply})


# ---------- 界面 ----------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var base := ColorRect.new()
	base.color = Color("120f0b")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_bg = TextureRect.new()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# 压暗底部，让面板浮起来
	_vignette = ColorRect.new()
	_vignette.color = Color(0.07, 0.06, 0.04, 0.35)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 34)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# 顶部标题（压在图上，用描边保证可读）
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_title = _plate_label(26, C_PAPER)
	head.add_child(_title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_place = _plate_label(14, Color("c9b998"))
	head.add_child(_place)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grow)

	# 羊皮纸面板
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(C_PAPER.r, C_PAPER.g, C_PAPER.b, 0.95)
	sb.border_color = Color("6b563a")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 24
	sb.content_margin_bottom = 20
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	col.add_child(panel)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 96)
	_text.add_theme_constant_override("line_separation", 12)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_text)

	var pagerow := HBoxContainer.new()
	inner.add_child(pagerow)
	_pager = Label.new()
	_pager.add_theme_color_override("font_color", C_DIM)
	_pager.add_theme_font_size_override("font_size", 12)
	pagerow.add_child(_pager)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pagerow.add_child(sp2)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", C_DIM)
	_hint.add_theme_font_size_override("font_size", 12)
	pagerow.add_child(_hint)

	# 对话区（读完才出现）
	_talk = VBoxContainer.new()
	_talk.add_theme_constant_override("separation", 8)
	_talk.visible = false
	inner.add_child(_talk)

	_talk.add_child(HSeparator.new())

	_who_label = Label.new()
	_who_label.add_theme_color_override("font_color", C_DIM)
	_who_label.add_theme_font_override("font", _sans)
	_who_label.add_theme_font_size_override("font_size", 13)
	_talk.add_child(_who_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	_talk.add_child(_choice_box)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 120)
	_log.add_theme_constant_override("line_separation", 4)
	_talk.add_child(_log)

	var footer := HBoxContainer.new()
	_talk.add_child(footer)
	var sp3 := Control.new()
	sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(sp3)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(130, 36)
	_next.add_theme_font_override("font", _sans)
	_next.pressed.connect(func() -> void: _show_scene(_index + 1))
	footer.add_child(_next)


func _plate_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _serif)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 7)
	return l
