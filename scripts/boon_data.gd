class_name BoonData
extends RefCounted

var id: String = ""
var title: String = ""
var subtitle: String = ""
var category: String = ""
var key_slot: String = ""
var effects: Array[Dictionary] = [] # [{"tag": "机制名", "detail": "具体数值与机制说明"}]
var tip: String = ""
var color: Color = Color.WHITE

## 极简一句话核心效果描述（直观无冗余）
var one_sentence_desc: String:
	get:
		match id:
			"dash_damage":
				return "冲刺斩伤害提升至 50 点，且瞬步冷却大幅缩短 40%。"
			"dash_phantom":
				return "瞬步在原地留下一尊石雕嘲讽敌人并吸收一次攻击。"
			"parry_thunder":
				return "成功弹反时降下天威神雷，对全屏所有敌人造成 40 点伤害并击晕。"
			"deflect_homing":
				return "弹反的魔矢自动锁定最近敌人弱点自导反击，造成 2.5 倍暴击伤害。"
			"titan_slash":
				return "破灭重斩蓄力时间减半，且重斩伤害大幅提升至 100 点。"
			"parry_instant_heavy":
				return "成功弹反后重置瞬步，且下一次攻击免蓄力直接轰出 70 伤破灭重斩。"
			_:
				return description

## 兼容性只读属性：返回组合后的纯文本描述
var description: String:
	get:
		var lines: Array[String] = []
		for eff in effects:
			lines.append("• " + eff.get("tag", "") + "：" + eff.get("detail", ""))
		return "\n".join(lines)

func _init(
	p_id: String,
	p_title: String,
	p_subtitle: String,
	p_cat: String,
	p_key: String,
	p_effects: Array[Dictionary],
	p_tip: String,
	p_color: Color
) -> void:
	id = p_id
	title = p_title
	subtitle = p_subtitle
	category = p_cat
	key_slot = p_key
	effects = p_effects
	tip = p_tip
	color = p_color

## 获取核心神力词条库（覆盖三大极境与跨流派质变联动）
static func get_all_boons() -> Array[BoonData]:
	var boons: Array[BoonData] = []

	# 1. 赫尔墨斯 · 残影瞬步流
	boons.append(BoonData.new(
		"dash_damage",
		"神行裂隙",
		"“神行飞鞋撕裂虚空，穿梭如刃”",
		"残影瞬步流",
		"[ A / Shift ] 瞬步",
		[
			{"tag": "裂隙斩击", "detail": "冲刺斩伤害大幅提升至 50 点（+66%）且硬直强化"},
			{"tag": "极速回充", "detail": "瞬步冷却缩短 40%（1.2s ➔ 0.72s）"}
		],
		"配合轻击打出极速冲刺斩，大幅强化输出与位移拉扯能力",
		Color(0.25, 0.85, 1.0) # 青蓝
	))

	boons.append(BoonData.new(
		"dash_phantom",
		"金羽残影",
		"“瞬身留影诱敌，幻化实体移形换位”",
		"残影瞬步流",
		"[ A / Shift ] 瞬步",
		[
			{"tag": "替身残影", "detail": "瞬步在原地留下一尊嘲讽石雕吸引仇恨"},
			{"tag": "吸收攻击", "detail": "诱导周围敌人攻击并替英雄承受一次伤害"}
		],
		"被怪群围困时起步脱身，诱导恶灵扑向残影自露破绽",
		Color(1.0, 0.75, 0.2) # 飞羽金
	))

	# 2. 雅典娜 · 绝命弹反流
	boons.append(BoonData.new(
		"parry_thunder",
		"雅典娜的雷暴",
		"“神盾引动天威，全屏神雷审判宵小”",
		"绝命弹反流",
		"[ B / 右键 ] 镜盾",
		[
			{"tag": "全屏神雷", "detail": "完美盾反任意近战或魔矢，降下天威神雷"},
			{"tag": "雷暴击晕", "detail": "对场上所有存活敌人造成 40 伤害并强击晕 0.8 秒"}
		],
		"面对满屏怪潮时，只需看准时机弹反一次即可全屏清场控场",
		Color(1.0, 0.88, 0.25) # 金雷黄
	))

	boons.append(BoonData.new(
		"deflect_homing",
		"波光追踪",
		"“青铜神镜聚光，反向洞穿魔眼死穴”",
		"绝命弹反流",
		"[ B / 右键 ] 镜盾",
		[
			{"tag": "神导反弹", "detail": "折射魔矢自动锁定最近敌人弱点自导攻击"},
			{"tag": "必爆重创", "detail": "反弹飞弹速度 1.8 倍，伤害 2.5 倍且必定暴击"}
		],
		"面对远程怪无需追逐，看准时机举盾反弹即可借力打力秒杀敌人",
		Color(0.55, 0.75, 1.0) # 神镜蓝
	))

	# 3. 弑神锻炉 · 破灭重斩流
	boons.append(BoonData.new(
		"titan_slash",
		"泰坦破军",
		"“承袭泰坦暴烈神力，一刀两断万物俱灭”",
		"破灭重斩流",
		"[ X / 左键长按 ] 破灭重斩",
		[
			{"tag": "瞬发充能", "detail": "破灭重斩蓄力时间减半（0.5s ➔ 0.25s 瞬满）"},
			{"tag": "毁灭增伤", "detail": "重斩伤害提升至 100 点（基础 70 ➔ 100）并强化击退"}
		],
		"无需漫长贪刀，短蓄力即可轰出毁灭重击直接击溃精英怪霸体",
		Color(1.0, 0.35, 0.25) # 炽红
	))

	# 4. 跨流派质变联动
	boons.append(BoonData.new(
		"parry_instant_heavy",
		"刚体反击",
		"“借盾之力化为暴刃，防守反击一气呵成”",
		"跨流派联动",
		"[ B ➔ X / 右键 ➔ 左键 ]",
		[
			{"tag": "免蓄瞬发", "detail": "完美盾反后刀刃燃起猩红血芒，重置 Shift 瞬步"},
			{"tag": "瞬轰重斩", "detail": "下一次攻击无需蓄力，直接轰出满段 70 伤破灭重斩"}
		],
		"右键格开敌人瞬间立刻接左键，零延迟将敌人一刀斩杀封喉",
		Color(1.0, 0.25, 0.45) # 猩红神威
	))

	return boons
