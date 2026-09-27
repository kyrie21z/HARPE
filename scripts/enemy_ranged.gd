extends CharacterBody2D
class_name EnemyRanged

signal defeated(enemy: Node2D)

@export var max_hp: float = 40.0
var current_hp: float = 40.0

@export var move_speed: float = 85.0
@export var shoot_interval: float = 2.4
@export var ideal_distance: float = 240.0

var player: Player = null
var shoot_timer: float = 0.0
var is_casting: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

var hit_stun_timer: float = 0.0
var cast_tween: Tween = null
var flinch_tween: Tween = null
@export var is_elite: bool = false

const BULLET_SCENE = preload("res://scenes/Bullet.tscn")

@onready var visuals: Node2D = $Visuals
@onready var body_mesh: Polygon2D = $Visuals/Body
@onready var staff_gem: Polygon2D = $Visuals/Staff/Gem
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

func _physics_process(delta: float) -> void:
	# 击退阻尼衰减
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
		velocity = knockback_velocity
	else:
		velocity = Vector2.ZERO

	# 受击硬直计时：硬直期间中断一切移动与攻击，仅受击退滑动
	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta
		if hit_stun_timer <= 0.0:
			hit_stun_timer = 0.0
		move_and_slide()
		return

	if knockback_velocity != Vector2.ZERO:
		move_and_slide()
		return

	if not player:
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return

	visuals.look_at(player.global_position)

	# 保持射程拉扯
	var to_player = player.global_position - global_position
	var dist = to_player.length()

	if not is_casting:
		if dist < ideal_distance - 40.0:
			# 太近了，后撤步拉开距离
			velocity = -to_player.normalized() * (move_speed * 1.1)
		elif dist > ideal_distance + 40.0:
			# 太远了，缓缓靠近
			velocity = to_player.normalized() * move_speed
		else:
			# 射程内微移走位
			velocity = Vector2.ZERO

		# 射击充能计时
		shoot_timer += delta
		if shoot_timer >= shoot_interval:
			shoot_timer = 0.0
			_start_cast_spell()
	else:
		velocity = Vector2.ZERO

	move_and_slide()

## 施法蓄力前摇（法杖宝珠闪烁紫光，引诱玩家准备镜盾弹反）
func _start_cast_spell() -> void:
	if hit_stun_timer > 0.0 or is_dead:
		return

	is_casting = true
	if cast_tween and cast_tween.is_valid():
		cast_tween.kill()
	cast_tween = create_tween()
	cast_tween.tween_property(staff_gem, "color", Color(1.0, 0.4, 0.9), 0.3)
	cast_tween.parallel().tween_property(staff_gem, "scale", Vector2(1.5, 1.5), 0.3)

	await get_tree().create_timer(0.45).timeout
	if is_inside_tree() and current_hp > 0 and not is_dead and is_casting and hit_stun_timer <= 0.0:
		_fire_bullet()

	if not is_dead:
		staff_gem.color = Color(0.7, 0.2, 0.8)
		staff_gem.scale = Vector2.ONE
		is_casting = false

## 发射魔矢弹幕
func _fire_bullet() -> void:
	if not player:
		return
	var bullet = BULLET_SCENE.instantiate() as Projectile
	get_parent().add_child(bullet)
	bullet.global_position = staff_gem.global_position
	bullet.direction = (player.global_position - staff_gem.global_position).normalized()

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, stun_duration: float = 0.30) -> void:
	if is_dead:
		return
	current_hp -= amount
	hp_bar.value = current_hp
	knockback_velocity = knockback

	if current_hp <= 0:
		_die()
		return

	# 受击硬直判定：普通远程怪物被击中立刻打断施法并抽搐硬直
	var should_stagger: bool = (not is_elite) or (stun_duration >= 0.40)
	if should_stagger:
		_apply_hit_stun(stun_duration)
	else:
		_play_damage_flash()

## 施加受击硬直与施法打断
func _apply_hit_stun(duration: float) -> void:
	hit_stun_timer = max(hit_stun_timer, duration)
	is_casting = false
	if cast_tween and cast_tween.is_valid():
		cast_tween.kill()
	staff_gem.color = Color(0.7, 0.2, 0.8)
	staff_gem.scale = Vector2.ONE

	# 受击抽搐后仰顿挫（打击感反馈）
	if flinch_tween and flinch_tween.is_valid():
		flinch_tween.kill()
	flinch_tween = create_tween()
	body_mesh.color = Color.WHITE
	# 瞬间压扁后仰 + 受创紫红
	flinch_tween.tween_property(visuals, "scale", Vector2(0.72, 1.28), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flinch_tween.parallel().tween_property(body_mesh, "color", Color(0.8, 0.3, 0.8), 0.08)
	# 随后高弹性复原回标准体态与常态暗紫
	flinch_tween.tween_property(visuals, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flinch_tween.parallel().tween_property(body_mesh, "color", Color(0.3, 0.2, 0.45), 0.12)

func _play_damage_flash() -> void:
	var flash_tween = create_tween()
	body_mesh.color = Color.WHITE
	flash_tween.tween_property(body_mesh, "color", Color(0.3, 0.2, 0.45), 0.08)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	defeated.emit(self)
	set_physics_process(false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if cast_tween and cast_tween.is_valid():
		cast_tween.kill()
	if flinch_tween and flinch_tween.is_valid():
		flinch_tween.kill()

	var die_tween = create_tween()
	die_tween.tween_property(visuals, "scale", Vector2.ZERO, 0.2)
	die_tween.tween_property(visuals, "modulate:a", 0.0, 0.2)
	die_tween.tween_callback(queue_free)
