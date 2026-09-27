extends Node
class_name WaveManager

signal wave_started(wave_num: int, total_waves: int, enemy_count: int)
signal enemy_count_changed(remaining: int)
signal wave_cleared(wave_num: int)
signal all_waves_completed()

const ENEMY_MELEE_SCENE = preload("res://scenes/EnemyMelee.tscn")
const ENEMY_RANGED_SCENE = preload("res://scenes/EnemyRanged.tscn")

@export var max_waves: int = 3
var current_wave: int = 0
var remaining_enemies: int = 0
var is_wave_cleared: bool = false

var enemies_container: Node2D = null

func setup(container: Node2D) -> void:
	enemies_container = container

## 启动下一波次
func start_next_wave() -> void:
	is_wave_cleared = false
	current_wave += 1
	if current_wave > max_waves:
		all_waves_completed.emit()
		return

	_spawn_wave_enemies(current_wave)

func _spawn_wave_enemies(wave: int) -> void:
	var spawn_specs: Array[Dictionary] = []

	match wave:
		1:
			# 第 1 波（试炼）：2 只近战狂暴怪，练习近战弹反
			spawn_specs = [
				{"type": "melee", "pos": Vector2(300, 40), "elite": false},
				{"type": "melee", "pos": Vector2(-300, -40), "elite": false}
			]
		2:
			# 第 2 波（阵列）：1 只近战 + 2 只远程祭司，练习镜面折射
			spawn_specs = [
				{"type": "melee", "pos": Vector2(0, -220), "elite": false},
				{"type": "ranged", "pos": Vector2(360, 180), "elite": false},
				{"type": "ranged", "pos": Vector2(-360, 180), "elite": false}
			]
		3:
			# 第 3 波（决战）：2 只强化狂暴怪 + 2 只远程祭司合围
			spawn_specs = [
				{"type": "melee", "pos": Vector2(320, 80), "elite": true},
				{"type": "melee", "pos": Vector2(-320, -80), "elite": true},
				{"type": "ranged", "pos": Vector2(380, -220), "elite": false},
				{"type": "ranged", "pos": Vector2(-380, 220), "elite": false}
			]

	remaining_enemies = spawn_specs.size()
	wave_started.emit(current_wave, max_waves, remaining_enemies)

	for spec in spawn_specs:
		_instantiate_enemy(spec)

func _instantiate_enemy(spec: Dictionary) -> void:
	if not enemies_container:
		return

	var enemy_node: CharacterBody2D = null
	if spec["type"] == "melee":
		enemy_node = ENEMY_MELEE_SCENE.instantiate() as EnemyMelee
		if spec.get("elite", false):
			enemy_node.is_elite = true
			enemy_node.max_hp = 95.0
			enemy_node.current_hp = 95.0
			enemy_node.scale = Vector2(1.25, 1.25)
	else:
		enemy_node = ENEMY_RANGED_SCENE.instantiate() as EnemyRanged

	enemies_container.add_child(enemy_node)
	enemy_node.global_position = spec["pos"]

	# 监听敌人击败信号以统计存活数（严禁使用 tree_exited，避免重开场景时触发误结算）
	enemy_node.defeated.connect(_on_enemy_defeated)

func _on_enemy_defeated(_enemy: Node2D = null) -> void:
	if not is_inside_tree() or is_wave_cleared:
		return
	remaining_enemies -= 1
	enemy_count_changed.emit(max(0, remaining_enemies))

	if remaining_enemies <= 0:
		is_wave_cleared = true
		remaining_enemies = 0
		wave_cleared.emit(current_wave)

