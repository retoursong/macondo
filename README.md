# Godot Lab

Godot **4.7.2** 基础工程。题材未定——这里只有跟题材无关的地基，游戏本体从
`scenes/sandbox.tscn` 开始长。

## 快速开始

```bash
make editor    # 打开 Godot 编辑器
make run       # 直接跑游戏
make test      # 自检 + 冒烟，改完基建先跑这个
```

跑起来后：`WASD` 移动方块，`空格` 加分，`Esc` 暂停，`F3` 调试浮层。

## 目录

```
autoload/     全局单例（下面详解）
scenes/       游戏场景，.gd 和 .tscn 同名成对
ui/           可复用的界面组件（暂空）
assets/       美术/音频/字体
tools/        开发脚本，不进游戏
tests/        （暂空，见「故意没做的」）
```

## 七个 autoload，一句话一个

它们在 `project.godot` 的 `[autoload]` 段注册，**顺序有意义**（后面的可以用前面的）。
在任何脚本里直接写名字就能用，不需要 `get_node`。

| 名字 | 干什么 | 典型用法 |
|---|---|---|
| `EventBus` | 全局信号总线，让互不认识的模块通信 | `EventBus.score_changed.emit(10)` |
| `GameState` | 「这一局」的运行时数据 | `GameState.score += 1` |
| `SaveSystem` | 存档 + 设置，JSON 落在 `user://` | `SaveSystem.data["best_score"]` |
| `AudioMan` | 音量总线 + 音效池 + BGM 交叉淡化 | `AudioMan.play_sfx(stream)` |
| `SceneRouter` | 带淡入淡出的场景切换 | `SceneRouter.change_to(SceneRouter.SANDBOX)` |
| `PauseMenu` | 全局 Esc 暂停菜单 | `PauseMenu.enabled = false` |
| `DebugOverlay` | F3 调试浮层 | `DebugOverlay.watch("敌人数", n)` |

### 为什么要有 EventBus

不然你会写出 `get_node("../../UI/HUD/ScoreLabel")` 这种代码，节点一挪就全断。
有了总线：分数变了就 `emit`，谁关心谁 `connect`，两边互不认识。

```gdscript
# 发的一方
GameState.score += 1              # setter 里自动 emit score_changed

# 收的一方
func _ready() -> void:
    EventBus.score_changed.connect(_on_score_changed)
```

### 数据往哪放

- 只在这一局有效（血量、分数、当前波次）→ `GameState`
- 关掉游戏还要留着（最高分、解锁、设置）→ `SaveSystem`

## 输入映射

在 `项目设置 → 输入映射` 里可以改。用的是 **physical_keycode**，
所以非 QWERTY 布局（比如法语 AZERTY）玩家的 WASD 还在原来的物理位置。

| Action | 键盘 | 鼠标 | 手柄 |
|---|---|---|---|
| `move_left/right/up/down` | WASD / 方向键 | — | 左摇杆 |
| `action_primary` | 空格 | 左键 | A |
| `action_secondary` | J | 右键 | X |
| `pause` | Esc | — | Start |
| `restart` | R | — | Back |
| `debug_toggle` | F3 | — | — |

读输入优先用 `Input.get_vector("move_left","move_right","move_up","move_down")`，
它自带死区和归一化，比自己写四个 `if` 稳。

## 两个质量闸

```bash
make check   # 结构：7 个 autoload 在不在、输入 action 真能被按键触发、
             # 场景挂没挂上脚本、音频总线在不在、存档能不能读回
make smoke   # 运行：每个入口场景真跑 240 帧，任何 ERROR 就失败
```

两个都返回标准退出码，可以直接接 CI。
**加了新场景记得往 `tools/smoke.sh` 的 `SCENES` 里加一行**，否则它跑不到。

## 场景是生成出来的

`scenes/*.tscn` 由 `make scaffold` 用引擎自己的序列化器生成，不是手写的。

原因：`.tscn` 格式随版本变（4.7 给每个节点加了 `unique_id` 字段），手写迟早对不上。

⚠️ **生成之后就当普通场景文件用，正常在编辑器里改。**
`make scaffold` 会覆盖你的手动改动，除非你确实想重置，否则别跑。

（`tools/` 里那套两段式引导看着绕，原因是：`godot --script foo.gd` 不会加载
autoload，所以引用了 `EventBus` 的脚本在那个模式下编译不过。必须先造一个
不引用 autoload 的壳场景，再以「运行场景」的方式跑它。）

## 中文字体（重要，别删）

**Godot 内置字体一个汉字都没有**（只有拉丁/希腊/西里尔）。不挂中文字体的话，
所有中文 UI 会渲染成豆腐块 `□□□`——而且在编辑器里预览也一样，很容易以为是自己写错了。

所以工程里带了 `assets/fonts/NotoSansSC-VF.ttf`（Noto Sans SC 可变字体，OFL 协议，
可自由商用），并在 `项目设置 → GUI → 主题 → Custom Font` 设为项目默认字体。
`make check` 里有一条专门盯着这件事，字体被换掉或删掉会直接报错。

⚠️ 这个字体 **17 MB**，是仓库里最大的文件。两个选项：
- 嫌大：用 `pyftsubset` 裁成常用字集（GB2312 约 6763 字）能降到 3~5 MB，
  代价是以后写到生僻字会缺字。
- 想换字体：换完记得跑 `make font` 重新设置，再 `make check` 确认没变豆腐。

## 常见改法

**加一个新场景**
1. 写 `scenes/foo.gd`
2. 编辑器里建 `scenes/foo.tscn`，挂上脚本
3. 往 `SceneRouter` 里加一个 `const FOO := "res://scenes/foo.tscn"`
4. 往 `tools/smoke.sh` 的 `SCENES` 里加一行

**加一个全局事件**
1. `autoload/event_bus.gd` 里加 `signal enemy_killed(enemy: Node)`
2. 发：`EventBus.enemy_killed.emit(self)`
3. 收：`EventBus.enemy_killed.connect(_on_enemy_killed)`

**加音效**
1. 文件丢进 `assets/audio/`
2. `AudioMan.play_sfx(preload("res://assets/audio/hit.wav"), 0.0, 0.1)`
   （第三个参数是随机音高，连续触发时不会像机关枪）

## 故意没做的，以及为什么

| 没做 | 为什么 |
|---|---|
| 单元测试框架（GUT / gdUnit4） | 第三方插件跟 4.7 的兼容性没验证过，先用零依赖的 `make check` 顶着。真要写逻辑测试时再装。 |
| 玩家/敌人/血量/关卡 | 这些全是题材相关的。做俯视角割草和做卡牌构筑，这层完全不一样，现在写等于白写。 |
| 美术资源 | 硬瓶颈，得靠买素材包或找人。现在全是色块占位。 |
| 导出配置（打包成 exe/app/网页） | 要先装对应平台的 export template。等有东西可发再配。 |
| 存档加密/防篡改 | 单机游戏，玩家改自己存档是他的自由。真要做联网排行榜再说。 |

## 两个可能要改的默认值

- **渲染后端** 现在是 `forward_plus`（Godot 默认，3D 能力最全）。
  如果确定只做 2D 并且想导出到**网页**，改成 `gl_compatibility` 兼容性最好。
  在 `项目设置 → 渲染 → 渲染方法` 改。
- **窗口** 1280×720，拉伸模式 `canvas_items` + `expand`。
  做像素风的话应该换成 `viewport` 模式 + 整数缩放，那时候再说。
