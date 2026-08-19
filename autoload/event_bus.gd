extends Node
## 全局信号总线 —— 让互不认识的模块通信。
##
## 为什么要有它：不然你会写出 get_node("../../UI/HUD/Label") 这种一改结构就全断的代码。
## 发送：EventBus.score_changed.emit(120)
## 接收：EventBus.score_changed.connect(_on_score_changed)
##
## 定了题材之后，下面这些信号照着删改就行，它们只是起手示例。

# --- 流程 ---
signal game_started
signal game_over(reason: String)

# --- 玩家 ---
signal player_spawned(player: Node)
signal player_damaged(amount: int, current_hp: int)
signal player_died

# --- 数值 ---
signal score_changed(new_score: int)

# --- 系统 ---
signal scene_will_change(path: String)
signal scene_changed(path: String)
signal settings_changed
