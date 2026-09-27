extends Control
class_name BoonSelectUI

signal boon_selected(boon: BoonData)

@onready var cards_container: HBoxContainer = $CenterContainer/VBox/CardsContainer
@onready var title_label: Label = $CenterContainer/VBox/TitleLabel

var current_options: Array[BoonData] = []
var card_buttons: Array[Button] = []
var focused_card_index: int = 0
var stick_navigated: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 保证在游戏暂停时仍能响应交互
	visible = false

## 呼出神力三选一界面（支持定向流派赐福）
func show_selection(acquired_ids: Array[String], target_category: String = "") -> void:
	if title_label == null:
		title_label = $CenterContainer/VBox/TitleLabel
	if cards_container == null:
		cards_container = $CenterContainer/VBox/CardsContainer

	var all_boons = BoonData.get_all_boons()
	var matching_boons: Array[BoonData] = []
	var other_boons: Array[BoonData] = []

	for b in all_boons:
		if not acquired_ids.has(b.id):
			if target_category != "" and b.category == target_category:
				matching_boons.append(b)
			else:
				other_boons.append(b)

	matching_boons.shuffle()
	other_boons.shuffle()

	var available_boons: Array[BoonData] = []
	available_boons.append_array(matching_boons)
	available_boons.append_array(other_boons)

	if available_boons.size() < 3:
		available_boons = all_boons.duplicate()
		available_boons.shuffle()

	current_options = [available_boons[0], available_boons[1], available_boons[2]]

	# 根据流派更新神话标题
	if target_category == "绝命弹反流":
		title_label.text = "— 雅典娜之明眸：神盾秘术赐福 —"
	elif target_category == "残影瞬步流":
		title_label.text = "— 赫尔墨斯之翼：极速神行赐福 —"
	elif target_category == "破灭重斩流":
		title_label.text = "— 弑神锻炉之焰：暴烈重斩赐福 —"
	else:
		title_label.text = "— 奥林匹斯神力三选一 —"

	focused_card_index = 0
	stick_navigated = false
	_render_cards()
	visible = true
	get_tree().paused = true # 暂停游戏时空
	_update_card_visuals()

## 渲染 3 张神话风格卡牌
func _render_cards() -> void:
	# 立即彻底断开并清理上一密室的旧卡牌，严防 deferred queue_free 污染子节点计数与焦点
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
	card_buttons.clear()

	for i in range(current_options.size()):
		var boon = current_options[i]
		var card_btn = _create_card_button(boon, i)
		cards_container.add_child(card_btn)
		card_buttons.append(card_btn)

func _create_card_button(boon: BoonData, index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(310, 360)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_ALL

	# 自定义卡牌神圣边框与深色渐变背景
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	normal_style.border_color = boon.color * 0.75
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.corner_radius_bottom_left = 8
	btn.add_theme_stylebox_override("normal", normal_style)

	var focused_style = normal_style.duplicate() as StyleBoxFlat
	focused_style.bg_color = Color(0.12, 0.16, 0.26, 0.98)
	focused_style.border_color = boon.color.lerp(Color.WHITE, 0.35)
	focused_style.border_width_left = 3
	focused_style.border_width_top = 3
	focused_style.border_width_right = 3
	focused_style.border_width_bottom = 3
	focused_style.shadow_color = Color(boon.color.r, boon.color.g, boon.color.b, 0.55)
	focused_style.shadow_size = 22

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.layout_mode = 1
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. 顶部栏：左侧流派，右侧按键徽章
	var top_bar = HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cat_label = Label.new()
	cat_label.text = "[ " + boon.category + " ]"
	cat_label.add_theme_color_override("font_color", boon.color)
	cat_label.add_theme_font_size_override("font_size", 13)
	top_bar.add_child(cat_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	# 核心操作按键徽章
	var key_panel = PanelContainer.new()
	var key_style = StyleBoxFlat.new()
	key_style.bg_color = Color(boon.color.r, boon.color.g, boon.color.b, 0.22)
	key_style.border_color = boon.color
	key_style.border_width_left = 1
	key_style.border_width_top = 1
	key_style.border_width_right = 1
	key_style.border_width_bottom = 1
	key_style.corner_radius_top_left = 4
	key_style.corner_radius_top_right = 4
	key_style.corner_radius_bottom_right = 4
	key_style.corner_radius_bottom_left = 4
	key_style.content_margin_left = 8
	key_style.content_margin_right = 8
	key_style.content_margin_top = 2
	key_style.content_margin_bottom = 2
	key_panel.add_theme_stylebox_override("panel", key_style)
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var key_lbl = Label.new()
	key_lbl.text = boon.key_slot
	key_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_panel.add_child(key_lbl)
	top_bar.add_child(key_panel)
	vbox.add_child(top_bar)

	# 2. 标题
	var title_lbl = Label.new()
	title_lbl.text = boon.title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_lbl)

	# 3. 分割线
	var hs1 = HSeparator.new()
	hs1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hs1)

	# 4. 极简一句话核心效果描述（直观无冗余，居中高对比展示）
	var desc_margin = MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_top", 14)
	desc_margin.add_theme_constant_override("margin_bottom", 14)
	desc_margin.add_theme_constant_override("margin_left", 8)
	desc_margin.add_theme_constant_override("margin_right", 8)
	desc_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var desc_lbl = Label.new()
	desc_lbl.text = boon.one_sentence_desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.add_theme_constant_override("line_spacing", 8)
	desc_margin.add_child(desc_lbl)
	vbox.add_child(desc_margin)

	# 5. 弹性撑开
	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_spacer)

	# 6. 底部点击引导文本
	var choose_lbl = Label.new()
	choose_lbl.text = "✦ 点击注入此神力 ✦"
	choose_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choose_lbl.add_theme_color_override("font_color", Color(boon.color.r, boon.color.g, boon.color.b, 0.8))
	choose_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(choose_lbl)

	margin.add_child(vbox)
	btn.add_child(margin)

	btn.pivot_offset = Vector2(155, 180)

	# 存储元素引用以供高亮渲染与切换
	btn.set_meta("normal_style", normal_style)
	btn.set_meta("focused_style", focused_style)
	btn.set_meta("choose_lbl", choose_lbl)
	btn.set_meta("boon", boon)
	btn.set_meta("index", index)

	# 绑定点击选择
	btn.pressed.connect(func(): _on_card_selected(index))

	# 鼠标悬停聚焦响应
	btn.mouse_entered.connect(func():
		focused_card_index = index
		_update_card_visuals()
	)

	return btn

