extends SceneTree

const MeleeEnemyScene = preload("res://scenes/EnemyMelee.tscn")
const RangedEnemyScene = preload("res://scenes/EnemyRanged.tscn")
const PlayerScene = preload("res://scenes/Player.tscn")

func _init() -> void:
	print("--- 开始测试怪物受击硬直（Hit Stun）与动作打断系统 ---")

	var player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame

	# ----------------------------------------------------
	# 1. 测试近战普通小怪受击打断与硬直状态
	# ----------------------------------------------------
	var melee = MeleeEnemyScene.instantiate()
	melee.position = Vector2(300, 300)
	root.add_child(melee)
	await process_frame

	print("melee.current_state: ", melee.current_state, " (State.CHASE is ", EnemyMelee.State.CHASE, ")")
	assert(melee.current_state == EnemyMelee.State.CHASE, "初始状态应为 CHASE")
	assert(not melee.is_elite, "默认为普通小怪")

	# 受到轻击 1 段伤害 (20 点，击退向右，0.22s 硬直)
	melee.take_damage(20.0, Vector2(180, 0), 0.22)
	assert(melee.current_state == EnemyMelee.State.HIT_STUN, "普通怪受击必须进入 HIT_STUN")
	assert(melee.hit_stun_timer >= 0.20, "硬直计时器应被设为 >= 0.20s")
	assert(melee.knockback_velocity.x > 0, "击退速度必须生效")
	print("✓ 1. 普通近战怪受击进入 HIT_STUN 及硬直计时验证通过")

	# ----------------------------------------------------
	# 2. 测试攻击前摇（WINDUP）被硬直立即打断
	# ----------------------------------------------------
	melee.current_state = EnemyMelee.State.WINDUP
	melee._start_attack_windup()
	assert(melee.current_state == EnemyMelee.State.WINDUP, "进入蓄力前摇状态")

	# 在前摇期间遭受轻击
	melee.take_damage(20.0, Vector2(100, 0), 0.25)
	assert(melee.current_state == EnemyMelee.State.HIT_STUN, "前摇中的普通怪受击必须被立即打断并进入 HIT_STUN")
	assert(not melee.attack_hitbox.monitoring, "打断后扑击判定框必须保持关闭")
	print("✓ 2. 近战前摇蓄力被攻击打断机制验证通过")

	# ----------------------------------------------------
	# 3. 测试连续受击硬直刷新 (Stun Refresh / 连招压制)
	# ----------------------------------------------------
	melee.current_hp = 60.0
	melee.hit_stun_timer = 0.10
	melee.take_damage(10.0, Vector2(240, 0), 0.26)
	assert(melee.hit_stun_timer >= 0.25, "连续受击时硬直时间应被刷新/延长")
	print("✓ 3. 连续受击硬直时间刷新（平砍连击压制）验证通过")

	# ----------------------------------------------------
	# 4. 测试硬直倒计时结束恢复为追逐
	# ----------------------------------------------------
	melee._physics_process(0.30)
	assert(melee.current_state == EnemyMelee.State.CHASE, "硬直结束必须自动恢复为 CHASE")
	assert(melee.hit_stun_timer == 0.0, "硬直计时器归零")
	print("✓ 4. 硬直超时后安全恢复 CHASE 验证通过")

	# ----------------------------------------------------
	# 5. 测试精英怪的霸体抵抗与破霸重击
	# ----------------------------------------------------
	var elite_melee = MeleeEnemyScene.instantiate()
	elite_melee.is_elite = true
	elite_melee.max_hp = 200.0
	elite_melee.current_hp = 200.0
	root.add_child(elite_melee)
	elite_melee.global_position = Vector2(300, 300)
	await process_frame

	# 精英怪受轻击 (stun_duration = 0.22) -> 霸体不进入 HIT_STUN
	elite_melee.take_damage(20.0, Vector2(100, 0), 0.22)
	assert(elite_melee.current_state != EnemyMelee.State.HIT_STUN, "精英怪应抵抗轻击硬直")

	# 精英怪受重斩或终结击 (stun_duration = 0.60 >= 0.40) -> 破霸进入 HIT_STUN
	elite_melee.take_damage(70.0, Vector2(500, 0), 0.60)
	assert(elite_melee.current_state == EnemyMelee.State.HIT_STUN, "精英怪受到重击破霸必须进入 HIT_STUN")
	print("✓ 5. 精英怪轻击霸体抵抗与重击破霸打断机制验证通过")

	# ----------------------------------------------------
	# 6. 测试远程怪物施法被打断与硬直
	# ----------------------------------------------------
	var ranged = RangedEnemyScene.instantiate()
	root.add_child(ranged)
	ranged.global_position = Vector2(400, 400)
	await process_frame

	ranged._start_cast_spell()
	assert(ranged.is_casting, "远程怪物进入施法蓄力状态")

	# 受击打断施法
	ranged.take_damage(20.0, Vector2(150, 0), 0.30)
	assert(ranged.hit_stun_timer >= 0.28, "远程怪物进入受击硬直计时")
	assert(not ranged.is_casting, "施法状态必须被立即打断取消")
	print("✓ 6. 远程怪蓄力施法被攻击立即打断与硬直机制验证通过")

	# 销毁测试实例
	melee.queue_free()
	elite_melee.queue_free()
	ranged.queue_free()
	player.queue_free()

	print("\n★★★ 所有怪物受击硬直与动作打断单元测试全部通过！ ★★★")
	quit(0)
