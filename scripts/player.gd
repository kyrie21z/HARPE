extends CharacterBody2D
class_name Player

## 状态定义：有限状态机 (State Machine)
enum State {
	NORMAL,      ## 正常移动与索敌
	DASHING,     ## 瞬步冲刺中（不可打断，带无敌帧）
	ATTACKING,   ## 攻击中（轻击或重斩）
	PARRYING     ## 举盾弹反判定窗口中
}

var current_state: State = State.NORMAL

## --- 基础手感参数 (Game Feel Parameters) ---
@export_group("生命参数")
@export var max_hp: float = 100.0
var current_hp: float = 100.0

@export_group("移动参数")
@export var move_speed: float = 260.0        ## 常规移速
@export var acceleration: float = 2400.0     ## 加速度
@export var friction: float = 2800.0         ## 刹车摩擦力

@export_group("瞬步参数 (Dash)")
@export var dash_speed: float = 750.0        ## 瞬步爆发初速度
@export var dash_duration: float = 0.18      ## 瞬步持续时长（秒）
@export var dash_cooldown: float = 0.5       ## 瞬步冷却时间（秒）

@export_group("攻击与蓄力参数")
@export var charge_time_threshold: float = 0.22 ## 按住左键超过此时间判定为蓄力
@export var heavy_attack_lunge: float = 650.0   ## 重斩前冲突进速度

@export_group("三段轻击连招 (3-Hit Combo)")
@export var combo_window: float = 0.45          ## 连击有效输入缓冲窗口（秒）
@export var light_lunge_1: float = 340.0        ## 第 1 段（右往左）垫步位移速度
@export var light_lunge_2: float = 380.0        ## 第 2 段（左往右）顺势回砍位移速度
@export var light_lunge_3: float = 520.0        ## 第 3 段（由上往下）破空重劈位移速度
@export var light_damage_1: float = 20.0        ## 第 1 段基础伤害
@export var light_damage_2: float = 25.0        ## 第 2 段回砍伤害
@export var light_damage_3: float = 45.0        ## 第 3 段重劈爆发伤害

@export_group("冲刺攻击 (Dash-Strike)")
@export var dash_strike_lunge: float = 780.0        ## 冲刺斩向前贯穿滑行速度（高于常规瞬步速度750，全速贯通）
@export var dash_strike_damage: float = 30.0        ## 冲刺斩贯穿伤害

@export_group("盾反参数 (Parry)")
@export var parry_active_window: float = 0.15   ## 弹反完美有效判定窗口（秒）

@export_group("操作模式")
@export var aim_with_mouse: bool = false        ## 是否用鼠标瞄准近战（默认false：纯哈迪斯近战模式，移动/攻击/弹反方向严格保持一致）

signal hp_changed(current: float, max_value: float)
signal player_died()
signal boon_acquired(boon: BoonData)

## --- 内部变量 ---
var facing_direction: Vector2 = Vector2.RIGHT
var dash_direction: Vector2 = Vector2.ZERO
var can_dash: bool = true
var is_invincible: bool = false
var parry_invincible_timer: float = 0.0                  ## 弹反成功后的绝对无敌保护窗口（秒），免疫同帧/连带伤害
var player_knockback_velocity: Vector2 = Vector2.ZERO   ## 受创被击退速度，瞬间拉开物理身位杜绝黏连
var is_dash_striking: bool = false                  ## 当前是否正在冲刺斩贯穿中
var struck_enemies_this_dash: Array = []            ## 当前冲刺斩已命中的敌人列表，防止同次冲刺多次伤害
var input_locked: bool = false                      ## 是否锁定玩家输入（如房间转场入场漫步）
var is_using_gamepad: bool = false                  ## 是否当前正在使用手柄操控

# 三段连招状态
var current_combo_step: int = 0
var combo_timer: Timer
var attack_tween: Tween = null

# 蓄力判定变量
var is_holding_attack: bool = false
var attack_hold_timer: float = 0.0
var is_charge_ready: bool = false

## --- 肉鸽神力词条激活状态 (Boon States) ---
var acquired_boons: Array[String] = []
var has_dash_damage: bool = false       ## 【神行裂隙】瞬步穿透斩
var has_dash_phantom: bool = false      ## 【金羽残影】嘲讽自爆幻影
var has_parry_thunder: bool = false     ## 【雅典娜的雷暴】全屏神雷
var has_deflect_homing: bool = false    ## 【波光追踪】反弹追踪必暴
var has_titan_slash: bool = false       ## 【泰坦破军】破灭重斩强化
var has_instant_heavy_boon: bool = false## 【刚体反击】
var can_instant_heavy: bool = false     ## 当前是否激活瞬发破灭重斩

