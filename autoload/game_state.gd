extends Node
## 运行时状态 —— 只放「这一局」的数据。
## 需要关掉游戏还留着的东西（最高分、解锁、设置）走 SaveSystem。

var score: int = 0:
	set(value):
		if score == value:
			return
		score = value
		EventBus.score_changed.emit(score)

## 这一局是否进行中（区别于 get_tree().paused，那个是暂停）
var is_running: bool = false


func start_run() -> void:
	reset()
	is_running = true
	EventBus.game_started.emit()


func end_run(reason: String = "") -> void:
	if not is_running:
		return
	is_running = false
	SaveSystem.record_best_score(score)
	EventBus.game_over.emit(reason)


func reset() -> void:
	score = 0
