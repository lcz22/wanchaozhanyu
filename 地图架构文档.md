# 地图模块接入现有 UI 说明

本文档面向地图开发成员，说明如何将 2D 地图场景挂载到现有主界面 HUD。内容以当前工程代码为准，只定义场景挂载、输入传递和 UI 覆盖层边界，不定义城池、单位、战斗等业务接口。

## 1. 当前接入结论

- 地图组件场景：`res://ui/components/map_area.tscn`
- 地图内容挂载节点：`MapArea/MapViewportContainer/MapViewport`
- 地图屏幕空间 UI 挂载节点：`MapArea/MapUILayer`
- 地图输入预留脚本：`res://ui/components/map_input_anchor.gd`
- 主 HUD 创建位置：`res://ui/hud/main_hud.gd` 的 `_build_ui()`
- 当前没有地图业务方法、业务信号或正式地图场景路径。
- 地图资源缺失时必须保留占位界面，不能影响 HUD 启动。

地图团队交付一个可独立实例化的 `PackedScene` 后，UI 侧将该场景实例添加为 `MapViewport` 的子节点即可。

## 2. 现有节点结构

```text
MapArea (Control, mouse_filter = PASS)
├─ PlaceholderBackground (ColorRect, IGNORE)
├─ MapViewportContainer (SubViewportContainer, PASS, stretch = true)
│  └─ MapViewport (SubViewport)
├─ PlaceholderLabel (Label, IGNORE)
└─ MapUILayer (Control, IGNORE)
   └─ Hint (Label, IGNORE)
```

| 节点 | 当前职责 | 地图团队是否挂载内容 |
| --- | --- | --- |
| `MapViewport` | 渲染地图，并由容器向其转发输入 | 是，地图主场景挂在这里 |
| `MapViewportContainer` | 适配 HUD 中实际可用尺寸，承接触摸事件 | 不挂地图业务节点 |
| `MapUILayer` | 地图上方的屏幕空间按钮、提示等 UI | 仅挂屏幕空间 UI |
| `PlaceholderBackground` | 地图未接入或透明区域的底色 | 否 |
| `PlaceholderLabel`、`Hint` | 当前开发占位说明 | 地图成功加载后隐藏 |

`MapArea` 在 `main_hud.gd` 中通过代码动态实例化，因此不要依赖从 `/root` 开始的绝对节点路径。接入代码应先持有 `map_area` 实例，再使用组件内部的相对路径查找节点。

## 3. 地图场景交付约定

地图团队应交付：

1. 一个可独立实例化的主场景，例如 `res://map/main_map.tscn`；
2. 场景根节点建议使用 `Node2D`，地图所需的 `Camera2D`、TileMap、地形、单位等均由地图模块自行管理；
3. 地图相关资源统一放在地图模块目录内，不引用 HUD 页面内部节点；
4. 场景被添加到 `SubViewport` 后即可运行，不要求登录页、任务栏或其他业务页面先实例化；
5. 地图场景自行处理自己的释放，不保存 HUD 节点引用；
6. 不修改 `MapViewport` 的布局尺寸。当前 `MapViewportContainer.stretch = true`，运行时视口尺寸由容器实际尺寸控制；
7. 相机与地图布局应读取实际视口尺寸，不要按 `1920 × 1080` 或场景文件中的初始 `960 × 540` 写死地图可视范围。

当前阶段没有约定 `initialize()`、`select_city()`、`focus_unit()` 等方法，也没有约定城池选择、战斗开始等业务信号。需要这些接口时，应由 UI、地图和玩法成员共同确认数据结构后另行增加。

## 4. UI 侧最小挂载示例

以下代码是接入示例，不代表当前工程已经存在正式地图路径。建议由 UI 侧放入 `main_hud.gd`，保持地图缺失时仍可正常启动。

```gdscript
const MAP_SCENE_PATH := "res://map/main_map.tscn"

var _map_instance: Node


func _mount_map(map_area: Control) -> bool:
	var map_viewport := map_area.get_node_or_null(
		"MapViewportContainer/MapViewport"
	) as SubViewport
	if map_viewport == null:
		push_warning("地图挂载失败：MapViewport 节点不存在。")
		return false

	if not ResourceLoader.exists(MAP_SCENE_PATH):
		push_warning("地图场景尚未提供，继续显示地图占位区域。")
		return false

	var packed_map := load(MAP_SCENE_PATH) as PackedScene
	if packed_map == null:
		push_warning("地图挂载失败：地图场景无法读取。")
		return false

	_map_instance = packed_map.instantiate()
	map_viewport.add_child(_map_instance)
	_set_map_placeholder_visible(map_area, false)
	return true


func _set_map_placeholder_visible(map_area: Control, is_visible: bool) -> void:
	var placeholder_label := map_area.get_node_or_null("PlaceholderLabel") as CanvasItem
	var hint := map_area.get_node_or_null("MapUILayer/Hint") as CanvasItem
	if placeholder_label != null:
		placeholder_label.visible = is_visible
	if hint != null:
		hint.visible = is_visible
```

在现有 `_build_ui()` 中，调用位置应紧跟在地图组件加入 `map_frame` 之后：

```gdscript
var map_area := MAP_AREA_SCENE.instantiate() as Control
map_frame.add_child(map_area)
_mount_map(map_area)
```

