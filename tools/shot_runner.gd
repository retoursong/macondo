extends Node
## 把 V1 的几屏渲染成 png，方便直接看效果。

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	var g: Control = load("res://scenes/story.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame

	await _shot("01_opening")
	g._advance(); await _shot("02_world")
	g._advance(); g._advance(); await _shot("03_magnet")
	g._advance(); await _shot("04_melquiades")
	g._advance(); await _shot("05_choice")
	g._pick("colonel"); await _shot("06_war")
	g._advance(); g._advance(); await _shot("07_sons")
	g._advance(); g._advance(); await _shot("08_goldfish")
	g._advance(); await _shot("09_ending")
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 50:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % name)
	print("saved ", name)
