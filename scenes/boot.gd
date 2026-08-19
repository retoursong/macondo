extends Node
## 启动场景 —— 全游戏的第一站。
## 以后要做「加载资源 / 检查存档版本 / 播 logo 动画」都放这。

func _ready() -> void:
	PauseMenu.enabled = false
	# 占位：假装在加载。真有东西要加载时换成 ResourceLoader 的后台加载。
	await get_tree().create_timer(0.15).timeout
	SceneRouter.change_to(SceneRouter.MAIN_MENU)
