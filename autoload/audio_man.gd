extends Node
## 音频管理 —— 音量总线 + 音效播放池 + BGM 交叉淡化。
##
## 用法：
##	 AudioMan.play_sfx(preload("res://assets/audio/hit.wav"))
##	 AudioMan.play_bgm(preload("res://assets/audio/theme.ogg"))
##	 AudioMan.set_volume("SFX", 0.5)   # 0.0~1.0
##
## 音效池的意义：同一帧打中 20 个敌人也不会因为抢占同一个播放器而吞声音。

const SFX_VOICES := 16
const BGM_FADE := 1.0
const MIN_DB := -60.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _bgm_players: Array[AudioStreamPlayer] = []
var _bgm_active: int = 0
var _bgm_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()

	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "BGM"
		add_child(p)
		_bgm_players.append(p)

	apply_settings()
	EventBus.settings_changed.connect(apply_settings)


## 音效。pitch_jitter 给同一个音效加随机音高，避免连续触发听起来像机关枪。
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	if stream == null:
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## 换 BGM，旧的淡出、新的淡入。传 null 就是淡出停掉。
func play_bgm(stream: AudioStream, fade: float = BGM_FADE) -> void:
	var current := _bgm_players[_bgm_active]
	if current.stream == stream and current.playing:
		return

	var next_index := 1 - _bgm_active
	var next_player := _bgm_players[next_index]

	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true)

	if stream != null:
		next_player.stream = stream
		next_player.volume_db = MIN_DB
		next_player.play()
		_bgm_tween.tween_property(next_player, "volume_db", 0.0, fade)

	if current.playing:
		_bgm_tween.tween_property(current, "volume_db", MIN_DB, fade)
		_bgm_tween.chain().tween_callback(current.stop)

	_bgm_active = next_index


## bus_name: "Master" / "BGM" / "SFX"，linear 是 0.0~1.0 的线性音量
func set_volume(bus_name: String, linear: float) -> void:
	var key := "volume_" + bus_name.to_lower()
	SaveSystem.settings[key] = clampf(linear, 0.0, 1.0)
	SaveSystem.save_settings()


func get_volume(bus_name: String) -> float:
	return float(SaveSystem.settings.get("volume_" + bus_name.to_lower(), 1.0))


func apply_settings() -> void:
	for bus_name in ["Master", "BGM", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx == -1:
			continue
		var linear := get_volume(bus_name)
		AudioServer.set_bus_mute(idx, linear <= 0.0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _ensure_buses() -> void:
	## 新建项目默认只有 Master，这里补出 BGM / SFX 两条，省得手动配 bus layout
	for bus_name in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
