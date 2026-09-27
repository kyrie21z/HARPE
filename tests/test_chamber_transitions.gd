extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")
const Door = preload("res://scripts/door.gd")

func _init() -> void:
	print("--- 开始测试北壁并列三门与南门入场空间衔接系统 ---")

	var main_instance = MainScene.instantiate()
	root.add_child(main_instance)

	# 等待一帧以使 Main 的 _ready() 完全执行，初始化 @onready 变量
	await process_frame

	# 1. 验证南门与北壁三门节点存在且配置正确
	var doors_node = main_instance.get_node_or_null("Doors")
	assert(doors_node != null, "Doors 容器节点必须存在")

	var door_south = doors_node.get_node_or_null("DoorSouth") as Door
	var door_left = doors_node.get_node_or_null("DoorNorthLeft") as Door
	var door_center = doors_node.get_node_or_null("DoorNorthCenter") as Door
	var door_right = doors_node.get_node_or_null("DoorNorthRight") as Door

	assert(door_south != null and door_south.direction == Door.Direction.SOUTH, "南门（入场门）配置必须正确")
	assert(door_left != null and door_left.direction == Door.Direction.NORTH, "北壁左门配置必须正确")
	assert(door_center != null and door_center.direction == Door.Direction.NORTH, "北壁中门配置必须正确")
	assert(door_right != null and door_right.direction == Door.Direction.NORTH, "北壁右门配置必须正确")
	print("✓ 1. 南向入场门与北壁并列三门节点配置验证通过")

	# 2. 验证北壁三门一字横向排开的几何坐标
	assert(door_left.position.y == door_center.position.y and door_center.position.y == door_right.position.y, "北壁三门 Y 坐标必须对齐在同一边")
	assert(door_left.position.x < door_center.position.x and door_center.position.x < door_right.position.x, "北壁三门 X 坐标必须自左向右递增")
	assert(door_center.position.x == 0.0, "中门应居中对齐在 X=0")
	print("✓ 2. 北壁三门并列排布几何坐标对齐验证通过")

	# 3. 验证南门入场漫步几何向量推导（向上/向北入场）
	var south_spawn = door_south.get_spawn_position()
	var south_target = door_south.get_entry_target_position()
	assert(south_target.y < south_spawn.y, "南门入场目标点 Y 应小于起点 Y（由南向北迈步进入室内）")
	print("✓ 3. 南门入场漫步几何向量验证通过")

	# 4. 验证北壁出口开启机制与战利品契约分配
	for test_run in range(5):
		for d in main_instance.all_doors:
			d.lock_gate()

		main_instance._open_exit_doors()

		# 南面入场门绝对不可作为出口开启
		assert(door_south.current_state == Door.State.LOCKED, "南面入场门必须保持关闭锁死")

		# 统计北壁开启的出口数量
		var open_count = 0
		var open_rewards: Array[Door.RewardType] = []
		for exit_door in main_instance.exit_doors:
			if exit_door.current_state == Door.State.OPEN:
				open_count += 1
				assert(exit_door.trigger_area.monitoring == true, "开启的出口门必须激活 TriggerArea 监听")
				assert(exit_door.reward_badge.visible == true, "开启的门必须升起神印战利品徽章")
				open_rewards.append(exit_door.reward_type)

		assert(open_count >= 1 and open_count <= 3, "北壁开启出口数必须在 1 到 3 扇之间")
		# 验证分配的战利品各不相同（无重复）
		var unique_rewards: Dictionary = {}
		for r in open_rewards:
			assert(not unique_rewards.has(r), "同时开启的多扇出口必须对应不同的战利品类型")
			unique_rewards[r] = true

	print("✓ 4. 北壁 1~3 扇出口随机开启与非重复战利品分配验证通过")

	# 5. 验证玩家输入锁定与漫步状态机安全接口
	var player = main_instance.player
	player.set_input_locked(true)
	assert(player.input_locked == true, "输入锁定应当为 true")
	player.set_input_locked(false)
	assert(player.input_locked == false, "输入锁定应当为 false")
	print("✓ 5. 角色输入锁定与漫步状态机安全接口验证通过")

	# 6. 验证生命圣杯治疗与提升生命上限接口
	var initial_hp = player.current_hp
	var initial_max = player.max_hp
	player.heal_and_boost_max_hp(40.0, 15.0)
	assert(player.max_hp == initial_max + 15.0, "最大生命值应提升 15")
	print("✓ 6. 仙馔密酒圣物回复与上限提升接口验证通过")

	print("\n★★★ 北壁并列三门与南门入场系统单元测试全部通过！ ★★★")
	quit(0)