## 更新所有卡牌的高亮、缩放与光效 (带视觉 Juicy 动效)
func _update_card_visuals() -> void:
	for i in range(card_buttons.size()):
		var btn = card_buttons[i]
		if not is_instance_valid(btn):
			continue
		var boon = current_options[i] if i < current_options.size() else null
		var normal_style = btn.get_meta("normal_style") as StyleBoxFlat
		var focused_style = btn.get_meta("focused_style") as StyleBoxFlat
		var choose_lbl = btn.get_meta("choose_lbl") as Label
		var is_focused = (i == focused_card_index)

		var tw = btn.create_tween()
		if is_focused:
			btn.z_index = 10
			tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			btn.add_theme_stylebox_override("normal", focused_style)
			btn.add_theme_stylebox_override("hover", focused_style)
			btn.add_theme_stylebox_override("focus", focused_style)
			if choose_lbl:
				choose_lbl.text = "✦ 按 A 键 / 点击 注入神力 ✦"
				choose_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		else:
			btn.z_index = 0
			tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_stylebox_override("hover", focused_style)
			btn.add_theme_stylebox_override("focus", normal_style)
			if choose_lbl and boon:
				choose_lbl.text = "✦ 浏览中 ✦"
				choose_lbl.add_theme_color_override("font_color", Color(boon.color.r, boon.color.g, boon.color.b, 0.6))

## 切换当前高亮聚焦卡牌（循环切换）
func _navigate_cards(delta: int) -> void:
	if card_buttons.is_empty():
		return
	focused_card_index = posmod(focused_card_index + delta, card_buttons.size())
	_update_card_visuals()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# 1. 摇杆模拟轴左右推拉（带 0.5 触发阈值与 0.25 回中复位，防止多段连续跳卡）
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X:
			if event.axis_value > 0.5 and not stick_navigated:
				_navigate_cards(1)
				stick_navigated = true
				get_viewport().set_input_as_handled()
			elif event.axis_value < -0.5 and not stick_navigated:
				_navigate_cards(-1)
				stick_navigated = true
				get_viewport().set_input_as_handled()
			elif abs(event.axis_value) < 0.25:
				stick_navigated = false
		return

	# 2. 十字键 (D-Pad) 与键盘 A/D 或 左/右箭头
	var is_left: bool = false
	var is_right: bool = false

	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			is_left = true
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			is_right = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			is_left = true
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			is_right = true

	if not is_left and not is_right:
		if event.is_action_pressed("ui_left", false):
			is_left = true
		elif event.is_action_pressed("ui_right", false):
			is_right = true

	if is_left:
		_navigate_cards(-1)
		get_viewport().set_input_as_handled()
		return
	elif is_right:
		_navigate_cards(1)
		get_viewport().set_input_as_handled()
		return

	# 3. 按下 A 键或确认键选定当前高亮卡牌
	var is_confirm: bool = false
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		is_confirm = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			is_confirm = true

	if not is_confirm and event.is_action_pressed("ui_accept", false):
		is_confirm = true

	if is_confirm:
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		_on_card_selected(focused_card_index)
		return

func _on_card_selected(index: int) -> void:
	if index >= 0 and index < current_options.size():
		var chosen_boon = current_options[index]
		visible = false
		get_tree().paused = false # 恢复游戏时空
		boon_selected.emit(chosen_boon)
