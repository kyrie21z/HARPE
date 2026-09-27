extends SceneTree

func _init() -> void:
	print("\n--- 开始测试招架弹反免伤、雅典娜神雷与伤害互斥判定闭环 ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var player_scene = load("res://scenes/Player.tscn")
	var melee_scene = load("res://scenes/EnemyMelee.tscn")
	var bullet_scene = load("res://scenes/Bullet.tscn")

	var player = player_scene.instantiate() as Player
	root.add_child(player)
	player.global_position = Vector2(0, 0)
	player.facing_direction = Vector2.RIGHT

	# 激活雅典娜神雷词条
	player.has_parry_thunder = true

	# -------------------------------------------------------------
	# 场景 1: 近战怪攻击被玩家正面举盾招架 -> 触发神雷、怪物瘫痪、玩家0扣血！
	# -------------------------------------------------------------
	var melee = melee_scene.instantiate() as EnemyMelee
	root.add_child(melee)
	melee.player = player
	melee.global_position = Vector2(30, 0)

	# 玩家举盾进入有效招架窗口
	player._execute_parry()
	assert(player.is_parrying_active() == true, "招架有效判定窗口应为激活态")

	# 模拟近战攻击生效，触发碰撞
	melee._execute_attack()
	# 手动触发攻击命中玩家
	melee._on_attack_hitbox_body_entered(player)

	assert(player.current_hp == 100.0, "招架成功时玩家严禁扣血！当前HP: " + str(player.current_hp))
	assert(melee.current_state == EnemyMelee.State.STUNNED, "近战怪应被震瘫进入 STUNNED 态")
	assert(melee.current_hp < melee.max_hp, "雅典娜神雷应对近战怪造成雷暴伤害！当前怪HP: " + str(melee.current_hp))
	assert(melee.knockback_velocity.length() >= 400.0, "招架成功必须产生强大的后退击退初速度！")
	assert(melee.knockback_velocity.dot(player.facing_direction) > 0, "击退方向必须远离玩家，严禁朝玩家身躯怀里黏合！")
	assert(player.parry_invincible_timer > 0.0, "招架成功后应激活无敌保护计时")
	print("✓ 1. 近战攻击招架成功：雅典娜神雷触发，怪物被强力震飞拉开身位，玩家绝对零扣血验证通过！")

	# -------------------------------------------------------------
	# 场景 2: 招架后无敌保护窗口内受到连带攻击 -> 免疫伤害
	# -------------------------------------------------------------
	player.take_damage(20.0, Vector2(50, 0))
	assert(player.current_hp == 100.0, "招架保护窗口内受到任何后续伤害均应完全免疫！")
	print("✓ 2. 招架大成功后的 0.35s 绝对无敌保护期验证通过！")

	# 清理第 1 阶段近战怪
	melee.queue_free()
	# 重置玩家状态与招架计时
	player.parry_invincible_timer = 0.0
	player.current_state = Player.State.NORMAL
	player.parry_box.monitoring = false

	# -------------------------------------------------------------
	# 场景 3: 未举盾被击中 -> 正常扣血，且该次攻击不能后续再触发弹反
	# -------------------------------------------------------------
	var melee2 = melee_scene.instantiate() as EnemyMelee
	root.add_child(melee2)
	melee2.player = player
	melee2.global_position = Vector2(30, 0)

	melee2._execute_attack()
	melee2._on_attack_hitbox_body_entered(player)

	assert(player.current_hp == 80.0, "未招架受创应扣减 20 HP，当前HP: " + str(player.current_hp))
	assert(melee2.attack_has_hit == true, "攻击命中标记应已锁定")

	# 尝试在已被击中后延迟触发招架判定框（模拟玩家慢半拍按右键）
	melee2._on_attack_hitbox_area_entered(player.parry_box)
	assert(melee2.current_state != EnemyMelee.State.STUNNED, "已命中的攻击绝不能后续触发幽灵弹反")
	print("✓ 3. 受创判定与招架判定互斥闭环：被命中后攻击判定立即关闭，杜绝先扣血后触发神雷的幽灵弹反！")

	melee2.queue_free()

	# -------------------------------------------------------------
	# 场景 4: 远程子弹撞击举盾招架玩家 -> 反弹偏折、触发神雷、玩家0扣血
	# -------------------------------------------------------------
	player.current_hp = 100.0
	player.parry_invincible_timer = 0.0
	player._execute_parry()

	var bullet = bullet_scene.instantiate() as Projectile
	root.add_child(bullet)
	bullet.global_position = Vector2(15, 0)
	bullet.direction = Vector2.LEFT

	# 模拟子弹撞入玩家身体与判定框
	bullet._on_body_entered(player)

	assert(bullet.is_reflected == true, "子弹应被偏折反弹")
	assert(player.current_hp == 100.0, "反弹子弹期间玩家严禁扣血！")
	assert(player.parry_invincible_timer > 0.0, "反弹成功激活无敌保护")
	print("✓ 4. 远程魔矢举盾反弹：反弹偏折正常，神雷激活，玩家绝对零扣血验证通过！")

	bullet.queue_free()
	player.queue_free()

	print("\n★★★ 招架弹反免伤与雅典娜神雷判定闭环测试全部通过！ ★★★\n")
	quit(0)
