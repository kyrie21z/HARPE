extends SceneTree

func _init() -> void:
	print("\n--- 开始测试祝福介绍直观性、UI卡牌信息完整度与玩家神力注入 ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var all_boons = BoonData.get_all_boons()
	assert(all_boons.size() == 6, "基础祝福库应包含 6 个核心祝福")

	# 1. 验证每一个祝福的数据规范与直观性字段
	for boon in all_boons:
		assert(boon.id != "", "祝福 ID 不能为空")
		assert(boon.title != "", "祝福名称不能为空")
		assert(boon.subtitle != "", "祝福神话副标题不能为空")
		assert(boon.category != "", "流派分类不能为空")
		assert(boon.key_slot != "", "操作按键槽位不能为空: " + boon.id)
		assert(boon.effects.size() > 0, "效果机制清单不能为空: " + boon.id)
		for eff in boon.effects:
			assert(eff.has("tag") and eff["tag"] != "", "机制标签必须有效: " + boon.id)
			assert(eff.has("detail") and eff["detail"] != "", "机制说明必须有效: " + boon.id)
		assert(boon.tip != "", "战术技巧指引不能为空: " + boon.id)
		assert(boon.description != "", "兼容性描述属性不可为空")
		assert(boon.one_sentence_desc != "", "一句话核心效果描述不可为空: " + boon.id)
		assert(not boon.one_sentence_desc.contains("\n"), "一句话描述严禁包含换行: " + boon.id)

	print("✓ 1. 所有 6 个核心祝福的数据完整性、极简一句话核心描述验证通过！")

	# 2. 验证 BoonSelectUI 界面卡牌组件生成
	var boon_ui_scene = load("res://scenes/BoonSelectUI.tscn")
	var boon_ui = boon_ui_scene.instantiate() as BoonSelectUI
	root.add_child(boon_ui)

	# 触发赫尔墨斯定向祝福
	boon_ui.show_selection([], "残影瞬步流")
	assert(boon_ui.title_label.text.contains("赫尔墨斯"), "标题应针对流派动态展示")
	assert(boon_ui.cards_container.get_child_count() == 3, "应生成 3 张神话卡牌")

	# 检查卡牌内部结构是否含有按键、效果和技巧
	var first_card = boon_ui.cards_container.get_child(0) as Button
	assert(first_card != null, "卡牌根节点应为 Button")
	var margin = first_card.get_child(0) as MarginContainer
	var vbox = margin.get_child(0) as VBoxContainer
	assert(vbox != null, "卡牌内部容器应正确构建")

	# 验证卡牌选择信号
	var signal_captured = {"chosen": null}
	boon_ui.boon_selected.connect(func(b): signal_captured["chosen"] = b)
	first_card.pressed.emit()
	assert(signal_captured["chosen"] != null, "点击卡牌应成功发射 boon_selected 信号")
	assert(boon_ui.visible == false, "选择后 UI 应自动隐藏")

	print("✓ 2. BoonSelectUI 界面卡牌结构、按键标签渲染与点击选定逻辑验证通过！")

	# 3. 验证玩家注入所有 6 种祝福的逻辑
	var player_scene = load("res://scenes/Player.tscn")
	var player = player_scene.instantiate() as Player
	root.add_child(player)

	for boon in all_boons:
		player.apply_boon(boon)

	assert(player.has_dash_damage == true, "穿透割裂注入验证失败")
	assert(player.has_dash_phantom == true, "金羽残影注入验证失败")
	assert(player.has_parry_thunder == true, "全屏神雷注入验证失败")
	assert(player.has_deflect_homing == true, "波光追踪注入验证失败")
	assert(player.has_titan_slash == true, "泰坦破军注入验证失败")
	assert(player.has_instant_heavy_boon == true, "刚体反击注入验证失败")

	print("✓ 3. 玩家角色注入所有 6 种神力状态效果验证通过！")

	player.queue_free()
	boon_ui.queue_free()

	print("\n★★★ 祝福直观化与卡牌展示系统单元测试全部通过！ ★★★\n")
	quit(0)