## 节点引用
@onready var visuals: Node2D = $Visuals
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var left_shield: Node2D = $Visuals/LeftShield
@onready var shield_glint: Polygon2D = $Visuals/LeftShield/ShieldGlint
@onready var right_blade: Node2D = $Visuals/RightBlade
@onready var harpe_blade: Polygon2D = $Visuals/RightBlade/HarpeBlade
@onready var slash_effect: Node2D = $Visuals/SlashEffect
@onready var light_slash_arc: Polygon2D = $Visuals/SlashEffect/LightSlashArc
@onready var light_slash_arc_1: Polygon2D = $Visuals/SlashEffect/LightSlashArc1
@onready var light_slash_arc_2: Polygon2D = $Visuals/SlashEffect/LightSlashArc2
@onready var light_slash_arc_3: Polygon2D = $Visuals/SlashEffect/LightSlashArc3
@onready var heavy_slash_arc: Polygon2D = $Visuals/SlashEffect/HeavySlashArc
@onready var dash_slash_arc: Polygon2D = $Visuals/SlashEffect/DashSlashArc
@onready var hitbox: Area2D = $Visuals/Hitbox
@onready var parry_box: Area2D = $Visuals/ParryBox
@onready var dash_hitbox: Area2D = $Visuals/DashHitbox
@onready var camera: Camera2D = $Camera2D

## 计时器引用
var dash_timer: Timer
var dash_cooldown_timer: Timer
var ghost_timer: Timer

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	current_hp = max_hp
	if parry_box:
		parry_box.monitoring = false
		parry_box.monitorable = false
	_setup_timers()
	_setup_combat_signals()

func _setup_timers() -> void:
	dash_timer = Timer.new()
	dash_timer.one_shot = true
	dash_timer.wait_time = dash_duration
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	add_child(dash_timer)

	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)
	add_child(dash_cooldown_timer)

	ghost_timer = Timer.new()
	ghost_timer.wait_time = 0.04
	ghost_timer.timeout.connect(_spawn_ghost_trail)
	add_child(ghost_timer)

	combo_timer = Timer.new()
	combo_timer.one_shot = true
	combo_timer.wait_time = combo_window
	combo_timer.timeout.connect(_on_combo_timer_timeout)
	add_child(combo_timer)

func _on_combo_timer_timeout() -> void:
	current_combo_step = 0

func _setup_combat_signals() -> void:
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	parry_box.area_entered.connect(_on_parry_box_area_entered)
	if dash_hitbox:
		dash_hitbox.area_entered.connect(_on_dash_hitbox_area_entered)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		is_using_gamepad = true
	elif event is InputEventJoypadMotion:
		if abs(event.axis_value) > 0.2:
			is_using_gamepad = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		is_using_gamepad = false
	elif event is InputEventKey and event.pressed:
		is_using_gamepad = false

## 手柄触觉震动反馈 (Controller Haptics)
func _rumble(weak: float, strong: float, duration: float) -> void:
	Input.start_joy_vibration(0, weak, strong, duration)

func _physics_process(delta: float) -> void:
	if parry_invincible_timer > 0.0:
		parry_invincible_timer = max(0.0, parry_invincible_timer - delta)

	# 受创冲击击退衰减
	if player_knockback_velocity != Vector2.ZERO:
		player_knockback_velocity = player_knockback_velocity.move_toward(Vector2.ZERO, 2000.0 * delta)

	if input_locked:
		velocity = Vector2.ZERO
		return

	match current_state:
		State.NORMAL:
			_handle_normal_state(delta)
		State.DASHING:
			_handle_dash_state(delta)
		State.ATTACKING:
			_handle_attacking_state(delta)
		State.PARRYING:
			_handle_parrying_state(delta)

	if player_knockback_velocity != Vector2.ZERO and current_state != State.DASHING:
		velocity += player_knockback_velocity

	move_and_slide()

