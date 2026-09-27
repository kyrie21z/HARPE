extends Node2D
class_name Door

signal player_entered(door: Door)

enum Direction { NORTH, SOUTH, WEST, EAST }
enum State { LOCKED, CLOSED, OPEN }
enum RewardType { ATHENA, HERMES, FORGE, HEAL, FINAL }

@export var direction: Direction = Direction.NORTH
@export var reward_type: RewardType = RewardType.ATHENA
var current_state: State = State.LOCKED

@onready var gate_slab: Polygon2D = $Visuals/GateSlab
@onready var portal_light: Polygon2D = $Visuals/PortalLight
@onready var trigger_area: Area2D = $TriggerArea
@onready var physical_barrier: StaticBody2D = $PhysicalBarrier

@onready var reward_badge: Node2D = $RewardBadge
@onready var badge_border: Line2D = $RewardBadge/BadgeBorder
@onready var reward_title: Label = $RewardBadge/RewardTitle
@onready var reward_desc: Label = $RewardBadge/RewardDesc
@onready var icon_shield: Polygon2D = $RewardBadge/IconAnchor/IconShield
@onready var icon_wing: Polygon2D = $RewardBadge/IconAnchor/IconWing
@onready var icon_blade: Polygon2D = $RewardBadge/IconAnchor/IconBlade
@onready var icon_chalice: Polygon2D = $RewardBadge/IconAnchor/IconChalice
@onready var icon_crown: Polygon2D = $RewardBadge/IconAnchor/IconCrown

func _ready() -> void:
	trigger_area.body_entered.connect(_on_trigger_body_entered)
	lock_gate()

## 获取角色从门走入场内的起始点（全局坐标）
func get_spawn_position() -> Vector2:
	return to_global(Vector2(0, 5))

## 获取角色走入场内的目标点（全局坐标）
func get_entry_target_position() -> Vector2:
	return to_global(Vector2(0, 140))

## 作为入场门：开启闸门供玩家入室，但禁用离开触发
func open_as_entrance() -> void:
	current_state = State.OPEN
	if reward_badge:
		reward_badge.visible = false
	trigger_area.monitoring = false
	if physical_barrier:
		physical_barrier.collision_layer = 0
		var shape_node = physical_barrier.get_node_or_null("CollisionShape2D")
		if shape_node:
			shape_node.set_deferred("disabled", true)

	portal_light.color = Color(0.4, 0.85, 1.0, 0.45)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(gate_slab, "position:y", -45.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(portal_light, "modulate:a", 0.6, 0.3)

## 作为出口门：神光大放，升起专属神印徽章，开启触发区域，允许玩家前往下一室
func open_as_exit(title_text: String = "✦ 雅典娜·镜盾 ✦", p_reward: RewardType = RewardType.ATHENA, light_color: Color = Color(0.4, 0.85, 1.0), desc_text: String = "弹反神力三选一") -> void:
	current_state = State.OPEN
	reward_type = p_reward
	if reward_badge:
		reward_badge.global_rotation = 0.0
		badge_border.default_color = light_color
		reward_title.text = title_text
		reward_title.add_theme_color_override("font_color", light_color)
		reward_desc.text = desc_text

		# 切换神明/战利品图标
		icon_shield.visible = (p_reward == RewardType.ATHENA)
		icon_wing.visible = (p_reward == RewardType.HERMES)
		icon_blade.visible = (p_reward == RewardType.FORGE)
		icon_chalice.visible = (p_reward == RewardType.HEAL)
		icon_crown.visible = (p_reward == RewardType.FINAL)

		reward_badge.visible = true

	trigger_area.monitoring = true
	if physical_barrier:
		physical_barrier.collision_layer = 0
		var shape_node = physical_barrier.get_node_or_null("CollisionShape2D")
		if shape_node:
			shape_node.set_deferred("disabled", true)

	portal_light.color = light_color

	var tw = create_tween().set_parallel(true)
	tw.tween_property(gate_slab, "position:y", -45.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(portal_light, "modulate:a", 1.0, 0.4)
	tw.tween_property(portal_light, "scale", Vector2(1.1, 1.2), 0.5)

## 关闭石门（重重合拢，锁住房间战场）
func close_gate() -> void:
	current_state = State.CLOSED
	if reward_badge:
		reward_badge.visible = false
	trigger_area.monitoring = false
	if physical_barrier:
		physical_barrier.collision_layer = 1
		var shape_node = physical_barrier.get_node_or_null("CollisionShape2D")
		if shape_node:
			shape_node.set_deferred("disabled", false)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(gate_slab, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(portal_light, "modulate:a", 0.0, 0.2)
	tw.tween_property(portal_light, "scale", Vector2.ONE, 0.2)

## 封锁石门（常态无光，完全封闭）
func lock_gate() -> void:
	current_state = State.LOCKED
	if reward_badge:
		reward_badge.visible = false
	trigger_area.monitoring = false
	if physical_barrier:
		physical_barrier.collision_layer = 1
		var shape_node = physical_barrier.get_node_or_null("CollisionShape2D")
		if shape_node:
			shape_node.set_deferred("disabled", false)
	gate_slab.position.y = 0.0
	portal_light.modulate.a = 0.0
	portal_light.scale = Vector2.ONE

func _on_trigger_body_entered(body: Node2D) -> void:
	if current_state == State.OPEN and (body is Player or body.is_in_group("player")):
		trigger_area.set_deferred("monitoring", false)
		player_entered.emit(self)
