extends Node
## 存档 + 设置持久化（JSON 存在 user:// 下）。
## macOS 实际路径：~/Library/Application Support/Godot/app_userdata/Godot Lab/
## 想看存档：在编辑器里 项目 → 打开用户数据文件夹。

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"

const DEFAULT_SAVE := {
	"best_score": 0,
	"total_runs": 0,
}

const DEFAULT_SETTINGS := {
	"volume_master": 1.0,
	"volume_bgm": 0.8,
	"volume_sfx": 1.0,
	"fullscreen": false,
}

var data: Dictionary = {}
var settings: Dictionary = {}


func _ready() -> void:
	load_settings()
	load_game()


# --- 设置 ---

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	_merge(settings, _read_json(SETTINGS_PATH))


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)
	EventBus.settings_changed.emit()


# --- 存档 ---

func load_game() -> void:
	data = DEFAULT_SAVE.duplicate(true)
	_merge(data, _read_json(SAVE_PATH))


func save_game() -> void:
	_write_json(SAVE_PATH, data)


func record_best_score(value: int) -> void:
	data["total_runs"] = int(data.get("total_runs", 0)) + 1
	if value > int(data.get("best_score", 0)):
		data["best_score"] = value
	save_game()


func wipe() -> void:
	## 调试用：清掉存档回到初始状态
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	load_game()


# --- 内部 ---

func _merge(target: Dictionary, source: Dictionary) -> void:
	## 只覆盖已知键，这样以后加字段不会被旧存档带崩
	for key in source:
		if target.has(key):
			target[key] = source[key]


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("读不了 %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("%s 内容不是合法 JSON 对象，已忽略" % path)
	return {}


func _write_json(path: String, dict: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("写不了 %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(dict, "\t"))
	f.close()