## 正常状态：处理移动、蓄力监控、瞬步与出招触发
func _handle_normal_state(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 1. 监控攻击输入
	if Input.is_action_just_pressed("attack"):
		# 质变联动：如果刚体反击就绪，直接轰出破灭重斩！
		if can_instant_heavy:
			can_instant_heavy = false
			_execute_heavy_attack()
			return

		is_holding_attack = true
		attack_hold_timer = 0.0
		is_charge_ready = false

	if is_holding_attack:
		attack_hold_timer += delta
		if attack_hold_timer >= charge_time_threshold and not is_charge_ready:
			is_charge_ready = true
			_on_charge_ready()

	# 蓄力期间移速降低（重心压低），并允许鼠标瞄准重斩方向
	var current_max_speed = move_speed * 0.4 if is_charge_ready else move_speed

	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * current_max_speed, acceleration * delta)
		if is_holding_attack:
			# 蓄力中：朝向对准瞄准方向，走位继续由摇杆/WASD驱动
			_snap_to_aim()
		else:
			# 常态跑动：朝向完全锁定在移动方向上，鼠标随意晃动绝不产生陀螺自转！
			facing_direction = input_vector.normalized()
			visuals.rotation = lerp_angle(visuals.rotation, facing_direction.angle(), 1.0 - exp(-30.0 * delta))
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if is_holding_attack:
			_snap_to_aim()
		elif is_using_gamepad:
			# 静止状态下允许用右摇杆精准调整朝向（双摇杆瞄准）
			var aim_vec = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
			if aim_vec.length() > 0.25:
				facing_direction = aim_vec.normalized()
				visuals.rotation = facing_direction.angle()

	# 2. 松开左键：根据是否蓄满释放【轻击】或【破灭重斩】
	if Input.is_action_just_released("attack") and is_holding_attack:
		is_holding_attack = false
		if is_charge_ready:
			_execute_heavy_attack()
		else:
			_execute_light_attack()

	# 3. 监听右键：触发【左手镜盾弹反】
	if Input.is_action_just_pressed("parry"):
		is_holding_attack = false
		_reset_charge_visuals()
		_execute_parry()
		return

	# 4. 监听瞬步 (Shift / Space / A)
	if Input.is_action_just_pressed("dash") and can_dash:
		# 只要玩家在起跑时按下攻击键、或正在进行轻击出招，立刻判定为冲刺斩；
		# 仅当已蓄力就绪（is_charge_ready）时，瞬步才视为蓄力取消并执行纯粹瞬身脱困
		var want_dash_strike: bool = Input.is_action_just_pressed("attack") or (Input.is_action_pressed("attack") and not is_charge_ready) or (is_holding_attack and not is_charge_ready)
		is_holding_attack = false
		_reset_charge_visuals()
		_start_dash(input_vector, want_dash_strike)

## 蓄满视觉反馈：Harpe 剑刃泛起金色光芒并微颤
func _on_charge_ready() -> void:
	var tween = create_tween()
	var glow_color = Color(1.0, 0.4, 0.1) if has_titan_slash else Color(1.0, 0.75, 0.1)
	tween.tween_property(harpe_blade, "color", glow_color, 0.08)
	visuals.scale = Vector2(0.9, 1.1)

## 重置蓄力视觉
func _reset_charge_visuals() -> void:
	if not can_instant_heavy:
		harpe_blade.color = Color(0.92, 0.95, 1, 1)
	visuals.scale = Vector2.ONE
	is_charge_ready = false

## 攻击状态移动处理
func _handle_attacking_state(delta: float) -> void:
	# 允许瞬步打断攻击收刀后摇（Dash-Cancel），实现丝滑走位！
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("dash") and can_dash:
		var want_dash_strike: bool = Input.is_action_pressed("attack") or Input.is_action_just_pressed("attack")
		_cancel_attack_and_dash(input_vector, want_dash_strike)
		return

	velocity = velocity.move_toward(Vector2.ZERO, friction * 1.5 * delta)

## 瞬步打断攻击
func _cancel_attack_and_dash(input_vector: Vector2, want_dash_strike: bool = false) -> void:
	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()
	_hide_all_slash_arcs()
	hitbox.set_deferred("monitoring", false)
	right_blade.position = Vector2(8, 18)
	right_blade.rotation = 0.0
	visuals.scale = Vector2.ONE
	_start_dash(input_vector, want_dash_strike)

## 弹反状态移动处理
func _handle_parrying_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * 2.0 * delta)

## 瞬步状态移动处理
func _handle_dash_state(_delta: float) -> void:
	# 瞬步期间只要按下或按住攻击键，立刻激活冲刺斩！
	if not is_dash_striking and (Input.is_action_just_pressed("attack") or Input.is_action_pressed("attack")):
		_trigger_dash_strike()

	# 冲刺斩享有全速穿透推力（780px/s），绝不减速急刹！
	var current_dash_speed = dash_strike_lunge if is_dash_striking else dash_speed
	velocity = dash_direction * current_dash_speed

