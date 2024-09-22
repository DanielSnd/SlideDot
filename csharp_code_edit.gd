extends CodeEdit
class_name SharpCodeEdit

var dirty_text:bool = false
var color_red_bg:Color = Color("561d29",0.22)
var color_keyword:Color = Color("68abef",1.0)
signal idle_timer_procd_signal
signal error_clicked(line_number: int)

signal compile_pressed
#TODO: First start with all lines but inside the method frozen. Don't let them be editted until a later chapter. Make frozen lines look more frozen. Allow enter, new entered lines are not frozen.

@export var is_mouse_hovered:bool = false
func on_prepare_save():
	if Engine.has_singleton("YSave"):
		Engine.get_singleton("YSave").save_data["code"] = text

func _gui_input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.is_pressed():
		#if (not get_global_rect().has_point(event.position)) and has_focus():
			#release_focus()
			#focus_exited.emit()
	# Handle shortcuts that come from the editor
	if event is InputEventKey and event.is_pressed():
		#if locked_to_line > 0 and (event as InputEventKey).keycode == KEY_ENTER or  (event as InputEventKey).keycode == KEY_KP_ENTER:
			#get_viewport().set_input_as_handled()
		if locked_to_line > 0:
			if ((get_cursor().x == 0 and (event as InputEventKey).keycode == KEY_BACKSPACE)) and get_caret_line() > 0:
				var potential_prev_line = get_line(get_caret_line()-1)
				if (not potential_prev_line.is_empty()) and potential_prev_line.begins_with("  "):
					get_viewport().set_input_as_handled()

			elif (event as InputEventKey).keycode == KEY_DELETE:
				var line_text = get_line(get_caret_line())
				if get_cursor().x >= line_text.length() and get_line_count() > get_caret_line():
					var potential_next_line = get_line(get_caret_line()+1)
					if (not potential_next_line.is_empty()) and potential_next_line.begins_with("  "):
						get_viewport().set_input_as_handled()
		var shortcut: String = get_editor_shortcut(event)
		match shortcut:
			"compile":
				compile_pressed.emit()
			"toggle_comment":
				toggle_comment()
				get_viewport().set_input_as_handled()
			"delete_line":
				if locked_to_line == -1:
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

func set_dirty_text():
	dirty_text = true
	idle_timer.start()
	request_code_completion()

var locked_to_line:int = -1
func lock_to_line(line_to_lock_to:int= -1):
	if line_to_lock_to == -1:
		if caret_changed.is_connected(watch_for_locked_line_caret_change):
			caret_changed.disconnect(watch_for_locked_line_caret_change)
		locked_to_line = -1
	else:
		if not caret_changed.is_connected(watch_for_locked_line_caret_change):
			caret_changed.connect(watch_for_locked_line_caret_change)
		locked_to_line = line_to_lock_to - 1

func watch_for_locked_line_caret_change():
	if locked_to_line > 0 and get_line_count() > 0:
		if get_line(get_caret_line()).begins_with("  "):
			for i in get_line_count():
				if not get_line(i).begins_with("  "):
					set_caret_line(i)
					return

func _handle_unicode_input(unicode_char, caret_index:int ):
	if locked_to_line == -1:
		if  self.has_method(&"handle_unicode_input_internal"):
			call(&"handle_unicode_input_internal",unicode_char, caret_index)
	else:
		var current_text_line = get_line(get_caret_line(clamp(caret_index,0,get_caret_count())))
		if current_text_line.is_empty() or not current_text_line.begins_with("  "):
			if  self.has_method(&"handle_unicode_input_internal"):
				call(&"handle_unicode_input_internal",unicode_char, caret_index)

func idle_timer_procced():
	#print("Idle timer procced")
	#set_line_background_color(4,Color.RED)
	idle_timer_procd_signal.emit()
	pass

var idle_timer:Timer = null

