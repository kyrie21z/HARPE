extends CharacterBody2D
class_name EnemyMelee

signal defeated(enemy: Node2D)

enum State {
	CHASE,     ## 追逐玩家
	WINDUP,    ## 蓄势预警前摇（红光闪烁，诱导弹反）
	ATTACK,    ## 扑击判定生效
	RECOVERY,  ## 攻击后摇硬直
	STUNNED,   ## 弹反破势瘫痪状态（受易伤 1.4 秒）
	HIT_STUN   ## 受击打断硬直状态（被普通攻击击中，中断招式并后仰抽搐僵直）
}

var current_state: State = State.CHASE

@export var max_hp: float = 60.0
var current_hp: float = 60.0

@export var move_speed: float = 120.0
@export var attack_range: float = 75.0
@export var is_elite: bool = false

var player: Player = null
var knockback_velocity: Vector2 = Vector2.ZERO
var attack_direction: Vector2 = Vector2.ZERO

var hit_stun_timer: float = 0.0
var flinch_tween: Tween = null
var windup_tween: Tween = null
var claw_tween: Tween = null
var attack_has_hit: bool = false
var attack_was_parried: bool = false

@onready var visuals: Node2D = $Visuals
@onready var body_mesh: Polygon2D = $Visuals/Body
@onready var claws: Node2D = $Visuals/Claws
@onready var attack_hitbox: Area2D = $Visuals/AttackHitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var hp_bar: ProgressBar = $HPBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_dead: bool = false

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	current_hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hurtbox.add_to_group("enemy_hurtbox")
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	# 击退阻尼衰减（受到击退推挤时匀减速滑动）
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		velocity = knockback_velocity
	else:
		velocity = Vector2.ZERO

	# 受击硬直计时监控（硬直期间完全无法移动、转向或发起攻击）
	if current_state == State.HIT_STUN:
		hit_stun_timer -= delta
		if hit_stun_timer <= 0.0:
			hit_stun_timer = 0.0
			current_state = State.CHASE
		move_and_slide()
		return

	if knockback_velocity != Vector2.ZERO:
		move_and_slide()
		return

	if not player:
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	match current_state:
		State.CHASE:
			_handle_chase(delta)
		State.WINDUP:
			velocity = Vector2.ZERO
		State.ATTACK:
			# 若攻击已经判定命中，终止向前扑击推力
			velocity = Vector2.ZERO if attack_has_hit else (attack_direction * 280.0)
		State.RECOVERY:
			velocity = Vector2.ZERO
		State.STUNNED:
			velocity = Vector2.ZERO

	move_and_slide()

## 追逐玩家与索敌
func _handle_chase(_delta: float) -> void:
	var to_player = player.global_position - global_position
	var dist = to_player.length()

	visuals.look_at(player.global_position)

	if dist > attack_range:
		velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
		_start_attack_windup()

## 攻击前摇（喂招预警）：身体发红暴涨，给玩家 0.38 秒的反应弹反时间！
func _start_attack_windup() -> void:
	if current_state == State.HIT_STUN or current_state == State.STUNNED or is_dead:
		return

	current_state = State.WINDUP
	attack_direction = (player.global_position - global_position).normalized()
	visuals.look_at(player.global_position)

	if windup_tween and windup_tween.is_valid():
		windup_tween.kill()
	windup_tween = create_tween()
	windup_tween.tween_property(body_mesh, "color", Color(1.0, 0.2, 0.2), 0.1)
	windup_tween.parallel().tween_property(visuals, "scale", Vector2(0.8, 1.2), 0.2)
	windup_tween.tween_property(visuals, "scale", Vector2(1.2, 0.9), 0.1)

	await get_tree().create_timer(0.38).timeout
	if current_state == State.WINDUP and not is_dead:
		_execute_attack()

## 扑击动作（判定生效）
func _execute_attack() -> void:
	current_state = State.ATTACK
	attack_has_hit = false
	attack_was_parried = false
	attack_hitbox.monitoring = true

	# 利爪向前突刺
	if claw_tween and claw_tween.is_valid():
		claw_tween.kill()
	claw_tween = create_tween()
	claw_tween.tween_property(claws, "position", Vector2(25, 0), 0.08)
	claw_tween.tween_property(claws, "position", Vector2(8, 0), 0.1)

	await get_tree().create_timer(0.16).timeout
	attack_hitbox.set_deferred("monitoring", false)

	if current_state == State.ATTACK and not is_dead:
		current_state = State.RECOVERY
		body_mesh.color = Color(0.65, 0.25, 0.35) # 恢复常态暗红
		visuals.scale = Vector2.ONE
		await get_tree().create_timer(0.45).timeout
		if current_state == State.RECOVERY and not is_dead:
			current_state = State.CHASE

