extends CodeEdit

const REDIRECT_COMPONENT_PROPERTIES = {
	"LeftText" : "Text",
	"RightText" : "Text",
	"BottomText": "Text",
	"TopText": "Text",
	"SetMargins" : "SetMargin",
	"Margin" : "SetMargin",
	"Margins" : "SetMargin",
	"RightImage" : "Image",
	"BottomImage" : "Image",
	"TopImage" : "Image",
	"LeftImage" : "Image",
	"TextureRect" : "Image"
}
static var COMPONENT_PROPERTIES = {
	"SetMargin" : {
		"margin_left": "int",
		"margin_top": "int",
		"margin_right": "int",
		"margin_bottom": "int"
	},
	"Text": {
		"font_size": "int",
		"text": "string",
		"custom_minimum_size": "Vector2",
		"size_flags_horizontal": "int",
		"size_flags_vertical": "int",
		"bbcode_enabled": "bool",
		"fit_content": "bool",
		"anchors_preset": "int",
		"anchor_left": "float",
		"anchor_top": "float",
		"anchor_right": "float",
		"anchor_bottom": "float",
		"expand_horizontal": "bool",
		"expand_vertical": "bool",
	},
	"Code": {
		"font_size": "int",
		"code_font_size": "int",
		"custom_minimum_size": "Vector2",
		"min_size_y": "int",
		"size_flags_horizontal": "int",
		"size_flags_vertical": "int",
		"shows_line_numbers": "bool",
		"shows_compile": "bool",
		"anchor_left": "float",
		"anchor_top": "float",
		"anchor_right": "float",
		"anchor_bottom": "float",
		"expand_horizontal": "bool",
		"expand_vertical": "bool",
	},
	"HBox": {
		"custom_minimum_size": "Vector2",
		"size_flags_horizontal": "int",
		"size_flags_vertical": "int",
		"theme_override_constants/separation": "int",
		"anchors_preset": "int",
		"anchor_left": "float",
		"anchor_top": "float",
		"anchor_right": "float",
		"anchor_bottom": "float",
		"expand_horizontal": "bool",
		"expand_vertical": "bool",
		"alignment" : "int"
	},
	"VBox": {
		"custom_minimum_size": "Vector2",
		"size_flags_horizontal": "int",
		"size_flags_vertical": "int",
		"theme_override_constants/separation": "int",
		"anchors_preset": "int",
		"anchor_left": "float",
		"anchor_top": "float",
		"anchor_right": "float",
		"anchor_bottom": "float",
		"expand_horizontal": "bool",
		"expand_vertical": "bool",
		"alignment" : "int"
	},
	"Console": {
		"custom_minimum_size": "Vector2",
		"size_flags_horizontal": "int",
		"size_flags_vertical": "int"
	},
	"QRCode": {
		"custom_minimum_size": "Vector2",
		"data": "string",
		"size_flags_horizontal": "int",
		"size_flags_vertical": "int"
	},
	"Image": {
		"custom_minimum_size": "Vector2",
		"data": "string",
		"expand_mode": "int",
		"stretch_mode": "int",
		"size_flags_horizontal": "int",
		"size_flags_vertical": "int",
		"anchor_left": "float",
		"anchor_top": "float",
		"anchor_right": "float",
		"anchor_bottom": "float",
		"expand_horizontal": "bool",
		"expand_vertical": "bool"
	}
}

const COMPONENT_NAMES = [
	"Text",
	"Code",
	"HBox",
	"VBox",
	"Console",
	"QRCode",
	"TextureRect",
	"LeftText",
	"RightText",
	"TopText",
	"BottomText",
	"LeftImage",
	"RightImage",
	"SetBackgroundImage",
	"SetMargin",
	"Image",
	"Scale"
]

var emoji_data: Array = []
var last_pasted_image_path: String = ""

func _get_emoji_matches(search_term: String) -> Array:
	var matches = []
	search_term = search_term.to_lower()

	for emoji_info in emoji_data:
		# Search in description
		if emoji_info.description.to_lower().contains(search_term):
			matches.append(emoji_info)
			continue

		# Search in aliases
		for alias in emoji_info.aliases:
			if alias.to_lower().contains(search_term):
				matches.append(emoji_info)
				continue

		# Search in tags
		for tag in emoji_info.tags:
			if tag.to_lower().contains(search_term):
				matches.append(emoji_info)
				break

	return matches

