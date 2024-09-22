extends CodeEdit

func _ready():
	gui_input.connect(_on_gui_input)

func _on_gui_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B and event.ctrl_pressed:
			_surround_selection_with("**")
		if event.keycode == KEY_I and event.ctrl_pressed:
			_surround_selection_with("_")
		if event.keycode == KEY_N and event.ctrl_pressed:
			_surround_selection_with_specific("^^","^^")
		if event.keycode == KEY_W and event.ctrl_pressed:
			_surround_selection_with_specific("~^","^~")
		var shortcut: String = get_editor_shortcut(event)
		match shortcut:
			"toggle_comment":
				toggle_comment()
				get_viewport().set_input_as_handled()
			"delete_line":
				delete_current_line()
				get_viewport().set_input_as_handled()
			"move_up":
				move_line(-1)
				get_viewport().set_input_as_handled()
			"move_down":
				move_line(1)
				get_viewport().set_input_as_handled()
			"text_size_increase":
				self.font_size += 1
				get_viewport().set_input_as_handled()
			"text_size_decrease":
				self.font_size -= 1
				get_viewport().set_input_as_handled()
			"text_size_reset":
				self.font_size = 20
				get_viewport().set_input_as_handled()

	elif event is InputEventMouse:
		match event.as_text():
			"Ctrl+Mouse Wheel Up", "Command+Mouse Wheel Up":
				self.font_size += 1
				get_viewport().set_input_as_handled()
			"Ctrl+Mouse Wheel Down", "Command+Mouse Wheel Down":
				self.font_size -= 1
				get_viewport().set_input_as_handled()

func _surround_selection_with(surround_chars):
	var start = get_selection_from_line()
	var end = get_selection_to_line()
	var selected_text = get_selected_text()

	insert_text_at_caret(surround_chars + selected_text + surround_chars)
	select(start, get_selection_from_column(), end, get_selection_to_column() + 4)


func _surround_selection_with_specific(before, after):
	var start = get_selection_from_line()
	var end = get_selection_to_line()
	var selected_text = get_selected_text()

	insert_text_at_caret(before + selected_text + after)
	select(start, get_selection_from_column(), end, get_selection_to_column() + before.length() + after.length())


# Get the current caret as a Vector2
func get_cursor() -> Vector2i:
	return Vector2i(get_caret_column(), get_caret_line())


# Set the caret from a Vector2
func set_cursor(from_cursor: Vector2) -> void:
	set_caret_line(int(from_cursor.y) as int)
	set_caret_column(int(from_cursor.x) as int)

# Remove the current line
func delete_current_line() -> void:
	var cursor = get_cursor()
	var lines: PackedStringArray = text.split("\n")
	lines.remove_at(cursor.y)
	text = "\n".join(lines)
	set_cursor(cursor)
	text_changed.emit()

var cached_shortcuts:Dictionary = {}
## Get the shortcuts used by the plugin
func get_editor_shortcuts() -> Dictionary:
	if not cached_shortcuts.is_empty():
		return cached_shortcuts

	var shortcuts: Dictionary = {
		toggle_comment = [
			_create_event("Ctrl+K"),
			_create_event("Ctrl+Slash")
		],
		compile = [
			_create_event("Ctrl+S")
		],
		delete_line = [
			_create_event("Ctrl+Shift+K")
		],
		move_up = [
			_create_event("Alt+Up")
		],
		move_down = [
			_create_event("Alt+Down")
		],
		save = [
			_create_event("Ctrl+Alt+S")
		],
		close_file = [
			_create_event("Ctrl+W")
		],
		find_in_files = [
			_create_event("Ctrl+Shift+F")
		],

		run_test_scene = [
			_create_event("Ctrl+F5")
		],
		text_size_increase = [
			_create_event("Ctrl+Equal")
		],
		text_size_decrease = [
			_create_event("Ctrl+Minus")
		],
		text_size_reset = [
			_create_event("Ctrl+0")
		]
	}

	cached_shortcuts = shortcuts
	for key in cached_shortcuts.keys():
		if not InputMap.has_action(key):
			InputMap.add_action(key)
			for event in cached_shortcuts[key]:
				InputMap.action_add_event(key, event)
	return shortcuts

