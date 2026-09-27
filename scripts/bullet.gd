extends Area2D
class_name Projectile

@export var speed: float = 240.0
@export var damage: float = 15.0

var direction: Vector2 = Vector2.RIGHT
var is_reflected: bool = false
var has_hit_target: bool = false
var lifetime: float = 5.0

@onready var visual_normal: Polygon2D = $VisualNormal
@onready var visual_reflected: Polygon2D = $VisualReflected

func _ready() -> void:
	# 5秒后自动销毁
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

## 被左手镜盾弹反偏折 (Deflected / Reflected)
func deflect(new_dir: Vector2) -> void:
	if is_reflected:
		return
	is_reflected = true
	has_hit_target = false # 反弹后重置命中标记，以便命中恶灵
	direction = new_dir
	speed *= 1.8 # 反弹后速度暴增 1.8 倍
	damage *= 2.5 # 反弹伤害翻倍

	# 改变视觉流光：从原先的石化紫红色变成青铜神镜的破邪金蓝色
	if visual_normal:
		visual_normal.visible = false
	if visual_reflected:
		visual_reflected.visible = true

	# 切换碰撞层：不再打玩家，变成专打怪物
	set_collision_layer_value(5, false) # 关闭敌方子弹层
	set_collision_mask_value(2, false)  # 不再打玩家
	set_collision_mask_value(3, true)   # 击中怪物层

func _on_area_entered(area: Area2D) -> void:
	if has_hit_target:
		return
	# 如果击中怪物的 Hurtbox
	if is_reflected and area.is_in_group("enemy_hurtbox"):
		has_hit_target = true
		var enemy = area.get_parent()
		if enemy and enemy.has_method("take_damage"):
			enemy.take_damage(damage, direction * 300.0, 0.35)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if has_hit_target:
		return

	if body is TileMap or body is StaticBody2D:
		has_hit_target = true
		# 撞墙消散
		queue_free()
	elif not is_reflected and body is Player:
		# 优先检查玩家当前是否正处于举盾招架有效判定中
		if body.has_method("is_parrying_active") and body.is_parrying_active():
			has_hit_target = true
			var deflect_target = body.facing_direction
			if body.has_deflect_homing:
				var closest = body._find_closest_enemy()
				if closest:
					deflect_target = (closest.global_position - global_position).normalized()
			deflect(deflect_target)
			body.on_parry_success(global_position)
			return

		has_hit_target = true
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		queue_free()
