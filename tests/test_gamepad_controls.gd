extends SceneTree

const RestartButton = preload("res://scripts/restart_button.gd")

func _init() -> void:
	print("\n--- 开始测试精准手柄映射 (弹反B/攻击X/瞬步A)、神力选定及死亡/胜利界面手柄重新开始闭环 ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# 1. 验证用户严格指定的 InputMap 手柄键位映射
	# 弹反 -> B (JOY_BUTTON_B = 1)
	# 攻击 -> X (JOY_BUTTON_X = 2)
	# 瞬步 -> A (JOY_BUTTON_A = 0)
	assert(InputMap.has_action("parry"), "InputMap 必须包含 parry 动作")
	var parry_events = InputMap.action_get_events("parry")
	var has_b_parry = false
	var has_forbidden_parry_buttons = false
	for ev in parry_events:
		if ev is InputEventJoypadButton:
			if ev.button_index == JOY_BUTTON_B:
				has_b_parry = true
			elif ev.button_index in [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER]:
				has_forbidden_parry_buttons = true
	assert(has_b_parry, "parry 动作必须包含手柄 B 键 (JOY_BUTTON_B = 1)")
	assert(not has_forbidden_parry_buttons, "parry 动作严禁包含 RB/Y/LB 等冗余按键")

	assert(InputMap.has_action("attack"), "InputMap 必须包含 attack 动作")
	var attack_events = InputMap.action_get_events("attack")
	var has_x_attack = false
	for ev in attack_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_X:
			has_x_attack = true
	assert(has_x_attack, "attack 动作必须包含手柄 X 键 (JOY_BUTTON_X = 2)")

	assert(InputMap.has_action("dash"), "InputMap 必须包含 dash 动作")
	var dash_events = InputMap.action_get_events("dash")
	var has_a_dash = false
	var has_b_in_dash = false
	for ev in dash_events:
		if ev is InputEventJoypadButton:
			if ev.button_index == JOY_BUTTON_A:
				has_a_dash = true
			elif ev.button_index in [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER]:
				has_b_in_dash = true
	assert(has_a_dash, "dash 动作必须包含手柄 A 键 (JOY_BUTTON_A = 0)")
	assert(not has_b_in_dash, "dash 动作严禁包含 B 键或 RB 键")

	# ui_accept 包含手柄 A 键
	assert(InputMap.has_action("ui_accept"), "InputMap 必须包含 ui_accept")
	var accept_events = InputMap.action_get_events("ui_accept")
	var has_a_accept = false
	for ev in accept_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A:
			has_a_accept = true
	assert(has_a_accept, "ui_accept 必须包含手柄 A 键 (JOY_BUTTON_A = 0)")

	print("✓ 1. InputMap 精准键位绑定校验通过：弹反->B，攻击->X，瞬步->A，确认->A！")

	# 2. 验证玩家角色输入模式热切换与中立瞬步
	var player_scene = load("res://scenes/Player.tscn")
	var player = player_scene.instantiate() as Player
	root.add_child(player)

	var mouse_event = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	player._input(mouse_event)
	assert(player.is_using_gamepad == false, "接收鼠标输入后必须切换为键鼠模式")

	var joy_event = InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_A
	joy_event.pressed = true
	player._input(joy_event)
	assert(player.is_using_gamepad == true, "接收手柄输入后必须切换为手柄模式")

	player.facing_direction = Vector2.UP
	player._snap_to_aim()
	assert(player.facing_direction == Vector2.UP, "手柄回中时面朝方向不吸附鼠标")

	player._start_dash(Vector2.ZERO, false)
	assert(player.dash_direction == Vector2.UP, "手柄回中瞬步朝面朝方向")

	print("✓ 2. 玩家手柄输入检测与瞄准/瞬步行为校验通过！")

	# 3. 验证 BoonSelectUI：第一关摇杆左右切换与按下 A 键选定
	var boon_ui_scene = load("res://scenes/BoonSelectUI.tscn")
	var boon_ui = boon_ui_scene.instantiate() as BoonSelectUI
	root.add_child(boon_ui)

	var selected_box = {"boon": null}
	boon_ui.boon_selected.connect(func(b): selected_box["boon"] = b)

	boon_ui.show_selection([])
	assert(boon_ui.cards_container.get_child_count() == 3, "第一关应生成 3 张卡牌")
	assert(boon_ui.focused_card_index == 0, "初始默认聚焦第 0 张卡牌")

	# 模拟左摇杆向右推 (JOY_AXIS_LEFT_X = 1.0)
	var stick_right = InputEventJoypadMotion.new()
	stick_right.axis = JOY_AXIS_LEFT_X
	stick_right.axis_value = 1.0
	boon_ui._input(stick_right)
	assert(boon_ui.focused_card_index == 1, "摇杆向右推应切换至第 1 张卡牌")

	# 摇杆回中
	var stick_center = InputEventJoypadMotion.new()
	stick_center.axis = JOY_AXIS_LEFT_X
	stick_center.axis_value = 0.0
	boon_ui._input(stick_center)

	# 验证 X/Y/B 等旧快捷键被禁用（不再直接选定卡牌）
	var joy_x = InputEventJoypadButton.new()
	joy_x.button_index = JOY_BUTTON_X
	joy_x.pressed = true
	boon_ui._input(joy_x)
	assert(selected_box["boon"] == null, "按 X 键不应直接选卡，必须统一按 A 键选定")
	assert(boon_ui.visible == true, "UI 应保持开启")

	# 模拟按下手柄 A 键确认选定
	var joy_a = InputEventJoypadButton.new()
	joy_a.button_index = JOY_BUTTON_A
	joy_a.pressed = true
	boon_ui._input(joy_a)

	assert(selected_box["boon"] != null, "第一关按下 A 键必须成功选定卡牌！")
	assert(selected_box["boon"].id == boon_ui.current_options[1].id, "选定的神力必须为高亮的第 1 张卡牌")
	assert(boon_ui.visible == false, "选定后 UI 隐藏")

	print("✓ 3. 第一关：摇杆左右切换卡牌 + 按下 A 键选定闭环测试完全成功！")

	# 4. 验证后续关卡（第二关）：解决卡牌重叠与十字键选择及 A 键确认失效 bug
	selected_box["boon"] = null
	boon_ui.show_selection([selected_box["boon"] if selected_box["boon"] else "dash_damage"], "绝命弹反流")
	assert(boon_ui.cards_container.get_child_count() == 3, "第二关卡牌数量必须精准为 3（旧卡牌已彻底清除）")
	assert(boon_ui.focused_card_index == 0, "第二关重新呼出默认聚焦第 0 张卡牌")

	# 模拟十字键右 (D-Pad Right = 14)
	var dpad_right = InputEventJoypadButton.new()
	dpad_right.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad_right.pressed = true
	boon_ui._input(dpad_right)
	assert(boon_ui.focused_card_index == 1, "第二关十字键右应切换至第 1 张卡牌")

	# 模拟十字键右再次按下 -> 第 2 张卡牌
	boon_ui._input(dpad_right)
	assert(boon_ui.focused_card_index == 2, "第二关十字键右再次按下应切换至第 2 张卡牌")

	# 按下手柄 A 键确认选定第 2 张卡牌
	boon_ui._input(joy_a)
	assert(selected_box["boon"] != null, "第二关按下 A 键必须成功选定卡牌！")
	assert(selected_box["boon"].id == boon_ui.current_options[2].id, "第二关选定的神力必须为高亮的第 2 张卡牌")
	assert(boon_ui.visible == false, "第二关选定后 UI 隐藏")

	print("✓ 4. 后续关卡：彻底解决卡牌残留与选择/选定失效 Bug，十字键与 A 键表现稳健！")

	# 5. 验证第三关：摇杆循环回环 (Wrap-around) 与选定
	selected_box["boon"] = null
	boon_ui.show_selection([], "破灭重斩流")
	assert(boon_ui.cards_container.get_child_count() == 3, "第三关卡牌数量精准为 3")

	# 模拟左摇杆向左推 (JOY_AXIS_LEFT_X = -1.0) -> 从 0 循环切换至 2
	var stick_left = InputEventJoypadMotion.new()
	stick_left.axis = JOY_AXIS_LEFT_X
	stick_left.axis_value = -1.0
	boon_ui._input(stick_left)
	assert(boon_ui.focused_card_index == 2, "摇杆左推应循环切换至末尾第 2 张卡牌")

	# 按下手柄 A 键确认
	boon_ui._input(joy_a)
	assert(selected_box["boon"] != null, "第三关按下 A 键必须成功选定卡牌！")
	assert(selected_box["boon"].id == boon_ui.current_options[2].id, "选定卡牌与循环高亮匹配")

	print("✓ 5. 第三关：循环切换与多关卡高频调用测试全部通过！")

	# 6. 验证死亡与大捷界面：手柄支持直接按 A 键或确认键重新开始
	var main_scene = load("res://scenes/Main.tscn")
	var main_inst = main_scene.instantiate()
	root.add_child(main_inst)

	var victory_panel = main_inst.get_node("UI/VictoryPanel") as Control
	var defeat_panel = main_inst.get_node("UI/DefeatPanel") as Control
	var victory_btn = victory_panel.get_node("Center/VBox/RestartBtn") as Button
	var defeat_btn = defeat_panel.get_node("Center/VBox/RestartBtn") as Button

	assert(victory_btn is RestartButton, "VictoryPanel RestartBtn 必须挂载 RestartButton 脚本组件")
	assert(defeat_btn is RestartButton, "DefeatPanel RestartBtn 必须挂载 RestartButton 脚本组件")

	# 模拟死亡界面唤起：
	defeat_panel.visible = true
	var defeat_restart_box = {"triggered": false}
	defeat_btn.pressed.connect(func(): defeat_restart_box["triggered"] = true)

	# 模拟手柄按下 A 键
	defeat_btn._input(joy_a)
	assert(defeat_restart_box["triggered"] == true, "死亡界面下按下手柄 A 键必须成功触发重开！")
	defeat_panel.visible = false

	# 模拟大捷界面唤起：
	victory_panel.visible = true
	var victory_restart_box = {"triggered": false}
	victory_btn.pressed.connect(func(): victory_restart_box["triggered"] = true)

	# 模拟手柄按下 A 键
	victory_btn._input(joy_a)
	assert(victory_restart_box["triggered"] == true, "大捷界面下按下手柄 A 键必须成功触发重开！")
	victory_panel.visible = false

	print("✓ 6. 死亡界面与大捷通关界面：手柄 A 键与确认键无缝重开验证通过！")

	# 清理
	player.queue_free()
	boon_ui.queue_free()
	main_inst.queue_free()

	print("\n★★★ 手柄精准映射(弹反B/攻击X/瞬步A)、神力选定与结算面板重开测试全部通过！ ★★★\n")
	quit(0)