## 被玩家左手镜盾完美弹反！(Parried)
func get_parried(parry_point: Vector2) -> void:
	if is_dead:
		return
	attack_was_parried = true
	current_state = State.STUNNED
	attack_hitbox.set_deferred("monitoring", false)
	if windup_tween and windup_tween.is_valid():
		windup_tween.kill()
	if flinch_tween and flinch_tween.is_valid():
		flinch_tween.kill()
	if claw_tween and claw_tween.is_valid():
		claw_tween.kill()
	claws.position = Vector2(8, 0)
	
	# 核心物理：绝对远离玩家身躯被暴力震飞！
	var push_center = parry_point
	if player and is_instance_valid(player):
		push_center = player.global_position

	var recoil_dir = (global_position - push_center).normalized()
	# 若与玩家过于重叠或反向，强制朝玩家面朝方向正前方震飞
	if recoil_dir == Vector2.ZERO or (player and recoil_dir.dot(player.facing_direction) < -0.2):
		if player:
			recoil_dir = player.facing_direction
		else:
			recoil_dir = Vector2.RIGHT

	# 强力击退 650px/s，迅速拉开约 175px 绝对安全身位，彻底杜绝黏在英雄身边
	knockback_velocity = recoil_dir * 650.0

	# 破势瘫痪视觉：闪烁眩晕黄白流光，体态瘫软
	body_mesh.color = Color(1.0, 0.9, 0.2) # 金黄眩晕态
	visuals.scale = Vector2(0.7, 0.7)

	# 处于 1.4 秒易伤虚弱状态
	await get_tree().create_timer(1.4).timeout
	if current_state == State.STUNNED and not is_dead:
		body_mesh.color = Color(0.65, 0.25, 0.35)
		visuals.scale = Vector2.ONE
		current_state = State.CHASE

## 承受玩家武器或反弹伤害
func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, stun_duration: float = 0.25) -> void:
	if is_dead:
		return

	# 若处于弹反瘫痪态，承受 1.8 倍暴击伤害！
	if current_state == State.STUNNED:
		amount *= 1.8

	current_hp -= amount
	hp_bar.value = current_hp
	if knockback != Vector2.ZERO:
		knockback_velocity = knockback

	if current_hp <= 0:
		_die()
		return

	# 受击硬直判定：
	# 1. 普通小怪（无霸体）受到任何伤害均被立刻打断并进入受击硬直
	# 2. 精英怪在受到重型爆发招式（破灭重斩或第 3 段重劈 stun_duration >= 0.40）时同样被硬直打断
	var should_stagger: bool = (not is_elite) or (stun_duration >= 0.40)
	if should_stagger and current_state != State.STUNNED:
		_apply_hit_stun(stun_duration)
	else:
		_play_damage_flash()

## 施加受击硬直与动作打断
func _apply_hit_stun(duration: float) -> void:
	current_state = State.HIT_STUN
	hit_stun_timer = max(hit_stun_timer, duration)

	# 立即中断前摇动作、取消蓄力红芒与关闭扑击判定
	if windup_tween and windup_tween.is_valid():
		windup_tween.kill()
	if claw_tween and claw_tween.is_valid():
		claw_tween.kill()
	attack_hitbox.set_deferred("monitoring", false)
	claws.position = Vector2(8, 0)

	# 受击抽搐后仰顿挫（打击感反馈）
	if flinch_tween and flinch_tween.is_valid():
		flinch_tween.kill()
	flinch_tween = create_tween()
	body_mesh.color = Color.WHITE
	# 瞬间压扁后仰 + 受创紫红
	flinch_tween.tween_property(visuals, "scale", Vector2(0.72, 1.28), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flinch_tween.parallel().tween_property(body_mesh, "color", Color(0.95, 0.4, 0.45), 0.08)
	# 随后高弹性复原回标准体态与常态暗红
	flinch_tween.tween_property(visuals, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flinch_tween.parallel().tween_property(body_mesh, "color", Color(0.65, 0.25, 0.35), 0.12)

func _play_damage_flash() -> void:
	var flash_tween = create_tween()
	body_mesh.color = Color.WHITE
	flash_tween.tween_property(body_mesh, "color", Color(0.65, 0.25, 0.35), 0.08)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	defeated.emit(self)
	set_physics_process(false)
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if claw_tween and claw_tween.is_valid():
		claw_tween.kill()

	# 死亡溃散动画
	var die_tween = create_tween()
	die_tween.tween_property(visuals, "scale", Vector2.ZERO, 0.2)
	die_tween.tween_property(visuals, "modulate:a", 0.0, 0.2)
	die_tween.tween_callback(queue_free)

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if current_state != State.ATTACK or attack_has_hit or attack_was_parried:
		return

	if body is Player:
		# 优先检查玩家当前是否正处于举盾招架有效窗口（正面防线）
		if body.has_method("is_parrying_active") and body.is_parrying_active():
			attack_was_parried = true
			attack_hitbox.set_deferred("monitoring", false)
			body.on_parry_success(global_position)
			get_parried(body.global_position)
			return

		# 未处于招架态，攻击确认命中玩家
		attack_has_hit = true
		attack_hitbox.set_deferred("monitoring", false)
		if body.has_method("take_damage"):
			body.take_damage(20.0, global_position)

		# 命中玩家后立即中止向前冲锋速度，怪物自身绝不被弹飞
		velocity = Vector2.ZERO

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if current_state != State.ATTACK or attack_has_hit or attack_was_parried:
		return

	# 击中玩家的镜盾弹反判定框！必须同时满足：玩家正处于有效举盾招架状态中！
	if area.name == "ParryBox":
		var player_node = area.get_parent().get_parent() as Player
		if player_node and player_node.has_method("is_parrying_active") and player_node.is_parrying_active():
			attack_was_parried = true
			attack_hitbox.set_deferred("monitoring", false)
			player_node.on_parry_success(global_position)
			get_parried(player_node.global_position)