## 触发瞬步（支持直接派生冲刺斩）
func _start_dash(input_vector: Vector2, trigger_strike: bool = false) -> void:
	current_state = State.DASHING
	can_dash = false
	is_invincible = true
	is_dash_striking = false
	struck_enemies_this_dash.clear()
	player_knockback_velocity = Vector2.ZERO

	if input_vector != Vector2.ZERO:
		dash_direction = input_vector.normalized()
		facing_direction = dash_direction
	else:
		if is_using_gamepad:
			# 手柄摇杆回中时朝面朝方向瞬步（经典哈迪斯手感）
			dash_direction = facing_direction
		else:
			# 键鼠松开键盘时朝鼠标方向瞬步
			var mouse_dir = (get_global_mouse_position() - global_position).normalized()
			if mouse_dir != Vector2.ZERO:
				dash_direction = mouse_dir
				facing_direction = mouse_dir
			else:
				dash_direction = facing_direction

	_rumble(0.18, 0.0, 0.08)

	visuals.rotation = dash_direction.angle()
	visuals.scale = Vector2(1.3, 0.7)

	# 纯瞬步（直接瞬身）绝对不产生肉身碰撞伤害，仅作为闪避与穿透位移
	if dash_hitbox:
		dash_hitbox.monitoring = false
	if hitbox:
		hitbox.monitoring = false

	# 瞬步期间允许穿透敌人身躯（Hades 核心穿梭体验），仅保留墙体碰撞
	set_collision_mask_value(3, false)

	dash_timer.start()
	ghost_timer.start()
	_spawn_ghost_trail()

	# 同时按下或按住攻击键时，从第 1 帧立刻激活冲刺斩！
	if trigger_strike:
		_trigger_dash_strike()

func _on_dash_timer_timeout() -> void:
	current_state = State.NORMAL
	is_invincible = false
	# 退出瞬步，恢复与敌人身躯的实体碰撞
	set_collision_mask_value(3, true)
	ghost_timer.stop()

	if dash_hitbox:
		dash_hitbox.set_deferred("monitoring", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)

	if is_dash_striking:
		is_dash_striking = false
		struck_enemies_this_dash.clear()
		var arc_tween = create_tween()
		arc_tween.tween_property(dash_slash_arc, "modulate:a", 0.0, 0.10)
		arc_tween.tween_callback(_hide_all_slash_arcs)
		right_blade.position = Vector2(8, 18)
		right_blade.rotation = 0.0

		# 冲刺斩贯通结束后，顺畅派生平砍连招第 2 段（顺势回砍）！
		current_combo_step = 1
		combo_timer.start(combo_window)

	var tween = create_tween()
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.08)
	# 退出瞬步时的滑行初动量（不踩急刹，滑行带入常态）
	velocity = dash_direction * (move_speed * 1.25)
	dash_cooldown_timer.start()

func _on_dash_cooldown_timeout() -> void:
	can_dash = true

## 瞬步斩击碰撞检测
func _on_dash_hitbox_area_entered(area: Area2D) -> void:
	if is_dash_striking and area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy:
			_apply_dash_strike_hit(enemy)

## 瞄准朝向对齐（键鼠瞄准鼠标，手柄瞄准摇杆与面朝方向）
func _snap_to_aim() -> void:
	if is_using_gamepad:
		# 优先使用右摇杆（双摇杆精准射击/斩击瞄准）
		var aim_vec = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if aim_vec.length() > 0.25:
			facing_direction = aim_vec.normalized()
			visuals.rotation = facing_direction.angle()
			return

		# 其次使用左摇杆（移动即朝向，经典哈迪斯近战手感）
		var move_vec = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if move_vec.length() > 0.15:
			facing_direction = move_vec.normalized()
			visuals.rotation = facing_direction.angle()
			return

		# 摇杆均回中时保持当前面朝方向
		visuals.rotation = facing_direction.angle()
	else:
		var mouse_dir = (get_global_mouse_position() - global_position).normalized()
		if mouse_dir != Vector2.ZERO:
			facing_direction = mouse_dir
			visuals.rotation = facing_direction.angle()

func _snap_to_mouse() -> void:
	_snap_to_aim()

## 隐藏所有刀光弧面
func _hide_all_slash_arcs() -> void:
	slash_effect.visible = false
	if light_slash_arc:
		light_slash_arc.visible = false
	if light_slash_arc_1:
		light_slash_arc_1.visible = false
	if light_slash_arc_2:
		light_slash_arc_2.visible = false
	if light_slash_arc_3:
		light_slash_arc_3.visible = false
	if heavy_slash_arc:
		heavy_slash_arc.visible = false
	if dash_slash_arc:
		dash_slash_arc.visible = false

