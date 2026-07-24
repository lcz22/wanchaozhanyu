extends Control

const RESOURCE_BAR_SCENE := preload("res://ui/components/resource_bar.tscn")
const TASK_PANEL_SCENE := preload("res://ui/components/task_panel.tscn")
const MAP_AREA_SCENE := preload("res://ui/components/map_area.tscn")

var _resource_bar: ResourceBar
var _task_panel: TaskPanel
var _status_panel: PanelContainer
var _status_grid: GridContainer


func _ready() -> void:
	_build_ui()
	_connect_mock_signals()
	_refresh_all()


func _exit_tree() -> void:
	if MockData.resources_changed.is_connected(_on_resources_changed):
		MockData.resources_changed.disconnect(_on_resources_changed)
	if MockData.tasks_changed.is_connected(_on_tasks_changed):
		MockData.tasks_changed.disconnect(_on_tasks_changed)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("0e0d0c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var safe := SafeAreaContainer.new()
	safe.minimum_safe_padding = 18
	add_child(safe)
	var root_box := VBoxContainer.new()
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(root_box, 12)
	safe.add_child(root_box)

	_resource_bar = RESOURCE_BAR_SCENE.instantiate() as ResourceBar
	_resource_bar.more_status_requested.connect(_toggle_status_panel)
	_resource_bar.demo_update_requested.connect(MockData.apply_demo_resource_update)
	root_box.add_child(_resource_bar)

	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIBuilder.set_box_spacing(workspace, 12)
	root_box.add_child(workspace)

	_task_panel = TASK_PANEL_SCENE.instantiate() as TaskPanel
	_task_panel.task_details_requested.connect(_show_task_details)
	_task_panel.tracking_toggled.connect(MockData.toggle_task_tracking)
	_task_panel.demo_advance_requested.connect(MockData.advance_demo_task)
	workspace.add_child(_task_panel)

	var map_frame := PanelContainer.new()
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(map_frame)
	var map_area := MAP_AREA_SCENE.instantiate()
	map_frame.add_child(map_area)

	var secondary := VBoxContainer.new()
	secondary.custom_minimum_size.x = 180
	UIBuilder.set_box_spacing(secondary, 8)
	workspace.add_child(secondary)
	secondary.add_child(UIBuilder.make_label("全局事务", 19, UIBuilder.COLOR_ACCENT))
	_add_route_button(secondary, "全服事件", "world_event")
	_add_route_button(secondary, "赛季结算", "season")
	_add_route_button(secondary, "NPC 对话", "npc")
	_add_route_button(secondary, "流亡", "exile")
	_add_route_button(secondary, "复兴", "revival")
	_add_route_button(secondary, "反攻", "counterattack")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	secondary.add_child(spacer)
	_add_route_button(secondary, "UI 演示", "ui_demo")
	_add_route_button(secondary, "设置", "settings")

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	UIBuilder.set_box_spacing(nav, 12)
	root_box.add_child(nav)
	_add_route_button(nav, "城池经营", "city", true)
	_add_route_button(nav, "武将", "generals", true)
	_add_route_button(nav, "联盟", "alliance", true)
	_add_route_button(nav, "战前路线", "route", true)
	_add_route_button(nav, "战斗指令", "battle", true)

	_build_status_panel()


func _add_route_button(parent: BoxContainer, label: String, route: String, expand: bool = false) -> void:
	var button := UIBuilder.make_button(label, 0)
	button.custom_minimum_size.y = 52
	if expand:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: NavigationManager.open_screen(route))
	parent.add_child(button)


func _build_status_panel() -> void:
	_status_panel = UIBuilder.make_panel()
	_status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_panel.position = Vector2(-470, 110)
	_status_panel.size = Vector2(440, 390)
	_status_panel.visible = false
	add_child(_status_panel)
	var content := VBoxContainer.new()
	UIBuilder.set_box_spacing(content, 12)
	_status_panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UIBuilder.make_label("更多状态", 24, UIBuilder.COLOR_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UIBuilder.make_button("关闭", 96)
	close.custom_minimum_size.y = 46
	close.pressed.connect(_toggle_status_panel)
	header.add_child(close)
	_status_grid = GridContainer.new()
	_status_grid.columns = 2
	_status_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_grid.add_theme_constant_override("h_separation", 26)
	_status_grid.add_theme_constant_override("v_separation", 14)
	content.add_child(_status_grid)


func _toggle_status_panel() -> void:
	_status_panel.visible = not _status_panel.visible
	if _status_panel.visible:
		_refresh_status_panel()


func _refresh_all() -> void:
	_resource_bar.set_resources(MockData.get_resources())
	_task_panel.set_tasks(MockData.get_tasks())
	_refresh_status_panel()


func _refresh_status_panel() -> void:
	for child in _status_grid.get_children():
		child.queue_free()
	var statuses: Dictionary = MockData.get_statuses()
	for status_name in statuses:
		var value: String = str(statuses[status_name])
		_status_grid.add_child(UIBuilder.make_label(str(status_name), 17, UIBuilder.COLOR_MUTED))
		var value_label := UIBuilder.make_label(value, 18, UIBuilder.COLOR_TEXT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_status_grid.add_child(value_label)


func _connect_mock_signals() -> void:
	if not MockData.resources_changed.is_connected(_on_resources_changed):
		MockData.resources_changed.connect(_on_resources_changed)
	if not MockData.tasks_changed.is_connected(_on_tasks_changed):
		MockData.tasks_changed.connect(_on_tasks_changed)


func _on_resources_changed(resources: Dictionary, changes: Dictionary) -> void:
	_resource_bar.set_resources(resources, changes)
	_refresh_status_panel()


func _on_tasks_changed(tasks: Array[Dictionary]) -> void:
	_task_panel.set_tasks(tasks)


func _show_task_details(task: Dictionary) -> void:
	var tracked_text := "已追踪" if bool(task.get("tracked", false)) else "未追踪"
	NavigationManager.show_message(
		str(task.get("title", "任务详情")),
		"%s\n\n进度：%d / %d\n状态：%s · %s" % [
			task.get("description", "暂无描述"),
			int(task.get("current", 0)),
			int(task.get("target", 0)),
			task.get("status", "进行中"),
			tracked_text,
		]
	)
