extends Node
## 大模型调用 —— OpenAI 兼容接口（火山方舟）。
##
## API key 绝不写进仓库。按顺序找：
##	 1. 环境变量 ARK_API_KEY
##	 2. 项目根的 .ark_key 文件（已在 .gitignore 里）
## 都没有的话游戏照常跑，只是对话功能会提示未配置。
##
## ⚠️ 当前 BASE 指向 Coding Plan 通道。火山官方规定该通道的 key
##	  只能在编程工具里用、不能直接调 API。要长期跑请换成按量计费的
##	  /api/v3 通道，把下面的 URL 改掉即可。

const URL := "https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions"
const MODEL := "deepseek-v4-flash"
const TIMEOUT := 60.0

var _key: String = ""

## 上一次请求耗时（毫秒），调试用
var last_ms: int = 0


func _ready() -> void:
	_key = OS.get_environment("ARK_API_KEY").strip_edges()
	if _key.is_empty() and FileAccess.file_exists("res://.ark_key"):
		var f := FileAccess.open("res://.ark_key", FileAccess.READ)
		if f != null:
			_key = f.get_as_text().strip_edges()
			f.close()
	if _key.is_empty():
		push_warning("没找到 ARK_API_KEY（环境变量或 res://.ark_key），对话功能不可用。")


func has_key() -> bool:
	return not _key.is_empty()


## 返回 {ok: bool, text: String, error: String}。可以 await。
func chat(messages: Array, max_tokens: int = 300, temperature: float = 0.85) -> Dictionary:
	if not has_key():
		return _fail("没有配置 ARK_API_KEY")

	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)

	var payload := {
		"model": MODEL,
		"messages": messages,
		"max_tokens": max_tokens,
		"temperature": temperature,
		# 关掉思考。实测：开着会多花 70~290 个 reasoning token，
		# 而角色台词只需要 20 来个 token，思考纯属浪费时间。
		"thinking": {"type": "disabled"},
	}
	var err := http.request(
		URL,
		["Content-Type: application/json", "Authorization: Bearer " + _key],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		http.queue_free()
		return _fail("请求发不出去: %s" % error_string(err))

	var t0 := Time.get_ticks_msec()
	var res: Array = await http.request_completed
	last_ms = Time.get_ticks_msec() - t0
	http.queue_free()

	var result: int = res[0]
	var code: int = res[1]
	var body: PackedByteArray = res[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		return _fail("网络失败 (result=%d)，检查网络或超时" % result)

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("返回的不是 JSON")

	if code != 200:
		var e: Dictionary = parsed.get("error", {})
		return _fail("HTTP %d: %s" % [code, e.get("message", "未知错误")])

	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		return _fail("返回里没有 choices")

	var content: String = String(choices[0].get("message", {}).get("content", "")).strip_edges()
	if content.is_empty():
		return _fail("模型返回了空内容")

	return {"ok": true, "text": content, "error": ""}


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "text": "", "error": reason}
