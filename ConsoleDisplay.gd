extends CodeEdit
class_name ConsoleDisplay

@export var console_width: int = 30
@export var console_height: int = 22

var cursor_x: int = 0
var cursor_y: int = 0
var waiting_for_key: bool = false

@export var remove_on_compile:bool = false
var constructing_script:String = ""
func _ready():
	editable = false
	selecting_enabled = false
	add_theme_constant_override("line_spacing", 0)
	add_theme_font_override("font", load("res://monovariation.tres"))
	add_theme_color_override("font_color",Color("c3c3c3"))
	add_theme_color_override("font_readonly_color",Color("c3c3c3"))
	autowrap_mode = TextServer.AutowrapMode.AUTOWRAP_OFF
	clear_console()
	for i in 3:
		custom_minimum_size = Vector2(console_width * 10, console_height * 20)  # Approximate size, adjust if needed
		size = custom_minimum_size
		if get_h_scroll_bar() != null:
			get_h_scroll_bar().visible = false
			get_h_scroll_bar().self_modulate.a = 0.0
		if get_v_scroll_bar() != null:
			get_v_scroll_bar().visible = false
			get_v_scroll_bar().self_modulate.a = 0.0
		await get_tree().process_frame

func set_cursor_position(x: int, y: int):
	cursor_x = clamp(x, 0, console_width - 1)
	cursor_y = clamp(y, 0, console_height - 1)

# Get the current caret as a Vector2
func get_cursor() -> Vector2i:
	return Vector2i(get_caret_column(), get_caret_line())

# Set the caret from a Vector2
func set_cursor(from_cursor: Vector2) -> void:
	set_caret_line(int(from_cursor.y) as int)
	set_caret_column(int(from_cursor.x) as int)

func write_at_pos(content: String, pos_x:int, pos_y:int):
	set_cursor_position(pos_x,pos_y)
	write(content)

func create_child_script(child_script:String):
	await get_tree().process_frame
	var code_without_empty_enters = child_script.split("\n",false)
	var empty_char:= ' '
	for i in code_without_empty_enters.size():
		if (code_without_empty_enters[i] as String).length() > 1 and code_without_empty_enters[i][0] == empty_char:
			if code_without_empty_enters[i].strip_edges().is_empty():
				code_without_empty_enters[i] = ""
			else:
				code_without_empty_enters[i] = code_without_empty_enters[i].strip_edges()

	child_script = "\n".join(code_without_empty_enters)

	var newgdscript = GDScript.new()
	newgdscript.source_code = child_script
	var file = FileAccess.open("res://new_test_read.txt",FileAccess.WRITE)
	file.store_string(newgdscript.source_code)
	var error_found = newgdscript.reload(false)
	if error_found != OK:
		print(error_found)
		return
	await get_tree().process_frame
	if is_instance_valid(newgdscript):
		var script_instance = newgdscript.new()
		if remove_on_compile:
			get_parent().add_child(script_instance)
			queue_free()
		else:
			add_child(script_instance)

func write(content: String):
	for _char in content:
		if _char == '\n':
			cursor_y += 1
			cursor_x = 0
		else:
			if cursor_x >= console_width:
				cursor_y += 1
				cursor_x = 0

			if cursor_y >= console_height:
				cursor_y = console_height - 1
			#if _char != ' ':
				#print("line before          [%s]" % get_line(cursor_y))
			remove_text(cursor_y,cursor_x, cursor_y,cursor_x+1)
#
			#if _char != ' ':
				#print("line after removal   [%s]" % get_line(cursor_y))
			insert_text(_char, cursor_y, cursor_x, false, false)
#
			#if _char != ' ':
				#print("line after insertion [%s]" % get_line(cursor_y))
			cursor_x += 1

func clear_console():
	text = " ".repeat(console_width) + "\n"
	text = text.repeat(console_height)
	cursor_x = 0
	cursor_y = 0

func write_line(content: String):
	write(content)

func read_key():
	waiting_for_key = true
	var keyreturn = await self.key_pressed
	waiting_for_key = false
	return keyreturn

func _input(event):
	if SlideManager.editor_focused:
		return
	if event is InputEventKey and event.pressed:
		if waiting_for_key:
			emit_signal("key_pressed", event.keycode)
			get_viewport().set_input_as_handled()
		else:
			# Handle regular input here
			pass

signal key_pressed(key)