## 激活冲刺攻击（Dash-Strike）：保持瞬步极速穿透，出刀撕裂前路
func _trigger_dash_strike() -> void:
	is_dash_striking = true
	# 出刀瞬间：Harpe 剑尖瞬切朝向瞄准方向，向瞄准方向贯穿突击！
	_snap_to_mouse()
	dash_direction = facing_direction

	_hide_all_slash_arcs()
	slash_effect.visible = true
	dash_slash_arc.visible = true
	dash_slash_arc.modulate.a = 1.0

	# 冲刺斩同时开启前方扇形刀光与环身冲刺判定盒，全方位判定穿透割裂
	if hitbox:
		hitbox.monitoring = true
	if dash_hitbox:
		dash_hitbox.monitoring = true

	# 保证冲刺斩有足够的有效割裂时间（至少 0.14 秒）
	if dash_timer and dash_timer.time_left < 0.14:
		dash_timer.start(0.14)

	# 角色重心压低、利刃前刺贯通姿态
	visuals.scale = Vector2(1.38, 0.68)
	right_blade.position = Vector2(26, 4)
	right_blade.rotation = 0.0

	_shake_camera(3.5, 0.10)
	_rumble(0.2, 0.3, 0.08)

	# 立即检测当前已重叠的敌人（防止瞬发同帧物理穿模不触发 area_entered）
	_check_dash_strike_overlaps()

func _check_dash_strike_overlaps() -> void:
	if not is_dash_striking:
		return
	if hitbox and hitbox.monitoring:
		for area in hitbox.get_overlapping_areas():
			_on_hitbox_area_entered(area)
	if dash_hitbox and dash_hitbox.monitoring:
		for area in dash_hitbox.get_overlapping_areas():
			_on_dash_hitbox_area_entered(area)

func _apply_dash_strike_hit(enemy: Node) -> void:
	if not is_dash_striking or enemy == null:
		return
	if enemy in struck_enemies_this_dash:
		return
	struck_enemies_this_dash.append(enemy)

	var dmg = 50.0 if has_dash_damage else dash_strike_damage
	var knock_force = 420.0 if has_dash_damage else 320.0
	var hit_stop_time = 0.08 if has_dash_damage else 0.06
	var shake_power = 4.5 if has_dash_damage else 3.5
	var stun_time = 0.40 if has_dash_damage else 0.30

	if enemy.has_method("take_damage"):
		enemy.take_damage(dmg, dash_direction * knock_force, stun_time)
		_trigger_hit_stop(hit_stop_time)
		_shake_camera(shake_power, 0.12)

## 执行【三段轻击连招 (3-Hit Combo)】
func _execute_light_attack() -> void:
	current_state = State.ATTACKING
	# Hades 核心手感：出刀瞬间身体与剑刃强制瞬切至鼠标方向！
	_snap_to_mouse()

	_hide_all_slash_arcs()
	slash_effect.visible = true
	hitbox.monitoring = true

	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()
	attack_tween = create_tween()

	match current_combo_step:
		0:
			# === 第 1 段：从右往左挥刃（右起手上削，扇面大弧光） ===
			velocity = facing_direction * light_lunge_1
			light_slash_arc_1.visible = true
			light_slash_arc_1.modulate.a = 1.0

			right_blade.position = Vector2(16, 22)
			right_blade.rotation = 0.5
			attack_tween.tween_property(right_blade, "position", Vector2(6, -20), 0.12)
			attack_tween.parallel().tween_property(right_blade, "rotation", -1.2, 0.12)
			attack_tween.parallel().tween_property(visuals, "scale", Vector2(1.15, 0.9), 0.08)
			attack_tween.tween_property(visuals, "scale", Vector2.ONE, 0.08)
			attack_tween.parallel().tween_property(light_slash_arc_1, "modulate:a", 0.0, 0.12)

			current_combo_step = 1
			combo_timer.start(combo_window)
			await attack_tween.finished

		1:
			# === 第 2 段：顺势从左往右回砍（左起手反向切削） ===
			velocity = facing_direction * light_lunge_2
			light_slash_arc_2.visible = true
			light_slash_arc_2.modulate.a = 1.0

			right_blade.position = Vector2(4, -20)
			right_blade.rotation = -1.2
			attack_tween.tween_property(right_blade, "position", Vector2(18, 18), 0.12)
			attack_tween.parallel().tween_property(right_blade, "rotation", 0.8, 0.12)
			attack_tween.parallel().tween_property(visuals, "scale", Vector2(1.18, 0.88), 0.08)
			attack_tween.tween_property(visuals, "scale", Vector2.ONE, 0.08)
			attack_tween.parallel().tween_property(light_slash_arc_2, "modulate:a", 0.0, 0.12)

			current_combo_step = 2
			combo_timer.start(combo_window)
			await attack_tween.finished

		2:
			# === 第 3 段：从上往下纵向重劈（破空终结下劈） ===
			velocity = facing_direction * light_lunge_3
			light_slash_arc_3.visible = true
			light_slash_arc_3.modulate.a = 1.0

			right_blade.position = Vector2(2, -24)
			right_blade.rotation = -1.6
			attack_tween.tween_property(right_blade, "position", Vector2(26, 4), 0.14)
			attack_tween.parallel().tween_property(right_blade, "rotation", 0.3, 0.14)
			attack_tween.parallel().tween_property(visuals, "scale", Vector2(1.28, 0.75), 0.10)
			attack_tween.tween_property(visuals, "scale", Vector2.ONE, 0.12)
			attack_tween.parallel().tween_property(light_slash_arc_3, "modulate:a", 0.0, 0.18)

			_shake_camera(4.5, 0.12)

			current_combo_step = 0
			combo_timer.stop()
			await attack_tween.finished

	_hide_all_slash_arcs()
	hitbox.set_deferred("monitoring", false)
	right_blade.position = Vector2(8, 18)
	right_blade.rotation = 0.0
	if current_state == State.ATTACKING:
		current_state = State.NORMAL