挂载失败时不要删除占位节点，也不要抛出导致主界面中断的错误。`MainHUD` 离开场景树后，其下的 `MapViewport` 和地图实例会随页面一起释放。

## 5. 触摸与手势接口

### 5.1 当前行为

- `MapViewportContainer` 使用 `map_input_anchor.gd`。
- `_gui_input(event)` 当前为空，不消费事件，也不产生业务信号。
- `SubViewportContainer` 默认会把输入事件继续传给其子 `SubViewport`。
- `MapUILayer`、占位背景和占位文字当前均为 `MOUSE_FILTER_IGNORE`，不会因透明全屏控件阻断地图输入。

因此，地图场景可以在自己的节点中处理转发到 `MapViewport` 的输入事件。移动端优先处理：

- `InputEventScreenTouch`：按下、抬起与触点索引；
- `InputEventScreenDrag`：单指拖拽和多触点移动；
- 其他手势：由地图模块按需要扩展；
- 鼠标事件：只作为桌面调试补充，不应成为唯一交互方式。

地图模块只应在确实识别并处理了地图操作后标记事件已处理。未识别的事件应继续传播，避免影响 HUD 或后续覆盖层控件。

### 5.2 UI 覆盖层规则

- 屏幕空间地图按钮、缩放按钮、地图提示等放在 `MapUILayer` 下；
- `MapUILayer` 根节点继续保持 `MOUSE_FILTER_IGNORE`；
- 真正可交互的 `Button`、`Control` 等子节点使用 `MOUSE_FILTER_STOP`，只拦截自身矩形范围内的触摸；
- 地图世界内的标记、城池和单位应留在 `MapViewport` 内，由地图相机统一变换；
- 不要添加透明的全屏 `Control` 并设置为 `STOP`。

### 5.3 坐标约定

- 地图输入逻辑使用 `SubViewport` 收到的事件坐标，不要再次按设计分辨率手动缩放；
- 屏幕坐标转地图世界坐标时，应通过地图自己的 `Camera2D` 或视口 Canvas Transform 转换；
- HUD 安全区域、任务栏和右侧入口会改变地图容器的实际大小，地图不得假设自己始终占满整个屏幕；
- 如果未来需要把地图世界坐标投影到 `MapUILayer`，应新增单独的坐标转换接口，不要直接读取 HUD 深层节点。

## 6. 当前视口配置

| 属性 | 当前值 | 说明 |
| --- | --- | --- |
| `MapViewportContainer.stretch` | `true` | 视口随 HUD 中地图区域自动调整 |
| `MapViewport.transparent_bg` | `true` | 地图透明区域可显示下方占位底色 |
| `MapViewport.handle_input_locally` | `false` | 与嵌入式 `SubViewportContainer` 的输入处理方式一致 |
| `MapViewport.render_target_update_mode` | `UPDATE_ALWAYS` | HUD 存在时持续更新地图画面 |
| 场景文件初始 `size` | `960 × 540` | 仅为初始资源值；运行时由启用 stretch 的容器控制 |

地图团队不应自行缩放 `MapViewportContainer`。如需降低渲染分辨率或改变更新策略，应先与 UI 成员确认，并在目标设备上验证画质、触摸坐标和性能。

## 7. 模块职责边界

地图模块负责：

- 地图内容、相机、地图内实体和地图手势；
- 地图世界坐标转换；
- 地图自身资源的加载与释放；
- 地图模块内部错误处理。

UI 模块负责：

- `MapArea` 在 HUD 中的尺寸和位置；
- 地图场景的安全加载、挂载失败回退和占位层显隐；
- `MapUILayer` 下的屏幕空间控件；
- 登录、导航、弹窗、资源栏和任务栏。

当前双方都不应在地图接入层实现正式战斗、经济、服务器或任务结算逻辑。

## 8. 联调验收清单

- [ ] 未提供地图场景时，主界面仍可进入并显示“地图区域”占位内容。
- [ ] 地图场景存在时，能够作为 `MapViewport` 子节点显示。
- [ ] 地图加载成功后，`PlaceholderLabel` 与 `MapUILayer/Hint` 已隐藏。
- [ ] 地图场景切出主 HUD 后能够正常释放，无残留引用和重复信号。
- [ ] 单指触摸与拖拽事件能到达地图模块。
- [ ] 双指事件能区分触点索引，且不会触发透明 UI 层误拦截。
- [ ] `MapUILayer` 中真实按钮能拦截自身区域，按钮外仍可操作地图。
- [ ] 在 16:9、较宽横屏和带安全区域设备下，地图不依赖固定全屏尺寸。
- [ ] 删除或改名地图场景后，HUD 只回退到占位状态，不崩溃。
- [ ] 控制台不存在地图接入导致的未处理错误。

## 9. 相关代码与官方说明

- `res://ui/components/map_area.tscn`
- `res://ui/components/map_input_anchor.gd`
- `res://ui/hud/main_hud.gd`
- [Godot SubViewportContainer 官方文档](https://docs.godotengine.org/en/latest/classes/class_subviewportcontainer.html)
- [Godot SubViewport 官方文档](https://docs.godotengine.org/en/stable/classes/class_subviewport.html)
- [Godot 输入事件传播说明](https://docs.godotengine.org/en/latest/tutorials/inputs/inputevent.html)