func _ready():
	gui_input.connect(_on_gui_input)
	text_changed.connect(_on_text_changed)

	# Load emoji data from JSON file
	var file = FileAccess.open("res://data/emoji.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			emoji_data = json.get_data()
		file.close()

	# Enable code completion
	code_completion_enabled = true
	code_completion_prefixes = ["=>", "[", ",", ":emj"]

func _on_text_changed():
	request_code_completion(true)

func _on_gui_input(event):
	if event is InputEventKey and event.pressed:
		# Handle paste event (Ctrl+V or Command+V)
		if event.keycode == KEY_V and event.ctrl_pressed and DisplayServer.clipboard_has_image():
			var image = DisplayServer.clipboard_get_image()
			if image:
				var path = _save_clipboard_image(image)
				if path != "":
					# Insert the BBCode for the image at the current cursor position
					var bbcode = "[img]%s[/img]" % path
					insert_text_at_caret(bbcode)
					get_viewport().set_input_as_handled()
					return

		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			var line = get_line(get_caret_line())
			if line.to_lower().begins_with("=> text"):
				var regex = RegEx.new()
				regex.compile("^=>\\s*Text\\s+(\\d+)\\s*$")
				var result = regex.search(line)

				if result:
					var font_size = result.get_string(1)
					var new_text = "=> Text [font_size=" + font_size + "]"
					set_line(get_caret_line(), new_text)
					set_caret_column(new_text.length())
					get_viewport().set_input_as_handled()
					return

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

func _request_code_completion(force:bool = false):
	var line = get_line(get_caret_line())
	var col = get_caret_column()
	var line_prefix = line.substr(0, col)

	# Emoji completion
	if line_prefix.contains(":emj"):
		var emoji_prefix = line_prefix.split(":emj")[-1].strip_edges().to_lower()

		var matches = _get_emoji_matches(emoji_prefix)
		for match_data in matches:
			var display_text = "%s %s (%s)" % [
				match_data.emoji,
				match_data.description,
				", ".join(match_data.aliases)
			]

			add_code_completion_option(
				CodeCompletionKind.KIND_CONSTANT,
				display_text,
				match_data.emoji,
				Color.WHITE,
				null,
				null,
				CodeCompletionLocation.LOCATION_LOCAL
			)

		update_code_completion_options(true)
		return

	var last_open_bracket = line_prefix.rfind("[")
	var last_close_bracket = line.rfind("]")
	# Component name completion
	if line_prefix.strip_edges().begins_with("=>"):
		if last_close_bracket < col and last_close_bracket > 0:
			update_code_completion_options(force)
			return
		var component_prefix = line_prefix.strip_edges().substr(2).strip_edges()
		if last_open_bracket != -1:
			component_prefix = line_prefix.strip_edges().substr(2,last_open_bracket-1)
					# Property completion - check if we're inside brackets
		if last_open_bracket != -1 and (last_close_bracket == -1 or last_open_bracket < last_close_bracket):
			var component_type = get_component_type_from_line(line)
			component_type = REDIRECT_COMPONENT_PROPERTIES.get(component_type,component_type) if component_type else component_type
			if component_type and COMPONENT_PROPERTIES.has(component_type):
				var properties = COMPONENT_PROPERTIES[component_type]
				var current_property = get_current_property(line_prefix)
				var partial_prop = get_partial_property(line_prefix)  # Get what user has typed so far

				for prop_name in properties:
					if current_property.is_empty() or prop_name.begins_with(current_property):
						var prop_type = properties[prop_name]
						var insert_text = prop_name
						var example_value = ""

						# Add default value based on type
						match prop_type:
							"int": example_value = "0"
							"float": example_value = "0.0"
							"bool": example_value = "false"
							"string": example_value = '""'
							"Vector2": example_value = "Vector2(0,0)"

						if not line_prefix.ends_with("="):
							insert_text += "="
						insert_text += example_value

						var display = "%s: %s" % [prop_name, prop_type]

						add_code_completion_option(
							CodeCompletionKind.KIND_MEMBER,
							display,
							insert_text.substr(current_property.length()),
							Color.WHITE,
							null,
							null,
							#"%s=%s" % [prop_name, example_value],
							CodeCompletionLocation.LOCATION_LOCAL
						)

				update_code_completion_options(true)
				return
		else:
			for component:String in COMPONENT_NAMES:
				if component.begins_with(component_prefix):
					# Add component with example properties
					var example_text = "=> %s" % component
					if COMPONENT_PROPERTIES.has(component):
						var props = COMPONENT_PROPERTIES[component]
						var example_props = []
						for prop_name in props:
							match props[prop_name]:
								"int": example_props.push_back("%s=0" % prop_name)
								"float": example_props.push_back("%s=0.0" % prop_name)
								"bool": example_props.push_back("%s=false" % prop_name)
								"string": example_props.push_back('%s=""' % prop_name)
								"Vector2": example_props.push_back("%s=Vector2(0,0)" % prop_name)
						if not example_props.is_empty():
							example_text += " [%s]" % example_props[0]
					if (not component_prefix.contains(component)) and line_prefix.count(" ") <= 1:
						add_code_completion_option(
							CodeCompletionKind.KIND_CLASS,
							component,
							component.substr(component_prefix.length()) + " ",
							Color.WHITE,
							null,
							null,
							CodeCompletionLocation.LOCATION_LOCAL
						)

			update_code_completion_options(true)
			return





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

func get_component_type_from_line(line: String) -> String:
	var regex = RegEx.new()
	regex.compile("=>\\s*(\\w+)")
	var result = regex.search(line)
	if result:
		var component_type = result.get_string(1)
		# Handle aliases
		match component_type:
			"LeftText", "RightText", "TopText", "BottomText":
				return "Text"
			"LeftImage", "RightImage":
				return "TextureRect"
		return component_type
	return ""

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

func get_current_property(line_prefix: String) -> String:
	var last_open_bracket = line_prefix.rfind("[")
	var last_comma = line_prefix.rfind(",")
	var start_pos = max(last_comma, last_open_bracket)
	if start_pos == -1:
		return ""

	var current = line_prefix.substr(start_pos + 1).strip_edges()
	# Remove any spaces after commas or opening bracket
	if current.begins_with(",") or current.begins_with("["):
		current = current.substr(1).strip_edges()

	var equals_pos = current.find("=")
	if equals_pos != -1:
		current = current.substr(0, equals_pos)

	return current.strip_edges()

func _filter_code_completion_candidates(candidates: Array) -> Array:
	# This method can be used to filter or modify completion candidates if needed
	return candidates

func get_partial_property(line_prefix: String) -> String:
	var last_open_bracket = line_prefix.rfind("[")
	var last_comma = line_prefix.rfind(",")
	var start_pos = max(last_comma, last_open_bracket)
	if start_pos == -1:
		return ""

	var current = line_prefix.substr(start_pos + 1).strip_edges()
	# Remove any spaces after commas or opening bracket
	if current.begins_with(",") or current.begins_with("["):
		current = current.substr(1).strip_edges()

	return current.strip_edges()

func _save_clipboard_image(image: Image) -> String:
	# Generate a unique filename based on timestamp
	var timestamp = Time.get_unix_time_from_system()
	var extension = "png"  # We'll save all images as PNG for consistency
	var filename = "image_%d.%s" % [timestamp, extension]

	# Get the absolute path from slide manager
	var absolute_path = SlideManager.slidesdirabsolute
	if absolute_path.is_empty():
		absolute_path = "%s/slides/" % OS.get_executable_path().get_base_dir()

	# Ensure the slides directory exists
	if not DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_absolute(absolute_path)

	# Save the image to the actual slides folder
	var full_path = absolute_path.path_join(filename)
	var error = image.save_png(full_path)
	if error == OK:
		# Create texture and take over the res:// path for Godot
		var texture = ImageTexture.create_from_image(image)
		texture.take_over_path("res://%s" % filename)

		# Add to slide manager's loaded images
		SlideManager.images_loaded[filename] = texture

		# Return the res:// path that Godot will use internally
		return "res://%s" % filename
	return ""
