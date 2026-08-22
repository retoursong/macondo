extends Node
## 端到端试玩 —— 在真引擎里跑一段对话，验证 LLM 那条链是通的。
## 跑：make playtest
## 注意：会真的调模型、真的花 token。

const SCENE_INDEX := 10	  # 冰块

func _ready() -> void:
	var story: Control = load("res://scenes/story.tscn").instantiate()
	add_child(story)
	await get_tree().process_frame

	story._show_scene(SCENE_INDEX)
	var scene: Dictionary = story._scenes[SCENE_INDEX]
	print("\n场景 %d｜%s ｜ %s" % [SCENE_INDEX + 1, scene["title"], scene["place"]])
	print("在场：", ", ".join(PackedStringArray(scene["cast"])))
	print("原文 %d 字，出处：第%d章 %s\n" % [
		len("".join(PackedStringArray(scene["narration"]))),
		scene["chapter"], scene["source"]["anchor"]])
	print("原文结尾 → ...%s\n" % String(scene["narration"][-1]).substr(
		maxi(0, String(scene["narration"][-1]).length() - 60)))

	if not LLM.has_key():
		print("✗ 没有 key，跳过对话测试")
		get_tree().quit(1)
		return

	print("=".repeat(56))
	for probe in [
		{"who": "奥雷里亚诺", "say": "爸爸，它在烧。"},
		{"who": "何塞·阿尔卡蒂奥", "say": "我不想摸。有什么好摸的。"},
	]:
		var who: String = probe["who"]
		if not who in scene["cast"]:
			continue
		story._target = who
		var msgs: Array = story._build_messages(who, probe["say"])
		var sys_len: int = String(msgs[0]["content"]).length()
		print("\n▸ 你（%s）对 %s 说：%s" % [story.POV, who, probe["say"]])
		print("	 [system prompt %d 字，已含本场原文]" % sys_len)
		var t0 := Time.get_ticks_msec()
		var res: Dictionary = await LLM.chat(msgs)
		var dt := (Time.get_ticks_msec() - t0) / 1000.0
		if res["ok"]:
			print("\n  %s：%s" % [who, res["text"]])
			print("	 （%.1f 秒）" % dt)
		else:
			print("	 ✗ 失败：", res["error"])
			get_tree().quit(1)
			return
	print("\n" + "=".repeat(56))
	print("✓ 端到端通了：读数据 → 拼 prompt → HTTPRequest → 模型回话")
	get_tree().quit(0)