## 执行【破灭重斩】
func _execute_heavy_attack() -> void:
	current_state = State.ATTACKING
	# 出刀瞬间：身体与重斩强制瞬切至鼠标方向！
	_snap_to_mouse()
	_reset_charge_visuals()
	current_combo_step = 0
	combo_timer.stop()

	_hide_all_slash_arcs()
	slash_effect.visible = true
	heavy_slash_arc.visible = true
	hitbox.monitoring = true

	var lunge_force = heavy_attack_lunge * 1.2 if has_titan_slash else heavy_attack_lunge
	velocity = facing_direction * lunge_force

	visuals.scale = Vector2(1.5, 0.75) if has_titan_slash else Vector2(1.4, 0.8)
	var body_tween = create_tween()
	body_tween.tween_property(visuals, "scale", Vector2.ONE, 0.18)

	_shake_camera(8.0 if has_titan_slash else 6.0, 0.16)
	_rumble(0.6, 0.9, 0.16)

	var slash_tween = create_tween()
	slash_tween.tween_property(heavy_slash_arc, "modulate:a", 0.0, 0.2).from(1.0)
	await slash_tween.finished

	_hide_all_slash_arcs()
	hitbox.set_deferred("monitoring", false)
	current_state = State.NORMAL

## 执行【左手镜盾弹反】
func _execute_parry() -> void:
	current_state = State.PARRYING
	# 举盾瞬间：神盾直接对准鼠标方向！
	_snap_to_mouse()

	parry_box.monitoring = true
	parry_box.monitorable = true
	shield_glint.visible = true

	var shield_tween = create_tween()
	shield_tween.tween_property(left_shield, "position", Vector2(20, -12), 0.06)
	shield_tween.tween_property(left_shield, "position", Vector2(8, -18), 0.12)

	var glint_tween = create_tween()
	glint_tween.tween_property(shield_glint, "modulate:a", 0.0, parry_active_window).from(1.0)

	await get_tree().create_timer(parry_active_window).timeout
	parry_box.set_deferred("monitoring", false)
	parry_box.set_deferred("monitorable", false)
	shield_glint.visible = false

	await get_tree().create_timer(0.06).timeout
	if current_state == State.PARRYING:
		current_state = State.NORMAL

## 击中敌人 Hurtbox 回调
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy and enemy.has_method("take_damage"):
			# 冲刺斩统一走冲刺打击处理，避免重复伤害
			if is_dash_striking or (dash_slash_arc and dash_slash_arc.visible):
				_apply_dash_strike_hit(enemy)
				return

			var is_heavy = heavy_slash_arc.visible
			var dmg = light_damage_1
			var knock_force = 180.0
			var hit_stop_time = 0.05
			var shake_power = 2.5
			var stun_time = 0.22

			if is_heavy:
				dmg = 100.0 if has_titan_slash else 70.0
				knock_force = 550.0
				hit_stop_time = 0.14
				shake_power = 8.0
				stun_time = 0.60
			elif dash_slash_arc and dash_slash_arc.visible:
				dmg = 50.0 if has_dash_damage else dash_strike_damage
				knock_force = 400.0 if has_dash_damage else 300.0
				hit_stop_time = 0.08 if has_dash_damage else 0.06
				shake_power = 4.5 if has_dash_damage else 3.5
				stun_time = 0.40 if has_dash_damage else 0.32
			elif light_slash_arc_3 and light_slash_arc_3.visible:
				dmg = light_damage_3
				knock_force = 480.0
				hit_stop_time = 0.09
				shake_power = 6.0
				stun_time = 0.45
			elif light_slash_arc_2 and light_slash_arc_2.visible:
				dmg = light_damage_2
				knock_force = 240.0
				hit_stop_time = 0.06
				shake_power = 3.5
				stun_time = 0.26
			elif light_slash_arc_1 and light_slash_arc_1.visible:
				dmg = light_damage_1
				knock_force = 180.0
				hit_stop_time = 0.05
				shake_power = 2.5
				stun_time = 0.22

			enemy.take_damage(dmg, facing_direction * knock_force, stun_time)
			_trigger_hit_stop(hit_stop_time)
			_shake_camera(shake_power, 0.12)

