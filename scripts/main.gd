extends Node2D


@onready var player: Player = $Player
@onready var enemies_container: Node2D = $Enemies
@onready var wave_manager: WaveManager = $WaveManager

# 门节点引用：南面入口门，北壁并列 3 扇出口门
@onready var door_south: Door = $Doors/DoorSouth
@onready var door_north_left: Door = $Doors/DoorNorthLeft
@onready var door_north_center: Door = $Doors/DoorNorthCenter
@onready var door_north_right: Door = $Doors/DoorNorthRight

var exit_doors: Array[Door] = []
var all_doors: Array[Door] = []

# UI 引用
@onready var player_hp_bar: ProgressBar = $UI/HUD/Panel/VBox/PlayerHP
@onready var wave_label: Label = $UI/HUD/Panel/VBox/WaveInfo
@onready var enemies_label: Label = $UI/HUD/Panel/VBox/EnemiesInfo
@onready var boon_select_ui: BoonSelectUI = $UI/BoonSelectUI
@onready var fade_overlay: ColorRect = $UI/FadeOverlay
@onready var victory_panel: Control = $UI/VictoryPanel
@onready var defeat_panel: Control = $UI/DefeatPanel
@onready var victory_restart_btn: Button = $UI/VictoryPanel/Center/VBox/RestartBtn
@onready var defeat_restart_btn: Button = $UI/DefeatPanel/Center/VBox/RestartBtn
@onready var wave_banner: Label = $UI/WaveBanner

# 密室与转场状态
var current_chamber: int = 1
var max_chambers: int = 3
var is_transitioning: bool = false
var pending_reward = null

func _ready() -> void:
	# 强制重置时间缩放与暂停状态，防止上一局残存状态污染
	Engine.time_scale = 1.0
	victory_panel.visible = false
	defeat_panel.visible = false
	wave_banner.visible = false

	# 1. 初始化石门引用与进入信号连接
	exit_doors = [door_north_left, door_north_center, door_north_right]
	all_doors = [door_south, door_north_left, door_north_center, door_north_right]

	for door: Door in all_doors:
		door.lock_gate()
		door.player_entered.connect(_on_door_entered)

	# 2. 玩家生命与死亡监听
	if player:
		player.hp_changed.connect(_on_player_hp_changed)
		player.player_died.connect(_on_player_died)

	# 3. 波次调度器配置与监听
	wave_manager.setup(enemies_container)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.enemy_count_changed.connect(_on_enemy_count_changed)
	wave_manager.wave_cleared.connect(_on_wave_cleared)

	# 4. 三选一神力强化监听
	boon_select_ui.boon_selected.connect(_on_boon_selected)

	# 5. 重开按钮绑定
	victory_restart_btn.pressed.connect(_restart_game)
	defeat_restart_btn.pressed.connect(_restart_game)

	# 6. 开局黑幕淡出并从南面石门迈入密室
	fade_overlay.modulate.a = 1.0
	var fade_tw = create_tween()
	fade_tw.tween_property(fade_overlay, "modulate:a", 0.0, 0.45)
	_enter_chamber()

## 英雄迈入密室核心流程（始终自南面石门跨入室内）
func _enter_chamber() -> void:
	is_transitioning = true

	# 初始全部石门锁闭
	for door: Door in all_doors:
		door.lock_gate()

	# 英雄就位于南门起点，重置相机平滑追踪
	player.global_position = door_south.get_spawn_position()
	if player.camera:
		player.camera.reset_smoothing()

	# 南面入场门升起放行
	door_south.open_as_entrance()

	# 英雄跨步迈入室内
	var entry_target = door_south.get_entry_target_position()
	var tw = player.walk_to_chamber_entrance(entry_target, 0.75)
	await tw.finished

	# 入场门轰然闭合封锁战场
	door_south.close_gate()
	player.shake_camera(5.0, 0.15)
	is_transitioning = false

	# 启动当前密室恶灵潮
	wave_manager.start_next_wave()

