class_name SharpEditorPanel
extends Panel
@onready var compile_button = %CompileButton
@onready var code_edit = %CodeEdit
@onready var run_button = %RunButton
static var cached_remembers:Dictionary = {}
var caching_text:String = ""

@export var remember:bool:
	set(v):
		remembers = v
	get:
		return remembers
@export var remembers:bool = false:
	set(v):
		remembers = v
		if v:
			await get_tree().process_frame
			if cached_remembers.has(name):
				code_edit.text = cached_remembers[name]
			if not tree_exiting.is_connected(on_tree_exiting):
				tree_exiting.connect(on_tree_exiting)

	get:
		return remembers

func on_tree_exiting():
	if remembers:
		cached_remembers[name] = caching_text

@export var min_size_y:int:
	set(v):
		custom_minimum_size.y = v
	get:
		return roundi(custom_minimum_size.y) as int

@onready var margin_container = %MarginContainer

@export var shows_line_numbers:bool:
	set(v):
		(code_edit as CodeEdit).gutters_draw_line_numbers = v
		(code_edit as CodeEdit).gutters_draw_breakpoints_gutter = v
		(code_edit as CodeEdit).gutters_draw_fold_gutter = v
		(code_edit as CodeEdit).gutters_draw_executing_lines = v
		(code_edit as CodeEdit).minimap_draw = v
	get:
		return (code_edit as CodeEdit).gutters_draw_line_numbers
@export var shows_compile:bool:
	set(v):
		margin_container.visible = v
	get:
		return margin_container.visible
@export var min_size_x:int:
	set(v):
		custom_minimum_size.x = v
	get:
		return roundi(custom_minimum_size.x) as int
@export var code_font_size:int = -1:
	set(v):
		if code_edit:
			code_edit.font_size = v
	get:
		return code_edit.font_size if code_edit else -1
@export var expand_horizontal:bool = false:
	set(v):
		size_flags_horizontal = SIZE_EXPAND_FILL if v else SIZE_SHRINK_CENTER
		#print(size_flags_horizontal, "boops")
	get:
		return size_flags_horizontal == SIZE_EXPAND_FILL

@export var expand_vertical:bool = false:
	set(v):
		size_flags_vertical = SIZE_EXPAND_FILL if v else SIZE_SHRINK_CENTER
	get:
		return size_flags_vertical == SIZE_EXPAND_FILL


signal run_requested()

func _ready():
	compile_button.pressed.connect(code_edit.compile_pressed.emit)
	await get_tree().process_frame
	run_button.pressed.connect(run_requested.emit)

#func _exit_tree():
	##print(size_flags_horizontal)
	##print(size_flags_vertical)
func started_recompiled():
	modulate.a = 0.5
	compile_button.visible = false

func recompiled(has_public_method:bool = false):
	modulate.a = 1.0
	compile_button.visible = true
	#print(has_public_method)
	run_button.visible = has_public_method

var text:String:
	set(v):
		code_edit.text = v
		if code_edit.get_line_count() > 1 and code_edit.get_line(0).is_empty():
			var lines: PackedStringArray = text.split("\n")
			lines.remove_at(0)
			code_edit.text = "\n".join(lines)
	get():
		return code_edit.text if is_instance_valid(code_edit) else ""