## 弹反判定框检测到飞来的子弹
func _on_parry_box_area_entered(area: Area2D) -> void:
	if area is Projectile:
		var bullet = area as Projectile
		if not bullet.is_reflected and not bullet.has_hit_target:
			bullet.has_hit_target = true
			var deflect_target = facing_direction
			# 如果激活了【波光追踪】，寻找最近的敌人弱点导向
			if has_deflect_homing:
				var closest_enemy = _find_closest_enemy()
				if closest_enemy:
					deflect_target = (closest_enemy.global_position - bullet.global_position).normalized()
			bullet.deflect(deflect_target)
			on_parry_success(bullet.global_position)

## 寻找最近敌人
func _find_closest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy_hurtbox")
	var closest: Node2D = null
	var min_dist: float = 99999.0
	for hurtbox_area in enemies:
		var enemy_body = hurtbox_area.get_parent() as Node2D
		if enemy_body and is_instance_valid(enemy_body):
			var d = global_position.distance_to(enemy_body.global_position)
			if d < min_dist:
				min_dist = d
				closest = enemy_body
	return closest

## 外部公开接口：查询当前是否处于有效招架判定中
func is_parrying_active() -> bool:
	return current_state == State.PARRYING and parry_box != null and parry_box.monitoring

## 弹反大成功核心反馈
func on_parry_success(_source_pos: Vector2) -> void:
	parry_invincible_timer = 0.35 # 给予 0.35 秒绝对无敌保护，防止同帧/近帧杂兵换血
	_trigger_hit_stop(0.15, 0.03)
	_shake_camera(9.0, 0.2)
	_rumble(0.8, 1.0, 0.22)
	can_dash = true # 重置瞬步

	# 词条强化 1：全屏雷暴
	if has_parry_thunder:
		_trigger_thunderstorm()

	# 词条强化 2：刚体反击（下一次免蓄力瞬发重斩）
	if has_instant_heavy_boon:
		can_instant_heavy = true
		harpe_blade.color = Color(1.8, 0.4, 0.2) # 猩红充能态

	# 盾面爆破金光
	var flash_tween = create_tween()
	shield_glint.visible = true
	shield_glint.modulate = Color(1.8, 1.4, 0.4, 1.0)
	flash_tween.tween_property(shield_glint, "scale", Vector2(2.0, 2.0), 0.08)
	flash_tween.tween_property(shield_glint, "modulate:a", 0.0, 0.12)
	await flash_tween.finished
	shield_glint.scale = Vector2.ONE
	shield_glint.visible = false

## 雅典娜全屏雷暴
func _trigger_thunderstorm() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy_hurtbox")
	for hurtbox_area in enemies:
		var enemy = hurtbox_area.get_parent()
		if enemy and enemy.has_method("take_damage") and is_instance_valid(enemy):
			var push_dir = (enemy.global_position - global_position).normalized()
			if push_dir == Vector2.ZERO:
				push_dir = facing_direction
			# 造成 40 点雷暴并强力震退 450px/s，打散敌群身位
			enemy.take_damage(40.0, push_dir * 450.0, 0.80)

