class_name TurnUIControl extends Panel

@onready var player_panel: Panel = $PlayerPanel
@onready var move_panel: Panel = $MovePanel
@onready var turn_panel: Panel = $TurnPanel

@onready var player_label: Label = $PlayerPanel/PlayerLabel
@onready var turn_label: Label = $TurnPanel/TurnLabel

var player_panel_og_pos: Vector2
var move_panel_og_pos: Vector2
var turn_panel_og_pos: Vector2
var tween_in_duration = 0.5
var tween_hold_duration = 1.5
var tween_out_duration = 0.75

var tween_pos_offset_horizontal = Vector2(ProjectSettings.get("display/window/size/viewport_width"), 0)
var tween_pos_offset_vertical = Vector2(0, ProjectSettings.get("display/window/size/viewport_height"))

func _ready():
	player_panel_og_pos = player_panel.position
	move_panel_og_pos = move_panel.position
	turn_panel_og_pos = turn_panel.position
	player_panel.position -= tween_pos_offset_horizontal
	move_panel.position += tween_pos_offset_horizontal
	turn_panel.position -= tween_pos_offset_vertical
	EventBus.turn_ui_freed.connect(__turn_ui_freed_handler)
	EventBus.turn_displayed.connect(__turn_displayed_handler)


func __turn_ui_freed_handler():
	queue_free()


func __turn_displayed_handler(player_name: String, is_me: bool, turn: int):
	if is_me:
		player_name = "YOUR "
	else:
		player_name = player_name + "'s "
	player_label.text = player_name
	turn_label.text = "Turn %d" % turn
	var tween_in = create_tween()
	tween_in.tween_property(player_panel, "position", player_panel_og_pos, tween_in_duration)
	tween_in.parallel()
	tween_in.tween_property(move_panel, "position", move_panel_og_pos, tween_in_duration)
	tween_in.parallel()
	tween_in.tween_property(turn_panel, "position", turn_panel_og_pos, tween_in_duration)
	tween_in.finished.connect(__tween_hold)


func __tween_hold():
	var tween_hold = create_tween()
	tween_hold.tween_interval(tween_hold_duration)
	tween_hold.finished.connect(__tween_out)


func __tween_out():
	var tween_out = create_tween()
	tween_out.tween_property(player_panel, "position", player_panel_og_pos - tween_pos_offset_horizontal, tween_out_duration)
	tween_out.parallel()
	tween_out.tween_property(move_panel, "position", move_panel_og_pos + tween_pos_offset_horizontal, tween_out_duration)
	tween_out.parallel()
	tween_out.tween_property(turn_panel, "position", turn_panel_og_pos - tween_pos_offset_vertical, tween_out_duration)
