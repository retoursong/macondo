extends Control
## 主菜单。节点树在编辑器里可见可拖，逻辑在这里连。

@onready var _stats: Label = $Center/VBox/Stats
@onready var _play_button: Button = $Center/VBox/PlayButton
@onready var _quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	PauseMenu.enabled = false
	_stats.text = "最高分 %d   ·   已玩 %d 局" % [
		SaveSystem.data.get("best_score", 0),
		SaveSystem.data.get("total_runs", 0),
	]
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_play_button.grab_focus()


func _on_play_pressed() -> void:
	SceneRouter.change_to(SceneRouter.SANDBOX)


func _on_quit_pressed() -> void:
	get_tree().quit()