## 受到伤害
func take_damage(amount: float, source_pos: Vector2 = Vector2.ZERO) -> void:
	# 瞬步无敌、常规无敌或刚成功招架（无敌保护中），完全免伤
	if is_invincible or current_state == State.DASHING or parry_invincible_timer > 0.0:
		return

	# 若受击瞬间玩家正处于举盾招架有效窗口，进行正面招架救赎拦截
	if is_parrying_active():
		var is_frontal: bool = true
		if source_pos != Vector2.ZERO:
			var attack_dir = (source_pos - global_position).normalized()
			# 正面 200 度圆弧防御判定（dot > -0.3）
			is_frontal = facing_direction.dot(attack_dir) > -0.3
		if is_frontal:
			on_parry_success(source_pos)
			_parry_stun_nearby_enemies(source_pos)
			return

	current_hp = max(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)

	# 受创核心反馈：打断蓄力
	if is_holding_attack or is_charge_ready:
		is_holding_attack = false
		is_charge_ready = false
		attack_hold_timer = 0.0
		_reset_charge_visuals()

	# 普通命中不再将角色超远击飞，保留原地受创硬直与顿挫
	player_knockback_velocity = Vector2.ZERO

	_shake_camera(4.5, 0.12)
	_rumble(0.5, 0.6, 0.14)
	var body_tween = create_tween()
	visuals.modulate = Color(1.0, 0.25, 0.25)
	body_tween.tween_property(visuals, "modulate", Color.WHITE, 0.12)

	if current_hp <= 0:
		Engine.time_scale = 1.0
		player_died.emit()

## 救赎招架时强力震退并瘫痪近身攻击来源怪物
func _parry_stun_nearby_enemies(source_pos: Vector2) -> void:
	var check_pos = source_pos if source_pos != Vector2.ZERO else global_position
	var enemies = get_tree().get_nodes_in_group("enemy_hurtbox")
	for hurtbox in enemies:
		var enemy = hurtbox.get_parent()
		if enemy and is_instance_valid(enemy):
			if enemy.global_position.distance_to(check_pos) < 140.0 or enemy.global_position.distance_to(global_position) < 140.0:
				if enemy.has_method("get_parried"):
					enemy.get_parried(global_position)

## 恢复生命与提升生命上限（仙馔密酒圣物效果）
func heal_and_boost_max_hp(heal_amount: float, max_hp_bonus: float = 0.0) -> void:
	max_hp += max_hp_bonus
	current_hp = min(max_hp, current_hp + heal_amount)
	hp_changed.emit(current_hp, max_hp)
	var body_tween = create_tween()
	visuals.modulate = Color(0.3, 1.0, 0.5)
	body_tween.tween_property(visuals, "modulate", Color.WHITE, 0.35)

## 应用神力词条强化 (Apply Boon)
func apply_boon(boon: BoonData) -> void:
	acquired_boons.append(boon.id)
	boon_acquired.emit(boon)

	match boon.id:
		"dash_damage":
			has_dash_damage = true
			dash_cooldown *= 0.6
			dash_cooldown_timer.wait_time = dash_cooldown
		"dash_phantom":
			has_dash_phantom = true
		"parry_thunder":
			has_parry_thunder = true
		"deflect_homing":
			has_deflect_homing = true
		"titan_slash":
			has_titan_slash = true
			charge_time_threshold *= 0.5
		"parry_instant_heavy":
			has_instant_heavy_boon = true

## 打铁顿帧 (Hit-stop)
func _trigger_hit_stop(duration_real: float, target_time_scale: float = 0.05) -> void:
	Engine.time_scale = target_time_scale
	await get_tree().create_timer(duration_real, true, false, true).timeout
	Engine.time_scale = 1.0

## 相机微震动 (Screen Shake)
func _shake_camera(intensity: float, duration: float) -> void:
	var tween = create_tween()
	for i in range(4):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(camera, "offset", offset, duration / 4.0)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

## 生成残影
func _spawn_ghost_trail() -> void:
	var ghost = visuals.duplicate() as Node2D
	get_parent().add_child(ghost)
	ghost.global_position = visuals.global_position
	ghost.global_rotation = visuals.global_rotation
	ghost.scale = visuals.scale
	ghost.modulate = Color(0.2, 0.8, 1.0, 0.6)

	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)

## 外部公开接口：相机震动
func shake_camera(intensity: float = 5.0, duration: float = 0.15) -> void:
	_shake_camera(intensity, duration)

## 外部公开接口：设置输入锁定
func set_input_locked(locked: bool) -> void:
	input_locked = locked
	if locked:
		velocity = Vector2.ZERO
		is_holding_attack = false
		_reset_charge_visuals()
		current_state = State.NORMAL

## 密室入场漫步：英雄迈步走入新密室
func walk_to_chamber_entrance(target_pos: Vector2, duration: float = 0.75) -> Tween:
	set_input_locked(true)
	var move_vec = (target_pos - global_position).normalized()
	if move_vec != Vector2.ZERO:
		facing_direction = move_vec
		visuals.rotation = move_vec.angle()

	var tw = create_tween()
	tw.tween_property(self, "global_position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		set_input_locked(false)
	)
	return tw