func _on_player_hp_changed(current: float, max_value: float) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = max_value
		player_hp_bar.value = current

func _on_wave_started(wave_num: int, total_waves: int, enemy_count: int) -> void:
	wave_label.text = "密室进度：第 " + str(wave_num) + " / " + str(total_waves) + " 室"
	enemies_label.text = "剩余恶灵：" + str(enemy_count) + " 只"
	enemies_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4, 1))
	_show_wave_banner("— 第 " + str(wave_num) + " 室 恶灵降临 —")

func _on_enemy_count_changed(remaining: int) -> void:
	enemies_label.text = "剩余恶灵：" + str(max(0, remaining)) + " 只"

## 房间清场：兑现前室预选战利品，并开启北壁出口（展示下室奖励）
func _on_wave_cleared(wave_num: int) -> void:
	_show_wave_banner("✦ 第 " + str(wave_num) + " 室 肃清！✦")

	# 1. 如果有前一室石门预定的奖励，在此兑现！
	if pending_reward != null:
		await _deliver_pending_reward()
	elif wave_num == 1:
		# 第一室开局奖励：通用神力三选一
		await get_tree().create_timer(0.6, true, false, true).timeout
		boon_select_ui.show_selection(player.acquired_boons)
		await boon_select_ui.boon_selected

	# 2. 开启北壁并列出口石门（1~3 扇一字排开，展示下室承诺奖励）
	_open_exit_doors()

## 兑现前一关选门承诺的战利品
func _deliver_pending_reward() -> void:
	var reward = pending_reward
	pending_reward = null

	match reward:
		Door.RewardType.HEAL:
			player.heal_and_boost_max_hp(40.0, 15.0)
			_show_wave_banner("✦ 饮下仙馔密酒：生命值已回复，上限提升！✦")
			player.shake_camera(3.0, 0.2)
			await get_tree().create_timer(1.2, true, false, true).timeout
		Door.RewardType.ATHENA:
			await get_tree().create_timer(0.5, true, false, true).timeout
			boon_select_ui.show_selection(player.acquired_boons, "绝命弹反流")
			await boon_select_ui.boon_selected
		Door.RewardType.HERMES:
			await get_tree().create_timer(0.5, true, false, true).timeout
			boon_select_ui.show_selection(player.acquired_boons, "残影瞬步流")
			await boon_select_ui.boon_selected
		Door.RewardType.FORGE:
			await get_tree().create_timer(0.5, true, false, true).timeout
			boon_select_ui.show_selection(player.acquired_boons, "破灭重斩流")
			await boon_select_ui.boon_selected

func _on_boon_selected(boon: BoonData) -> void:
	player.apply_boon(boon)
	_show_wave_banner("已注入神力：" + boon.title)