func receive_code_analyzis_result(code_analysis_result):
	#prints("Receive code analysis result",code_analysis_result)
	if code_analysis_result.is_empty():
		return

	var members_arr = code_analysis_result[0]
	#var _code_completion_prefix = []
	(syntax_highlighter as CodeHighlighter).clear_member_keyword_colors()
	for i in members_arr:
		var string_member = (i[0])
		#print(i)
		(syntax_highlighter as CodeHighlighter).add_member_keyword_color(string_member,(syntax_highlighter as CodeHighlighter).member_variable_color)
		#_code_completion_prefix.push_back(string_member)
	#code_completion_prefixes = _code_completion_prefix
	#code_completion_enabled = true
	#print(code_completion_prefixes)

	var errors_arr = code_analysis_result[1]
	var _errors:Array = []
	#print(errors_arr)
	for arr:Array in errors_arr:
		if arr.size() > 2 and arr[1] is int and arr[2] is int:
			_errors.append({
				line_number = arr[1],
				column_number = arr[2],
				error = arr[0]
			})
	errors = _errors

var runtime_mono:
	get: return SlideManager.runtime_mono

func run_code_completion_request():
	if not is_instance_valid(runtime_mono):
		return
	if not is_instance_valid(runtime_mono.get_main_library()):
		return
	var text_for_completion = get_text_for_code_completion()
	 #Find the completion index
	var completion_index = text_for_completion.find(char(0xFFFF))

	# Find the first space to the left
	#var last_space = text_for_completion.rfind(" ", completion_index)
	#var word = ""
	#if last_space > -1:
		## If there's an space get the word we are writting
		## from the position of the last space to the position of the completion index
		#word = text_for_completion.substr(last_space + 1, completion_index - last_space - 1)
	#else:
		## If not then it's the start of the line so
		## get the word from the beginning to the completion index
		#word = text_for_completion.substr(0, completion_index)
	var potential_word:String = get_completion_symbol()
	#print("Potential word " , potential_word)
	# Remove extra spaces just in case
	#word = word.strip_edges()
	#print("word: ",word)

	runtime_mono.runtime_call_static_method(runtime_mono.get_main_library(), "CatacombCompiler", "Compiler", "set_cursor_position", str(completion_index))
	runtime_mono.runtime_call_static_method(runtime_mono.get_main_library(), "CatacombCompiler", "Compiler", "set_cursor_column", str(get_cursor().x))
	runtime_mono.runtime_call_static_method(runtime_mono.get_main_library(), "CatacombCompiler", "Compiler", "set_cursor_line", str(get_cursor().y))
	if potential_word.is_empty():
		update_code_completion_options(false)
		return
	runtime_mono.runtime_call_static_method(runtime_mono.get_main_library(), "CatacombCompiler", "Compiler", "set_partialName", potential_word)

	var results = runtime_mono.runtime_call_static_method(runtime_mono.get_main_library(), "CatacombCompiler", "Compiler", "GetCompletions", text)
	#print(results," is string? ",results is String)
	#print("attempting to get results for ", potential_word)
	if results is String:
		results = str_to_var(results)
	#print (results)
	#print(results is Array)
	if results is Array:
		for suggestion in results:
			var insert = suggestion
			if "(" in suggestion and ")" in suggestion:
				# For methods, remove everything between parentheses and add a semicolon
				insert = suggestion.split("(")[0] + "();"
			elif ":" in suggestion:
				# For variables, remove everything after the colon
				insert = suggestion.split(":")[0]
			add_code_completion_option(CodeEdit.CodeCompletionKind.KIND_MEMBER, suggestion, insert)
	#add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, "Dialogue OFF", "Dialogue [#typeon=false]")
	update_code_completion_options(false)
	#print(results)

