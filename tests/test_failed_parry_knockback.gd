extends SceneTree

func _init() -> void:
	print("\n--- 开始测试纯瞬身零伤害、受创打断蓄力与命中无击飞机制 ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var player_scene = load("res://scenes/Player.tscn")
	var enemy_scene = load("res://scenes/EnemyMelee.tscn")

	var player = player_scene.instantiate() as Player
	var enemy = enemy_scene.instantiate() as EnemyMelee

	root.add_child(player)
	root.add_child(enemy)

	# 1. 验证 MotionMode 为 FLOATING 与 常态下 ParryBox 处于严格禁用隐匿状态
	assert(player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "玩家 motion_mode 必须为 MOTION_MODE_FLOATING")
	assert(enemy.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "近战敌人 motion_mode 必须为 MOTION_MODE_FLOATING")
	assert(player.parry_box.monitorable == false, "常态未举盾时 ParryBox.monitorable 必须为 false！")
	assert(player.is_parrying_active() == false, "常态下 is_parrying_active 必须为 false！")
	print("✓ 1. 玩家与敌人均已配置为 MOTION_MODE_FLOATING，常态下 ParryBox 处于严格禁用隐匿状态！")

	# 2. 模拟小怪攻击触碰常态下的 ParryBox：严禁被判定为弹反，小怪绝对不能被弹飞
	player.global_position = Vector2(200, 200)
	enemy.global_position = Vector2(240, 200)
	enemy.current_state = EnemyMelee.State.ATTACK
	enemy.attack_direction = Vector2.LEFT
	enemy.velocity = enemy.attack_direction * 280.0
	enemy.attack_has_hit = false
	enemy.attack_was_parried = false

	enemy._on_attack_hitbox_area_entered(player.parry_box)
	assert(enemy.attack_was_parried == false, "未举盾招架时触碰 ParryBox 绝对不能判定为弹反！")
	assert(enemy.knockback_velocity == Vector2.ZERO, "未招架时敌人击退速度必须为零，严禁被弹飞！")
	print("✓ 2. 角色未弹反时，小怪扑击触碰 ParryBox 绝不触发招架，小怪零反弹验证通过！")

	# 3. 模拟小怪攻击命中正在蓄力的角色：
	#    - 造成伤害（扣 20 HP）
	#    - 打断蓄力（is_holding_attack 与 is_charge_ready 均重置为 false）
	#    - 严禁将角色超远击飞（player_knockback_velocity 保持为 ZERO）
	player.current_hp = 100.0
	player.is_holding_attack = true
	player.is_charge_ready = true
	player.attack_hold_timer = 0.5

	enemy._on_attack_hitbox_body_entered(player)

	assert(player.current_hp == 80.0, "玩家应受到 20 点伤害，当前HP: %f" % player.current_hp)
	assert(player.is_holding_attack == false, "受击必须成功打断蓄力按住状态！")
	assert(player.is_charge_ready == false, "受击必须清空蓄力就绪标志！")
	assert(player.attack_hold_timer == 0.0, "受击必须清空蓄力计时！")
	assert(player.player_knockback_velocity == Vector2.ZERO, "普通小怪命中绝不能将角色击飞很远！当前: %v" % player.player_knockback_velocity)
	assert(enemy.knockback_velocity == Vector2.ZERO, "小怪命中玩家自身击退必须为零！")
	assert(enemy.velocity == Vector2.ZERO, "小怪命中玩家应终止冲锋速度！")
	print("✓ 3. 普通命中打断蓄力与角色零击飞验证通过：HP 扣除至 80，蓄力被打断，角色原地受创零击飞！")

	# 4. 验证纯瞬身穿过敌人绝对零伤害机制（直接瞬身绝不刮痧蹭血）
	enemy.current_hp = 60.0
	player.global_position = Vector2(200, 200)
	enemy.global_position = Vector2(230, 200)

	# 角色直接按瞬步穿透小怪 (trigger_strike = false)
	player._start_dash(Vector2.RIGHT, false)
	assert(player.dash_hitbox.monitoring == false, "纯瞬步时 DashHitbox.monitoring 必须为 false！")

	# 模拟物理步进穿过敌人身躯
	for i in range(12):
		player._physics_process(0.016)

	assert(enemy.current_hp == 60.0, "直接瞬身穿过敌人严禁造成任何伤害！当前怪物HP: %f" % enemy.current_hp)
	print("✓ 4. 直接瞬身穿透敌人零伤害验证通过：纯瞬身作为闪避位移，绝不对小怪造成碰撞伤害！")

	# 5. 验证主动操作冲刺斩（Dash-Strike）：主动出刀才造成斩击伤害
	player.current_state = Player.State.NORMAL
	player.can_dash = true
	enemy.current_hp = 60.0
	player.global_position = Vector2(200, 200)
	enemy.global_position = Vector2(230, 200)

	# 显式激活冲刺斩 (trigger_strike = true)
	player._start_dash(Vector2.RIGHT, true)
	assert(player.is_dash_striking == true, "显式触发冲刺斩应进入 is_dash_striking 状态！")

	# 触发刀光判定碰撞
	player._on_hitbox_area_entered(enemy.hurtbox)
	assert(enemy.current_hp < 60.0, "主动挥出冲刺斩必须有效造成伤害！当前怪物HP: %f" % enemy.current_hp)
	print("✓ 5. 主动冲刺斩（Dash-Strike）有效命中伤害验证通过：挥刀斩击有效削减怪物 HP 至 %.1f！" % enemy.current_hp)

	# 清理
	player.queue_free()
	enemy.queue_free()

	print("\n★★★ 纯瞬身零伤害、受创打断蓄力与命中零击飞测试全部通过！ ★★★\n")
	quit(0)