## Get the editor shortcut that matches an event
func get_editor_shortcut(event: InputEventKey) -> String:
	var shortcuts: Dictionary = get_editor_shortcuts()
	for key in shortcuts:
		for shortcut in shortcuts.get(key, []):
			if event.as_text().split(" ")[0] == shortcut.as_text().split(" ")[0]:
				return key
	return ""

func _create_event(string: String) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	var bits = string.split("+")
	event.keycode = OS.find_keycode_from_string(bits[bits.size() - 1])
	event.shift_pressed = bits.has("Shift")
	event.alt_pressed = bits.has("Alt")
	if bits.has("Ctrl") or bits.has("Command"):
		event.command_or_control_autoremap = true
	return event

# Move the selected lines up or down
func move_line(offset: int) -> void:
	offset = clamp(offset, -1, 1)

	var cursor = get_cursor()
	var reselect: bool = false
	var from: int = cursor.y
	var to: int = cursor.y
	if has_selection():
		reselect = true
		from = get_selection_from_line()
		to = get_selection_to_line()

	var lines := text.split("\n")

	# We can't move the lines out of bounds
	if from + offset < 0 or to + offset >= lines.size(): return

	var target_from_index = from - 1 if offset == -1 else to + 1
	var target_to_index = to if offset == -1 else from
	var line_to_move = lines[target_from_index]
	lines.remove_at(target_from_index)
	lines.insert(target_to_index, line_to_move)

	text = "\n".join(lines)

	cursor.y += offset
	from += offset
	to += offset
	if reselect:
		select(from, 0, to, get_line_width(to))
	set_cursor(cursor)
	text_changed.emit()

func toggle_comment() -> void:
	begin_complex_operation()

	var comment_delimiter: String = "//"
	var is_first_line: bool = true
	var will_comment: bool = true
	var selections: Array = []
	var line_offsets: Dictionary = {}

	for caret_index in range(0, get_caret_count()):
		var from_line: int = get_caret_line(caret_index)
		var from_column: int = get_caret_column(caret_index)
		var to_line: int = get_caret_line(caret_index)
		var to_column: int = get_caret_column(caret_index)

		if has_selection(caret_index):
			from_line = get_selection_from_line(caret_index)
			to_line = get_selection_to_line(caret_index)
			from_column = get_selection_from_column(caret_index)
			to_column = get_selection_to_column(caret_index)

		selections.append({
			from_line = from_line,
			from_column = from_column,
			to_line = to_line,
			to_column = to_column
		})

		for line_number in range(from_line, to_line + 1):
			if line_offsets.has(line_number): continue

			var line_text: String = get_line(line_number)

			# The first line determines if we are commenting or uncommentingg
			if is_first_line:
				is_first_line = false
				will_comment = not line_text.strip_edges().begins_with(comment_delimiter)

			# Only comment/uncomment if the current line needs to
			if will_comment:
				set_line(line_number, comment_delimiter + line_text)
				line_offsets[line_number] = 2
			elif line_text.begins_with(comment_delimiter):
				set_line(line_number, line_text.substr(comment_delimiter.length()))
				line_offsets[line_number] = -2
			else:
				line_offsets[line_number] = 0

	for caret_index in range(0, get_caret_count()):
		var selection: Dictionary = selections[caret_index]
		select(
			selection.from_line,
			selection.from_column + line_offsets[selection.from_line],
			selection.to_line,
			selection.to_column + line_offsets[selection.to_line],
			caret_index
		)
		set_caret_column(selection.from_column + line_offsets[selection.from_line], false, caret_index)

	end_complex_operation()

	text_set.emit()
	text_changed.emit()