# Called when the node enters the scene tree for the first time.
func _ready():
	mouse_entered.connect(func(): is_mouse_hovered = true)
	mouse_exited.connect(func(): is_mouse_hovered = false)
	if Engine.has_singleton("YSave"):
		Engine.get_singleton("YSave").prepare_save.connect(on_prepare_save)
	idle_timer = Timer.new()
	gutters_draw_breakpoints_gutter = false
	gutters_draw_executing_lines = false
	gutters_draw_bookmarks = false
	#gutters_draw_fold_gutter = false
	add_gutter(0)
	set_gutter_type(0, TextEdit.GUTTER_TYPE_ICON)
	add_child(idle_timer)
	idle_timer.wait_time = 1.5
	idle_timer.one_shot = true
	idle_timer.autostart = false
	idle_timer.timeout.connect(idle_timer_procced)
	code_completion_requested.connect(run_code_completion_request)
	code_completion_enabled = true
	text_changed.connect(set_dirty_text)
	set_highlight_keywords()
	add_string_delimiter("@\"", "\"")
	add_comment_delimiter("/**"," */")
	add_comment_delimiter("/*"," */")
	add_comment_delimiter("///","",true)
	add_comment_delimiter("//","",true)
	#add_comment_delimiter("  ","",true)
	auto_brace_completion_pairs["/*"] = "*/"
	auto_brace_completion_pairs["/**"] = "*/"
	auto_brace_completion_pairs["@\""] = "\""
	get_editor_shortcuts()

