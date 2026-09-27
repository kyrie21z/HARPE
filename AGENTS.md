# AGENTS.md — AI 协作与开发准则

本文件为任何接入此代码库的 AI 编码助手（包括但不限于 Cursor, Claude, Antigravity, GitHub Copilot 等）提供核心技术上下文与开发规范。
所有 AI 在阅读本仓库或修改代码前，**必须严格遵守以下约定**。

---

## 1. 项目概况与架构定位
- **项目名称**：`HARPE`
- **引擎版本**：Godot 4.3+ (推荐 4.7 Standard，严禁使用 Mono/.NET C# 版本)
- **脚本语言**：**GDScript 2.0**
- **游戏类型**：俯视角 2D 动作肉鸽（Top-Down Action Roguelite）
- **核心输入映射（见 project.godot）**：
  - `move_up` (W), `move_down` (S), `move_left` (A), `move_right` (D)
  - `dash` (Shift): 极速瞬步（充能限制）
  - `attack` (鼠标左键): 点按轻击，长按蓄力重斩
  - `parry` (鼠标右键): 弹反格挡

---

## 2. 目录规范与文件组织
所有资源与代码必须严格归类，禁止在根目录散落文件：
- `res://scenes/`：所有 `.tscn` 场景文件（如 `Main.tscn`, `Player.tscn`）
- `res://scripts/`：所有 `.gd` 脚本文件（纯数据类、管理器、逻辑控制器）
- `res://assets/`：静态美术贴图、音频、字体等资产
- `res://docs/`：设计文档与技术方案（如 `GDD.md`）

---

## 3. GDScript 编码规范
1. **静态类型标注（Strict Static Typing）**：
   所有变量、函数参数和返回值必须尽量显式标注类型：
   ```gdscript
   var current_health: float = 100.0
   func take_damage(amount: float) -> void:
       current_health -= amount
   ```
2. **命名约定**：
   - 节点与类名：帕斯卡命名法（`PascalCase`），如 `PlayerCharacter`, `HitBox2D`
   - 脚本文件名：帕斯卡或下划线（推荐小写下划线 `player_controller.gd`）
   - 变量与函数：蛇形命名法（`snake_case`），如 `is_charging`, `perform_parry()`
   - 常量与枚举：全大写下划线（`SCREAMING_SNAKE_CASE`），如 `MAX_DASH_COUNT`
   - 私有变量/内部方法：前缀下划线，如 `_update_charge_state()`
3. **节点引用机制**：
   优先使用 `@onready` 与显式类型注解：
   ```gdscript
   @onready var sprite: Sprite2D = $Sprite2D
   @onready var collision_shape: CollisionShape2D = $CollisionShape2D
   ```
4. **信号优先原则（Signal Up, Call Down）**：
   父节点调用子节点的方法，子节点通过信号（`signal`）向父节点报告状态变更，保持组件解耦。

---

## 4. 核心战斗逻辑约定
- **弹反窗口（Parry Window）**：判定时间保持在极短的 0.1~0.15 秒窗口，判定精准、不拖泥带水；
- **打击感三要素**：任何受击/招架必须配套：
  1. 顿帧（`Engine.time_scale` 临时归零 0.05~0.1 秒）；
  2. 屏幕震动（Camera Shake）；
  3. 火花粒子与音效。
- **瞬步（Dash）**：严格保持充能点数限制，不可无限连按；弹反成功有能力重置瞬步。

---

## 5. 多设备开发边界提醒
- **不要提交本地专用绝对路径**（如 `C:\Godot\...` 等写在仓库配置文件中）；
- 本地生成的 `.mcp.json` 或 `.cursor/mcp.json` 已在 `.gitignore` 保护，统一在各自设备按需要配置。
