extends SceneTree
## 阶段1（引导）：只造 scaffold.tscn 这一个壳。
##
## `godot --script foo.gd` 不会实例化 autoload，所以任何引用 EventBus/SaveSystem
## 的脚本在这个模式下都编译不过。scaffold_runner.gd 特意不引用 autoload，
## 所以只有它能在这一步被包壳；其余工具场景由阶段2（场景模式）去生成。

func _init() -> void:
	var root := Node.new()
	root.name = "ToolRunner"
	root.set_script(load("res://tools/scaffold_runner.gd"))
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, "res://tools/scaffold.tscn")
	if err == OK:
		print("  ✓ res://tools/scaffold.tscn")
	else:
		push_error("造壳失败: " + error_string(err))
	root.free()
	quit()
