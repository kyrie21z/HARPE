extends Button
class_name RestartButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_ALL
	pivot_offset = Vector2(custom_minimum_size.x / 2.0, custom_minimum_size.y / 2.0) if custom_minimum_size != Vector2.ZERO else size / 2.0

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(grab_focus)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		call_deferred("grab_focus")

func _on_focus_entered() -> void:
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_focus_exited() -> void:
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	# 支持手柄 A 键、ui_accept、Enter、Space 直接触发重开
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
		pressed.emit()
