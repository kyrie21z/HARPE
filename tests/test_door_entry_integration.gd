extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")
const Door = preload("res://scripts/door.gd")

func _init() -> void:
	print("--- 开始测试玩家实际走入石门并触发转场的完整闭环 ---")
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	# 1. 等待开局入场漫步完全完成
	await create_timer(1.0).timeout
	assert(not main.is_transitioning, "入场后转场状态应当已解除")
	assert(not main.player.input_locked, "入场后玩家输入应当已解锁")

	# 2. 模拟清场开启北壁出口
	main._open_exit_doors()

	# 找到任意一扇开启的出口门
	var target_door: Door = null
	for d in main.exit_doors:
		if d.current_state == Door.State.OPEN:
			target_door = d
			break

	assert(target_door != null, "北壁必须至少开启一扇门")
	assert(target_door.reward_badge.visible, "开启的门必须升起神明专属徽章")
	assert(target_door.trigger_area.monitoring, "开启的门必须开启 TriggerArea 监听")

	var record = {"fired": false}
	target_door.player_entered.connect(func(_d):
		record["fired"] = true
	)

	# 3. 将玩家放置在开启门正下方，向上自然走入门内
	main.player.global_position = target_door.trigger_area.global_position + Vector2(0, 50)
	print("放置玩家在开启门下方: ", main.player.global_position)

	for i in range(25):
		main.player.velocity = Vector2(0, -160)
		main.player.move_and_slide()
		await physics_frame
		if record["fired"]:
			break

	assert(record["fired"], "玩家走入门内必须成功触发 player_entered 信号！")
	assert(main.is_transitioning, "成功进门后必须进入转场状态 is_transitioning = true")
	assert(main.pending_reward == target_door.reward_type, "必须正确记录该门的战利品契约")
	print("✓ 玩家自然走入石门、触发感应、记录战利品并启动转场测试通过！")

	print("\n★★★ 石门真实进门与转场完整集成测试通过！ ★★★")
	quit(0)