func set_highlight_keywords():
	if already_added_stuff:
		return
	already_added_stuff = true

	(syntax_highlighter as CodeHighlighter).add_keyword_color("int",Color(0.7,0.4,0.4))
	syntax_highlighter.add_keyword_color("abstract", Color(color_keyword))
	syntax_highlighter.add_keyword_color("as", Color(color_keyword))
	syntax_highlighter.add_keyword_color("base", Color(color_keyword))
	syntax_highlighter.add_keyword_color("bool", Color(color_keyword))
	syntax_highlighter.add_keyword_color("break", Color(color_keyword))
	syntax_highlighter.add_keyword_color("byte", Color(color_keyword))
	syntax_highlighter.add_keyword_color("case", Color(color_keyword))
	syntax_highlighter.add_keyword_color("catch", Color(color_keyword))
	syntax_highlighter.add_keyword_color("char", Color(color_keyword))
	syntax_highlighter.add_keyword_color("checked", Color(color_keyword))
	syntax_highlighter.add_keyword_color("class", Color(color_keyword))
	syntax_highlighter.add_keyword_color("const", Color(color_keyword))
	syntax_highlighter.add_keyword_color("continue", Color(color_keyword))
	syntax_highlighter.add_keyword_color("decimal", Color(color_keyword))
	syntax_highlighter.add_keyword_color("default", Color(color_keyword))
	syntax_highlighter.add_keyword_color("delegate", Color(color_keyword))
	syntax_highlighter.add_keyword_color("do", Color(color_keyword))
	syntax_highlighter.add_keyword_color("double", Color(color_keyword))
	syntax_highlighter.add_keyword_color("else", Color(color_keyword))
	syntax_highlighter.add_keyword_color("enum", Color(color_keyword))
	syntax_highlighter.add_keyword_color("event", Color(color_keyword))
	syntax_highlighter.add_keyword_color("explicit", Color(color_keyword))
	syntax_highlighter.add_keyword_color("extern", Color(color_keyword))
	syntax_highlighter.add_keyword_color("false", Color(color_keyword))
	syntax_highlighter.add_keyword_color("finally", Color(color_keyword))
	syntax_highlighter.add_keyword_color("fixed", Color(color_keyword))
	syntax_highlighter.add_keyword_color("float", Color(color_keyword))
	syntax_highlighter.add_keyword_color("for", Color(color_keyword))
	syntax_highlighter.add_keyword_color("foreach", Color(color_keyword))
	syntax_highlighter.add_keyword_color("goto", Color(color_keyword))
	syntax_highlighter.add_keyword_color("f", Color(color_keyword))
	syntax_highlighter.add_keyword_color("mplicit", Color(color_keyword))
	syntax_highlighter.add_keyword_color("n", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nt", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nterface", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nternal", Color(color_keyword))
	syntax_highlighter.add_keyword_color("s", Color(color_keyword))
	syntax_highlighter.add_keyword_color("lock", Color(color_keyword))
	syntax_highlighter.add_keyword_color("long", Color(color_keyword))
	syntax_highlighter.add_keyword_color("namespace", Color(color_keyword))
	syntax_highlighter.add_keyword_color("new", Color(color_keyword))
	syntax_highlighter.add_keyword_color("null", Color(color_keyword))
	syntax_highlighter.add_keyword_color("object", Color(color_keyword))
	syntax_highlighter.add_keyword_color("operator", Color(color_keyword))
	syntax_highlighter.add_keyword_color("out", Color(color_keyword))
	syntax_highlighter.add_keyword_color("override", Color(color_keyword))
	syntax_highlighter.add_keyword_color("params", Color(color_keyword))
	syntax_highlighter.add_keyword_color("private", Color(color_keyword))
	syntax_highlighter.add_keyword_color("protected", Color(color_keyword))
	syntax_highlighter.add_keyword_color("public", Color(color_keyword))
	syntax_highlighter.add_keyword_color("readonly", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ref", Color(color_keyword))
	syntax_highlighter.add_keyword_color("return", Color(color_keyword))
	syntax_highlighter.add_keyword_color("sbyte", Color(color_keyword))
	syntax_highlighter.add_keyword_color("sealed", Color(color_keyword))
	syntax_highlighter.add_keyword_color("short", Color(color_keyword))
	syntax_highlighter.add_keyword_color("sizeof", Color(color_keyword))
	syntax_highlighter.add_keyword_color("stackalloc", Color(color_keyword))
	syntax_highlighter.add_keyword_color("static", Color(color_keyword))
	syntax_highlighter.add_keyword_color("string", Color(color_keyword))
	syntax_highlighter.add_keyword_color("struct", Color(color_keyword))
	syntax_highlighter.add_keyword_color("switch", Color(color_keyword))
	syntax_highlighter.add_keyword_color("his", Color(color_keyword))
	syntax_highlighter.add_keyword_color("hrow", Color(color_keyword))
	syntax_highlighter.add_keyword_color("rue", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ry", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ypeof", Color(color_keyword))
	syntax_highlighter.add_keyword_color("uint", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ulong", Color(color_keyword))
	syntax_highlighter.add_keyword_color("unchecked", Color(color_keyword))
	syntax_highlighter.add_keyword_color("unsafe", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ushort", Color(color_keyword))
	syntax_highlighter.add_keyword_color("using", Color(color_keyword))
	syntax_highlighter.add_keyword_color("virtual", Color(color_keyword))
	syntax_highlighter.add_keyword_color("void", Color(color_keyword))
	syntax_highlighter.add_keyword_color("volatile", Color(color_keyword))
	syntax_highlighter.add_keyword_color("while", Color(color_keyword))
	syntax_highlighter.add_keyword_color("add", Color(color_keyword))
	syntax_highlighter.add_keyword_color("alias", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ascending", Color(color_keyword))
	syntax_highlighter.add_keyword_color("async", Color(color_keyword))
	syntax_highlighter.add_keyword_color("await", Color(color_keyword))
	syntax_highlighter.add_keyword_color("by", Color(color_keyword))
	syntax_highlighter.add_keyword_color("descending", Color(color_keyword))
	syntax_highlighter.add_keyword_color("dynamic", Color(color_keyword))
	syntax_highlighter.add_keyword_color("equals", Color(color_keyword))
	syntax_highlighter.add_keyword_color("from", Color(color_keyword))
	syntax_highlighter.add_keyword_color("get", Color(color_keyword))
	syntax_highlighter.add_keyword_color("global", Color(color_keyword))
	syntax_highlighter.add_keyword_color("group", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nto", Color(color_keyword))
	syntax_highlighter.add_keyword_color("join", Color(color_keyword))
	syntax_highlighter.add_keyword_color("let", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nameof", Color(color_keyword))
	syntax_highlighter.add_keyword_color("on", Color(color_keyword))
	syntax_highlighter.add_keyword_color("orderby", Color(color_keyword))
	syntax_highlighter.add_keyword_color("partial", Color(color_keyword))
	syntax_highlighter.add_keyword_color("remove", Color(color_keyword))
	syntax_highlighter.add_keyword_color("select", Color(color_keyword))
	syntax_highlighter.add_keyword_color("set", Color(color_keyword))
	syntax_highlighter.add_keyword_color("value", Color(color_keyword))
	syntax_highlighter.add_keyword_color("var", Color(color_keyword))
	syntax_highlighter.add_keyword_color("when", Color(color_keyword))
	syntax_highlighter.add_keyword_color("where", Color(color_keyword))
	syntax_highlighter.add_keyword_color("yield", Color(color_keyword))
	(syntax_highlighter as CodeHighlighter).clear_color_regions()
	(syntax_highlighter as CodeHighlighter).add_color_region("\"", "\"", Color("c6a859"))
	(syntax_highlighter as CodeHighlighter).add_color_region("//", "", Color(0.3,0.3,0.3), true)


var already_added_stuff:bool = false
# Toggle the selected lines as comments
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



# Get the current caret as a Vector2
func get_cursor() -> Vector2i:
	return Vector2i(get_caret_column(), get_caret_line())


# Set the caret from a Vector2
func set_cursor(from_cursor: Vector2) -> void:
	set_caret_line(int(from_cursor.y) as int)
	set_caret_column(int(from_cursor.x) as int)


# Check if a prompt is the start of a string without actually being that string
func matches_prompt(prompt: String, matcher: String) -> bool:
	return prompt.length() < matcher.length() and matcher.to_lower().begins_with(prompt.to_lower())

const ERRORICON = preload("res://icons/cross_smol.png")

# Mark a line as an error or not
func mark_line_as_error(line_number: int, is_error: bool) -> void:
	#print("MARK LINE AS ERROR")
	if is_error:
		set_line_background_color(line_number, color_red_bg)
		set_line_gutter_icon(line_number, 0, ERRORICON)
	else:
		if locked_to_line > 0:
			var actual_line = get_line(line_number)
			if (not actual_line.is_empty()) and actual_line.begins_with("  "):
				set_line_background_color(line_number, Color(0.23,0.23,0.23,0.12))
				set_line_gutter_icon(line_number, 0, null)
				return
		set_line_background_color(line_number, Color(0,0,0,0))
		set_line_gutter_icon(line_number, 0, null)

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


# The last selection (if there was one) so we can remember it for refocusing
var last_selected_text: String

func get_completion_symbol():
	var cursor: Vector2 = get_cursor()
	var current_line: String = get_line(int(cursor.y) as int)
	var line_up_to_cursor: String = current_line.substr(0, int(cursor.x) as int)
	#var previous_letter:String = current_line.substr((int(cursor.x) as int)-1, ((int(cursor.x)) as int) + 1)
	#print("prev: ",previous_letter)
	# Regular expression to match word characters (letters, digits, underscore)
	var regex = RegEx.new()
	regex.compile("\\w+$")

	var result = regex.search(line_up_to_cursor)
	if result:
		return result.get_string()
	else:
		return ""

var font_size: int:
	set(value):
		font_size = value
		add_theme_font_size_override("font_size", font_size)
	get:
		return font_size

# Any parse errors
var errors: Array:
	set(next_errors):
		errors = next_errors
		for i in range(0, get_line_count()):
			var is_error: bool = false
			for error in errors:
				if error.line_number == i:
					is_error = true
			mark_line_as_error(i, is_error)
		_on_code_edit_caret_changed()
	get:
		return errors


func _on_code_edit_text_set() -> void:
	queue_redraw()

func _on_code_edit_caret_changed() -> void:
	last_selected_text = get_selected_text()

func _on_code_edit_gutter_clicked(line: int, _gutter: int) -> void:
	var line_errors = errors.filter(func(error): return error.line_number == line)
	if line_errors.size() > 0:
		error_clicked.emit(line)

func _on_errors_panel_error_pressed(line_number: int, column_number: int) -> void:
	set_caret_line(line_number)
	set_caret_column(column_number)
	grab_focus()