## 开启北壁并列出口石门（1~3 扇一字排开，每扇标明下室专属战利品）
func _open_exit_doors() -> void:
	door_south.lock_gate()

	var is_final_chamber: bool = (current_chamber >= max_chambers)

	# 随机开启 1 到 3 扇出口门（一字排开）
	var exit_count: int = randi_range(1, 3)
	var chosen_doors: Array[Door] = []
	if exit_count == 1:
		chosen_doors = [door_north_center]
	elif exit_count == 2:
		chosen_doors = [door_north_left, door_north_right]
	else:
		chosen_doors = [door_north_left, door_north_center, door_north_right]

	# 仅锁闭未被选中的出口门，严禁对即将开启的门执行冗余 lock_gate
	for door in exit_doors:
		if not door in chosen_doors:
			door.lock_gate()

	if is_final_chamber:
		for door in chosen_doors:
			door.open_as_exit("✦ 凯旋之门 ✦", Door.RewardType.FINAL, Color(1.0, 0.85, 0.3), "登峰造极·试炼大捷")
		enemies_label.text = "✦ 凯旋之门已开启：北壁一字列开 ✦"
		enemies_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1))
		_show_wave_banner("✦ 最终密室已破！迈入北壁凯旋之门 ✦")
		return

	# 随机挑选不重复的奖励类型分配给开启的门
	var reward_pool = [
		{"type": Door.RewardType.ATHENA, "name": "雅典娜 · 镜盾", "color": Color(0.4, 0.85, 1.0), "desc": "镜盾弹反神力"},
		{"type": Door.RewardType.HERMES, "name": "赫尔墨斯 · 飞羽", "color": Color(1.0, 0.75, 0.2), "desc": "极速瞬步神力"},
		{"type": Door.RewardType.FORGE, "name": "弑神锻炉 · 弯刃", "color": Color(1.0, 0.35, 0.25), "desc": "暴烈重斩神力"},
		{"type": Door.RewardType.HEAL, "name": "仙馔密酒 · 圣杯", "color": Color(0.3, 0.95, 0.5), "desc": "回血+上限提升"},
	]
	reward_pool.shuffle()

	var door_names: Array[String] = []
	for i in range(chosen_doors.size()):
		var door = chosen_doors[i]
		var reward_info = reward_pool[i]
		door.open_as_exit(reward_info["name"], reward_info["type"], reward_info["color"], reward_info["desc"])
		door_names.append("【" + reward_info["name"] + "】")

	var summary_text = " ".join(door_names)
	enemies_label.text = "✦ 北壁出口已开：" + summary_text + " ✦"
	enemies_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1))
	_show_wave_banner("✦ 道路已开！北壁并列之门，请选择你的造化 ✦")

## 玩家穿过开启的石门
func _on_door_entered(chosen_door: Door) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	player.set_input_locked(true)

	if current_chamber >= max_chambers or chosen_door.reward_type == Door.RewardType.FINAL:
		_show_victory()
		return

	# 记录该门所承诺的下室战利品
	pending_reward = chosen_door.reward_type
	_transition_to_next_chamber()

## 密室转场：黑屏过渡、进入新密室（北出南入，纵深推进）
func _transition_to_next_chamber() -> void:
	var tw = create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.35)
	await tw.finished

	current_chamber += 1

	# 清理上一密室残留敌人和弹幕
	for child in enemies_container.get_children():
		child.queue_free()

	var tw_in = create_tween()
	tw_in.tween_property(fade_overlay, "modulate:a", 0.0, 0.35)

	# 英雄自南面石门步入新密室
	await _enter_chamber()

## 空间连续性方向映射辅助函数
func _get_opposite_direction(dir: Door.Direction) -> Door.Direction:
	match dir:
		Door.Direction.NORTH:
			return Door.Direction.SOUTH
		Door.Direction.SOUTH:
			return Door.Direction.NORTH
		Door.Direction.WEST:
			return Door.Direction.EAST
		Door.Direction.EAST:
			return Door.Direction.WEST
	return Door.Direction.SOUTH

func _show_victory() -> void:
	Engine.time_scale = 1.0
	var tw = create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 0.75, 0.5)
	await tw.finished
	get_tree().paused = true
	victory_panel.visible = true
	victory_restart_btn.call_deferred("grab_focus")

func _on_player_died() -> void:
	Engine.time_scale = 1.0
	if not is_inside_tree() or get_tree() == null:
		return
	get_tree().paused = true
	defeat_panel.visible = true
	defeat_restart_btn.call_deferred("grab_focus")

func _restart_game() -> void:
	Engine.time_scale = 1.0
	if get_tree():
		get_tree().paused = false
		if get_tree().current_scene:
			get_tree().call_deferred("reload_current_scene")

func _show_wave_banner(text: String) -> void:
	if not wave_banner:
		return
	wave_banner.text = text
	wave_banner.visible = true
	wave_banner.modulate = Color(1, 1, 1, 1)
	var tw = create_tween()
	tw.tween_property(wave_banner, "modulate:a", 0.0, 1.2).set_delay(1.0)
	tw.tween_callback(func(): wave_banner.visible = false)
