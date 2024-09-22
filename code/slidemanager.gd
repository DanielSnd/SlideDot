## TODO: TEACH ABOUT BREAKPOINTS SO THEY CAN FOLLOW THE FLOW OF CODE

class_name SlideManager
extends CanvasLayer
@onready var slider_holder = %SliderHolder
@onready var spin_wheel = %SpinWheel
@onready var spin_contents = %SpinContents

var is_debugging = false
@export var type_characters_per_second = 100.0
var slide_folder = "res://slides/"
static var slides = []
var current_slide_index = 0:
	set(v):
		if is_debugging:
			print("Current slide index was [%s] it'll now be [%s]" % [current_slide_index, v])
		current_slide_index = v
var ui_elements = {}
var active_label = null:
	set(v):
		if is_debugging:
			print("Active label was [%s] it'll now be [%s]" % [active_label, v])
		active_label = v
var active_container = null
var runtime_loaded_images:Array[Texture2D] = []
static var runtime_mono = null
static var assemblycompiled = null
static var dynamic_compiler_assembly = null
static var dynamic_compiler_bytes:PackedByteArray = []
var class_instances:Dictionary = {}
var methods_dictionary:Dictionary = {}

signal started_compiling
signal recompile_finished(success:bool)
signal finished_checking_for_methods(success:bool)
var has_compiled_already:bool = false
var is_compiling:bool = false
signal compilation_finished_csharp
static var editor_focused:bool = false
var current_editor_focused:CodeEdit = null

var collect_errors:String = ""

var current_slide_elements = []
var revealed_elements = 0
var animating = false
var visited_slides = {}

func clicked_bg():
	if editor_focused:
		editor_focused = false
		%SliderHolder.grab_focus()

func _ready():
	YSave.request_load()
	Engine.max_fps = 30
	load_slides()
	show_slide(current_slide_index)
	finish_readying()
	spin_contents.get_parent().visible = false
	spin_wheel.visible = false
	(spin_contents.syntax_highlighter as CodeHighlighter).add_color_region("#","",Color.DIM_GRAY,true)
	spin_contents.focus_entered.connect(focused_code_editor.bind(spin_contents, true))
	spin_contents.focus_exited.connect(focused_code_editor.bind(spin_contents, false))

func spin():
	if spin_wheel.has_meta("animating"):
		return

	var scYtwn := YTween.create_unique_tween(spin_wheel)
	if spin_wheel.position.x < -0.1:
		set_segments_spin_wheel()
		spin_wheel.current_rotation = randf_range(-120.0,120.0)
		spin_wheel.set_meta("animating", true)
		spin_wheel.visible = true
		scYtwn.tween_property(spin_wheel, "position:x", 0, 2.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK, 1.82)
		spin_wheel.queue_redraw()
		await scYtwn.finished
		spin_wheel.spin()
		var winner = await spin_wheel.winner_selected_emit
		print("Winner: %s" % winner)
		spin_wheel.remove_meta("animating")
	else:
		spin_wheel.set_meta("animating", true)
		scYtwn.tween_property(spin_wheel, "position:x", -400.0, 2.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK, 1.82)
		scYtwn.finished.connect(func(): spin_wheel.visible = false)
		await scYtwn.finished
		spin_wheel.remove_meta("animating")

func toggle_spin_code_editor():
	var scYtwn := YTween.create_unique_tween(spin_contents.get_parent())
	if spin_contents.get_parent().position.x < -0.1:
		if spin_contents.text.is_empty():
			spin_contents.text = YSave.save_data.get("spincode","")
		spin_contents.get_parent().visible = true
		scYtwn.tween_property(spin_contents.get_parent(), "position:x", 0, 2.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK, 1.82)
		scYtwn.finished.connect(spin_contents.grab_focus)
	else:
		if get_viewport().gui_get_focus_owner() == spin_contents:
			spin_contents.release_focus()
		scYtwn.tween_property(spin_contents.get_parent(), "position:x", -400.0, 2.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK, 1.82)
		scYtwn.finished.connect(func(): spin_contents.get_parent().visible = false)
		YSave.save_data["spincode"] = spin_contents.text
		YSave.request_save()

func set_segments_spin_wheel():
	if spin_contents.text.is_empty():
		spin_contents.text = YSave.save_data.get("spincode","")
	var lines_spin:PackedStringArray = spin_contents.text.split("\n",false)
	var spin_names:Array = []
	for i in lines_spin:
		if i.strip_edges().begins_with("#"):
			continue
		spin_names.push_back(i)
	spin_names.shuffle()
	spin_wheel.set_segments(spin_names)

var has_slide_editor:SlideEditor = null

func finish_readying():
	await get_tree().process_frame
	if not ClassDB.class_exists(&"RuntimeMono"):
		return
	#print("Starting runtime mono stuff")
	var brand_mew_mono: = false
	if runtime_mono == null and not is_instance_valid(runtime_mono):
		runtime_mono = ClassDB.instantiate(&"RuntimeMono")
		brand_mew_mono = true
		#runtime_mono.set_debug_coroutines(true)
		runtime_mono.coroutine_namespace = "CatacombEngine"
		runtime_mono.coroutine_type = "Coroutine"

	await get_tree().process_frame

	add_csharp_calls()
	var _result_mono = runtime_mono.start_mono() if brand_mew_mono else true
	if dynamic_compiler_bytes.is_empty():
		var dynamic_compiler_dll_name:String = "dynamic-compiler.dll"
		var dynamic_compiler_dll_path :String = ("%s/mono/lib/%s" % [OS.get_executable_path().get_base_dir(), dynamic_compiler_dll_name]) if  FileAccess.file_exists(("%s/mono/lib/%s" % [OS.get_executable_path().get_base_dir(), dynamic_compiler_dll_name])) else (("%s/%s" % [OS.get_executable_path().get_base_dir(), dynamic_compiler_dll_name]))
		dynamic_compiler_bytes = FileAccess.get_file_as_bytes(dynamic_compiler_dll_path)
		#print(dynamic_compiler_bytes.size())

	await get_tree().process_frame

	reload_app_domain_stuff()

	await get_tree().process_frame
	add_csharp_calls()

static var images_loaded:Dictionary = {}

static var slidesdirabsolute:String = ""
func load_slides():
	slides.clear()
	visited_slides.clear()
	if slidesdirabsolute.is_empty():
		slidesdirabsolute = "%s/slides/" % OS.get_executable_path().get_base_dir()
	#print("%s/slides/" % [OS.get_executable_path().get_base_dir()])
	if DirAccess.dir_exists_absolute(slidesdirabsolute):
		slide_folder = slidesdirabsolute
	var dir = DirAccess.open(slide_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".txt"):
				slides.append(slide_folder + file_name)
			if not dir.current_is_dir() and file_name.ends_with(".config"):
				pass
			if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".svg") or file_name.ends_with(".webp") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg")):
				var image_loaded:Image = Image.load_from_file(slide_folder + file_name)
				if is_instance_valid(image_loaded):
					var converted_imgtexture:ImageTexture = ImageTexture.create_from_image(image_loaded)
					if is_instance_valid(converted_imgtexture):
						images_loaded[file_name] = converted_imgtexture
						converted_imgtexture.take_over_path("res://%s" % file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	slides.sort()

func show_slide(index):
	if index < 0 or index >= slides.size():
		return

	clear_current_slide()
	current_slide_elements.clear()
	parse_slide_file(slides[index])

	# Store all elements of the current slide, including children
	var get_all_elements_result = get_all_elements(ui_elements.values())
	for i in get_all_elements_result:
		if not current_slide_elements.has(i) and not i.has_meta(&"insta_appear"):
			if &"text" in i and i.text.is_empty():
				continue
			current_slide_elements.push_back(i)
		elif i.has_meta(&"insta_appear") and i.has_method(&"skip_typing"):
			i.skip_typing()
	#print("SHOW SLIDE GET ALL ELEMENTS: ",get_all_elements_result)
	#print("SHOW CURRENT ELEMENTS: ",current_slide_elements)

	revealed_elements = 0

	if visited_slides.has(index):
		# If we've visited this slide before, show all elements immediately
		reveal_all_elements()
	else:
		# Hide all elements initially
		for element in current_slide_elements:
			element.modulate.a = 0

		# Reveal the first element immediately
		if not current_slide_elements.is_empty():
			reveal_element(0)


	# Mark this slide as visited
	visited_slides[index] = true

func get_all_elements(elements):
	var all_elements = []
	for element in elements:
		if element is RichTextLabel or element is SharpEditorPanel or element is Label or element is ConsoleDisplay or element is WikiRichTextLabel or element is TextureRect:
			if not all_elements.has(element):
				all_elements.append(element)
		if element is Control and element.get_child_count() > 0:
			all_elements += get_all_elements(element.get_children())
	return all_elements

var current_typing_element:WikiRichTextLabel = null

func reveal_element(index: int, animate: bool = true):
	if index >= current_slide_elements.size():
		return

	var element = current_slide_elements[index]

	if index < revealed_elements:
		return

	if animate:
		animating = true
		if element is WikiRichTextLabel:
			var tween = create_tween()
			tween.tween_property(element, "modulate:a", 1.0, 0.3)
			if type_characters_per_second == null:
				type_characters_per_second = 100.0
			element.characters_per_second = type_characters_per_second  # Adjust this value to change typing speed
			element.type_out()
			current_typing_element = element
			await element.finished_typing
			if is_instance_valid(element) and is_instance_valid(current_typing_element) and current_typing_element == element:
				current_typing_element = null
		elif element is VBoxContainer or element is HBoxContainer:
			element.modulate.a = 1.0
			for child in element.get_children():
				if child in current_slide_elements:
					await reveal_element(current_slide_elements.find(child), animate)
		else:
			var tween := YTween.create_unique_tween(element)
			tween.tween_property(element, "modulate:a", 1.0, 0.5)
			await tween.finished_or_killed
		animating = false
	elif is_instance_valid(element):
		element.modulate.a = 1.0
		if element is WikiRichTextLabel:
			element.skip_typing()
		elif element is VBoxContainer or element is HBoxContainer:
			for child in element.get_children():
				if child in current_slide_elements:
					reveal_element(current_slide_elements.find(child), animate)

	revealed_elements = max(revealed_elements, index + 1)

func reveal_all_elements():
	for i in range(revealed_elements, current_slide_elements.size()):
		reveal_element(i, false)
	revealed_elements = current_slide_elements.size()

func clear_current_slide():
	for i in slider_holder.get_children():
		i.queue_free()
	if current_editor_focused != null:
		current_editor_focused = null
	for element in ui_elements.values():
		element.queue_free()
	active_label = null
	active_container = null
	ui_elements.clear()
	current_slide_elements.clear()
	current_typing_element = null
	editor_focused = false
	set_holder_margins("40,10,40,15")
	if is_debugging:
		print("Cleared current slide")

func set_holder_margins(margins:String):
	var split_margins = margins.split(",", false)
	var margin_sides:Array[String] = ["margin_left","margin_top","margin_right","margin_bottom"]
	if split_margins.size() == 1:
		for i in margin_sides:
			%SliderHolder.add_theme_constant_override(i, split_margins[0].to_int())
	elif split_margins.size() == 2:
		%SliderHolder.add_theme_constant_override(margin_sides[0], split_margins[0].to_int())
		%SliderHolder.add_theme_constant_override(margin_sides[2], split_margins[0].to_int())
		%SliderHolder.add_theme_constant_override(margin_sides[1], split_margins[1].to_int())
		%SliderHolder.add_theme_constant_override(margin_sides[3], split_margins[1].to_int())
	elif split_margins.size() == 4:
		for i in margin_sides.size():
			%SliderHolder.add_theme_constant_override(margin_sides[i], split_margins[i].to_int())

var last_parsed_slide_path:String = ""
func parse_slide_file(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	if is_debugging:
		print("Parsing slide path %s cached? %s" % [file_path, cached_edited_path.has(file_path)])
	last_parsed_slide_path = file_path
	var full_content = file.get_as_text()
	if cached_edited_path.has(file_path):
		full_content = cached_edited_path[file_path]
	if (not full_content.is_empty()) and (not full_content.split("\n",false)[0].contains("=>")):
		full_content = "%s%s" % ["""=> Margins 90,50,90,10
=> VBOX
=> TEXT\n""",full_content]
		if is_debugging:
			print("Initial Command not found, added initial vbox container when parsing ",file_path)
	parse_slide_text(full_content)

var last_parsed_was_empty_line:bool = false
func parse_slide_text(full_content:String):
	var in_list:bool = false
	var list_buffer:String = ""
	# Read the entire file content
	# Convert markdown-style elements to BBCode
	full_content = convert_markdown_to_bbcode(full_content)
	last_text_slide = full_content
	#print(full_content)
	# Split the content into lines for processing
	var lines = full_content.split("\n")

	for line_index in lines.size():
		var original_line = lines[line_index]
		var line = lines[line_index].strip_edges()
		if line.is_empty():
			if active_label and &"text" in active_label:
				if &"bbcode_enabled" in active_label and not in_list:
					if last_parsed_was_empty_line:
						var close_font_size_lenght:int = "[/font_size]".length()
						if (active_label.text as String).ends_with("[/font_size]"):
							var text_length:int = active_label.text.length()
							active_label.text = "%s\n [/font_size]" % active_label.text.substr(0,text_length - close_font_size_lenght)
					else:
						active_label.text = "%s[font_size=%d]\n [/font_size]" % [active_label.text, roundi(active_label.get_meta("font_size",24) * 0.4)]
					last_parsed_was_empty_line = true
				else:
					if active_label is ConsoleDisplay:
						active_label.constructing_script = "%s\n" % active_label.text
					else:
						active_label.text = "%s\n" % active_label.text
			if in_list:
				finish_list(active_label, list_buffer)
				in_list = false
			continue
		if active_label == null or (not is_instance_valid(active_label)):
			active_label = YEngine.find_node_with_type(%SliderHolderHolder, "RichTextLabel")
		if active_label == null or (not is_instance_valid(active_label)):
			execute_command("Text",0)
		if (not (active_label is ConsoleDisplay or active_label is CodeEdit)) and line.begins_with("# "):
			original_line = "[color=468bbe][b][font_size=%d][font name=res://ui/LilitaOne-Regular.ttf embolden=0.5]%s[/font][/font_size][/b][/color]" % [(active_label).get_theme_font_size("bold_font_size") + 18, line.substr(2, -1)]
			lines[line_index] = original_line
			line = original_line
		elif (not (active_label is ConsoleDisplay or active_label is CodeEdit)) and line.begins_with("#- "):
			original_line = "[b][font_size=%d][font name=res://ui/LilitaOne-Regular.ttf embolden=0.5]%s[/font][/font_size][/b]" % [(active_label).get_theme_font_size("bold_font_size") + 18, line.substr(3, -1)]
			lines[line_index] = original_line
			line = original_line
		elif (not (active_label is ConsoleDisplay or active_label is CodeEdit)) and line.begins_with("## "):
			original_line = "[color=468bbe][b][font_size=%d][font name=res://ui/LilitaOne-Regular.ttf embolden=0.3]%s[/font][/font_size][/b][/color]" % [(active_label).get_theme_font_size("bold_font_size") + 12, line.substr(3, -1)]
			lines[line_index] = original_line
			line = original_line
		elif (not (active_label is ConsoleDisplay or active_label is CodeEdit)) and line.begins_with("##- "):
			original_line = "[b][font_size=%d][font name=res://ui/LilitaOne-Regular.ttf embolden=0.3]%s[/font][/font_size][/b]" % [(active_label).get_theme_font_size("bold_font_size") + 12, line.substr(4, -1)]
			lines[line_index] = original_line
			line = original_line

		var is_line_list_start = (not (active_label is ConsoleDisplay or active_label is CodeEdit)) and  (line.begins_with("- ") or line.begins_with("* "))
		if not is_line_list_start and in_list:
			last_parsed_was_empty_line = false
			finish_list(active_label, list_buffer)
			in_list = false

		if original_line.begins_with("//"):
			continue
		elif is_line_list_start:
			if not in_list:
				in_list = true
				list_buffer = "[ul]"
			list_buffer = "%s  %s\n" % [list_buffer, line.substr(2)]
		elif original_line.begins_with("=>"):
			last_parsed_was_empty_line = false
			execute_command(original_line.substr(2).strip_edges(), line_index)
		else:
			#print("line: [%s] active label %s"% [line, active_label])
			if active_label and is_instance_valid(active_label) and &"text" in active_label:
				active_label.text = "%s%s%s" % [active_label.text,  "\n" if (not active_label.text.is_empty()) and (not last_parsed_was_empty_line) else "", lines[line_index]]
				last_parsed_was_empty_line = false
	if in_list:
		last_parsed_was_empty_line = false
		finish_list(active_label, list_buffer)
		in_list = false
	for i in ui_elements.values():
		if i.has_method("set_page"):
			#print("Set page ",i," with ",i.text)
			(i as WikiRichTextLabel).set_page(null, i.text)
		if i is ConsoleDisplay and not (i as ConsoleDisplay).constructing_script.is_empty():
			(i as ConsoleDisplay).create_child_script((i as ConsoleDisplay).constructing_script)

func finish_list(label, list_content):
	if label and label is RichTextLabel:
		list_content += "[/ul]"
		label.text += (list_content)

func create_ui_with_new_command_parse(command_text:String,parts:PackedStringArray, text_line:int, default_parts:String = ""):
	create_ui_element(parse_new_command(("%s %s" % [command_text,parts[1]]) if parts.size() > 1 else "%s%s%s" % [command_text, " " if not default_parts.is_empty() else "",default_parts],text_line), text_line)

const POSSIBLE_CREATE_UI_COMMANDS = [
	"LEFTTEXT" , "TEXT", "QRCODE", "CONSOLE", "VBOX", "HBOX", "ENDHBOX", "VBOX", "CODE", "TOPTEXT", "BOTTOMTEXT", "RIGHTTEXT", "RIGHTIMAGE", "LEFTIMAGE", "TEXTURERECT"
]

const CREATE_REPLACE = {
	"VBOX" : "VBoxContainer" ,
	"HBOX" : "HBoxContainer", "TEXTLEFT" : "LEFTTEXT", "TEXTRIGHT" : "RIGHTTEXT", "TEXTTOP" : "TOPTEXT", "TEXTBOTTOM" : "BOTTOMTEXT"
}

const CREATE_DEFAULTS = {
	"VBOX" : "[anchors_preset = 15, anchor_right = 1.0, anchor_bottom = 1.0]",
	"HBOX" : "[anchors_preset = 15, anchor_right = 1.0, anchor_bottom = 1.0, theme_override_constants/separation = 20]",
	"CODE" : "[min_size_y = 300, code_font_size=18]"
}

func execute_command(command, text_line:int):
	var parts = command.split(" ", false, 1)
	#prints("Command parts:",parts)
	var cmd = parts[0].to_upper()
	match cmd:
		"ENDHBOX":
			if active_container != null and is_instance_valid(active_container) and active_container is HBoxContainer:
				active_container = active_container.get_parent()
		"NEW":
			create_ui_element(parse_new_command(parts[1],text_line), text_line)
		"SETACTIVELABEL","SETLABEL":
			set_active_label(parts[1])
		"SETBACKGROUNDIMAGE","SETBGIMAGE","SETBG":
			%BG.texture = load(parts[1].strip_edges())
		"SETMARGIN","SETMARGINS","MARGINS","MARGIN":
			set_holder_margins(parts[1].strip_edges())
		_:
			if not POSSIBLE_CREATE_UI_COMMANDS.has(cmd) and CREATE_REPLACE.has(cmd):
				cmd = CREATE_REPLACE[cmd]
			if POSSIBLE_CREATE_UI_COMMANDS.has(cmd):
				var default_params:String = CREATE_DEFAULTS[cmd] if CREATE_DEFAULTS.has(cmd) else ""
				if CREATE_REPLACE.has(cmd):
					cmd = CREATE_REPLACE[cmd]
					if default_params.is_empty() and CREATE_DEFAULTS.has(cmd):
						default_params = CREATE_DEFAULTS[cmd]
				create_ui_with_new_command_parse(cmd,parts,text_line,default_params)
			else:
				push_warning("Slide => Command [%s] not found (line: %d)" % [cmd, text_line])

var has_current_fake_console = null

func parse_new_command(command_string:String, text_line:int):
	var params = {}
	var parts = command_string.split(" ", false, 1)
	params["type"] = parts[0]

	if parts.size() > 1:
		if parts[1].strip_edges()[0] == "[":
			params["name"] = "%s%d" % [parts[0], rand_from_seed(YEngine.string_to_hash(last_parsed_slide_path) + text_line + command_string.length())[0]]
			params["set"] = parse_set_arguments(parts[1])
		else:
			var name_parts = (parts[1] as String).split(" ", false, 1)
			var full_name = name_parts[0]
			#print("Name parts ",name_parts," full name ",full_name)
			if full_name.ends_with("::"):
				# Generate a random name
				params["name"] = "%s%d" % [parts[0], rand_from_seed(YEngine.string_to_hash(last_parsed_slide_path)  + text_line+ command_string.length())[0]]
				params["parent"] = full_name.trim_suffix("::")
			elif "::" in full_name:
				var name_split = full_name.split("::")
				params["parent"] = name_split[0]
				params["name"] = name_split[1]
			else:
				params["name"] = full_name if not full_name.is_empty() else "%s%d" % [parts[0], rand_from_seed(YEngine.string_to_hash(last_parsed_slide_path) + text_line + command_string.length())[0]]

			if name_parts.size() > 1:
				params["set"] = parse_set_arguments(name_parts[1])
	else:
		# No name or parent specified, use default
		params["name"] = "%s%d" % [parts[0], rand_from_seed(YEngine.string_to_hash(last_parsed_slide_path) + text_line + command_string.length())[0]]

	# If no parent is specified, find the last VBox or HBox
	if not "parent" in params:
		if is_instance_valid(active_container):
			params["parent"] = active_container.name
		else:
			var _find_last_container:String = find_last_container()
			if not _find_last_container.is_empty():
				params["parent"] = _find_last_container

	return params

func find_last_container():
	# Implement this function to find the last VBox or HBox created
	# This is a placeholder implementation
	for key in range(ui_elements.keys().size() -1, -1,-1):
		if ui_elements[ui_elements.keys()[key]] is VBoxContainer or ui_elements[ui_elements.keys()[key]] is HBoxContainer:
			active_container = ui_elements[ui_elements.keys()[key]]
			return ui_elements.keys()[key]
	return ""  # Default to MainVbox if no container is found

func parse_set_arguments(arg_string):
	var set_params = {}
	var regex = RegEx.new()
	regex.compile("\\[([^\\]]+)\\]")

	for result in regex.search_all(arg_string):
		var content = result.get_string(1)
		var pairs = split_preserving_quotes(content)

		for pair in pairs:
			var kv = pair.split("=", false, 1)
			if kv.size() == 2:
				var key = kv[0].strip_edges()
				var value = kv[1].strip_edges()

				# Remove surrounding quotes if present
				if value.begins_with('"') and value.ends_with('"'):
					value = value.substr(1, value.length() - 2)

				# Convert value to appropriate type
				if value.is_valid_int():
					value = value.to_int()
				elif value.is_valid_float():
					value = value.to_float()
				elif value.to_lower() == "true":
					value = true
				elif value.to_lower() == "false":
					value = false

				set_params[key] = value

	return set_params

func split_preserving_quotes(input_string):
	var result = []
	var current = ""
	var in_quotes = false
	var in_parentheses = 0

	for c in input_string:
		if c == '"' and in_parentheses == 0:
			in_quotes = !in_quotes
			current += c
		elif c == '(' and not in_quotes:
			in_parentheses += 1
			current += c
		elif c == ')' and not in_quotes:
			in_parentheses -= 1
			current += c
		elif c == ',' and not in_quotes and in_parentheses == 0:
			result.append(current.strip_edges())
			current = ""
		else:
			current += c

	if current:
		result.append(current.strip_edges())

	return result

func request_compile(code_edit_requesting:SharpEditorPanel):
	if (not ClassDB.class_exists(&"RuntimeMono")) or is_compiling:
		return
	is_compiling = true
	started_compiling.emit()
	pressed_desired = null
	code_edit_requesting.modulate.a = 0.4
	var had_console_open:bool = ClassDB.class_call_static_method(&"RuntimeMono",&"has_open_console")
	if  had_console_open:
		ClassDB.class_call_static_method(&"RuntimeMono",&"clear_console")
	for i in 3:
		await get_tree().process_frame
	var started_compiling_time = Time.get_ticks_msec()
	recompile_threaded(started_compiling_time, code_edit_requesting.code_edit.text)
	await recompile_finished
	await get_tree().process_frame
	if is_instance_valid(assemblycompiled):
		print("Compilation Succeed in %.2f secs" % ((Time.get_ticks_msec() - started_compiling_time)*0.001))
		var use_code:String = code_edit_requesting.code_edit.text if not code_edit_requesting.code_edit.text.is_empty() else "using System;"
		if not use_code.contains("class "):
			use_code = "using System; public class Program { public static void Main() { %s }}" % use_code
		var public_methods_got = runtime_mono.runtime_call_static_method(dynamic_compiler_assembly, "CatacombCompiler", "Compiler", "GetPublicMethods", use_code)
		public_methods_got = str_to_var(public_methods_got)
		if public_methods_got != null:
			for i in public_methods_got:
				var new_method_info = RMethodInfo.new()
				new_method_info.set_method_info(i)
				methods_dictionary[new_method_info.method_name] = new_method_info
				if (not new_method_info.is_static_class) and (not new_method_info.method_class_name.is_empty()) and (not class_instances.has(new_method_info.method_class_name)):
					class_instances[new_method_info.method_class_name] = runtime_mono.create_class_instance(assemblycompiled, new_method_info.method_namespace_name, new_method_info.method_class_name)
				if pressed_desired == null:
					pressed_desired = new_method_info
					if code_edit_requesting.code_edit.text.contains("Console."):
						new_method_info.has_console_request = true
	finished_checking_for_methods.emit(is_instance_valid(pressed_desired))

var pressed_desired = null

signal finished_call(call_id:int)

func add_csharp_calls():
	if not ClassDB.class_exists(&"RuntimeMono"):
		return
	ClassDB.class_call_static_method(&"RuntimeMono",&"add_managed_callable","compilation_done", compilation_completed_from_csharp)

func compilation_completed_from_csharp(_param_info:String):
	compilation_finished_csharp.emit.call_deferred()

func recompile_threaded(started_compiling_time:float, code_to_compile:String):
	var use_code:String = code_to_compile if not code_to_compile.is_empty() else "using System;"
	if not use_code.contains("class "):
		use_code = "using System; public class Program { public static void Main() { %s }}" % use_code
	#var result_bytes =
	runtime_mono.runtime_call_static_method(dynamic_compiler_assembly, "CatacombCompiler", "Compiler", "CompileCodeAsync",use_code)

	await compilation_finished_csharp
	var result_bytes = runtime_mono.compile_string_get_assembly(dynamic_compiler_assembly, "CatacombCompiler", "Compiler", "RetrieveCompiled","")
	finished_recompile_threaded(started_compiling_time, result_bytes)

func finished_recompile_threaded(_started_compiling_time:float, resulting_bytes:PackedByteArray):
	if not resulting_bytes.is_empty():
		await reload_app_domain_stuff()
		await get_tree().process_frame
		assemblycompiled = runtime_mono.load_assembly(resulting_bytes, "AssemblyCompiled")
		clear_previous_methods_and_instances()
		recompile_finished.emit(is_instance_valid(pressed_desired))
	else:
		compilation_failed()
		recompile_finished.emit(false)

	is_compiling = false

func compilation_failed():
	if is_instance_valid(assemblycompiled):
		assemblycompiled.unreference()
	clear_previous_methods_and_instances()

func clear_previous_methods_and_instances():
	class_instances.clear()
	methods_dictionary.clear()

func reload_app_domain_stuff():
	if has_compiled_already:
		#print("unload dom")
		runtime_mono.unload_app_domain()
	await get_tree().process_frame
	#print("create domain")
	runtime_mono.create_app_domain()
	#print("created domain")
	await get_tree().process_frame
	dynamic_compiler_assembly = runtime_mono.load_assembly(dynamic_compiler_bytes, "CatacombEngine")
	await get_tree().process_frame
	runtime_mono.set_main_library(dynamic_compiler_assembly)
	runtime_mono.runtime_call_static_method_with_bytes(dynamic_compiler_assembly, "CatacombCompiler", "Compiler", "SetDynamicCompilerBytes", dynamic_compiler_bytes)
	has_compiled_already = true

func execute_method():

	if is_compiling or (not is_instance_valid(pressed_desired)) or (not is_instance_valid(assemblycompiled)) or (not is_instance_valid(runtime_mono)):
		push_error("Couldn't execute method, code isn't compiled.")
		return

	#prints("Execute method",pressed_desired.method_name,pressed_desired.method_class_name,pressed_desired.method_namespace_name, pressed_desired.has_console_request)
	if pressed_desired.has_console_request:
		ClassDB.class_call_static_method(&"RuntimeMono",&"create_console")
		for i in 2:
			await get_tree().process_frame

	if pressed_desired.is_static_method:
		runtime_mono.runtime_call_static_method(assemblycompiled, pressed_desired.method_namespace_name, pressed_desired.method_class_name, pressed_desired.method_name)
		return

	elif class_instances.has(pressed_desired.method_class_name) and is_instance_valid(class_instances[pressed_desired.method_class_name]):
		runtime_mono.runtime_call_method(class_instances[pressed_desired.method_class_name], pressed_desired.method_name)
		return

func connect_compile(sharp_code_edit):
	await  get_tree().process_frame
	if is_instance_valid(sharp_code_edit):
		sharp_code_edit.run_requested.connect(execute_method)
		sharp_code_edit.code_edit.compile_pressed.connect(request_compile.bind(sharp_code_edit))
		started_compiling.connect(sharp_code_edit.started_recompiled)
		finished_checking_for_methods.connect(sharp_code_edit.recompiled)
		(sharp_code_edit.code_edit as CodeEdit).focus_entered.connect(focused_code_editor.bind(sharp_code_edit.code_edit, true))
		(sharp_code_edit.code_edit as CodeEdit).focus_exited.connect(focused_code_editor.bind(sharp_code_edit.code_edit, false))

func focused_code_editor(_focusing:CodeEdit, _now_focused:bool = false):
	editor_focused = _now_focused
	if _now_focused:
		current_editor_focused = _focusing
	elif current_editor_focused == _focusing:
		current_editor_focused = null

var last_text_slide:String = ""
func create_ui_element(params, _text_line):
	var element = null
	match (params.type as String).to_upper():
		"VBOXCONTAINER","VBOX":
			element = VBoxContainer.new()
			active_container = element
		"HBOXCONTAINER","HBOX":
			element = HBoxContainer.new()
			active_container = element
		"QRCODE":
			print(&"set" in params)
			if &"set" in params and &"data" in params.set:
				element = QRCodeRect.new()
				element.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				element.custom_minimum_size = Vector2(150,150)
				(element as QRCodeRect).set_mode(QRCodeRect.QRCode.Mode.ALPHANUMERIC)
				(element as QRCodeRect).set_error_correction(QRCodeRect.QRCode.ErrorCorrection.MEDIUM)
				(element as QRCodeRect).data = (params.set.data)

		"CONSOLE":
			element = load("res://console_display.tscn").instantiate()
			has_current_fake_console = (element as ConsoleDisplay)
			active_label = element

		"CODEEDITOR","CODEEDIT","CODE":
			element = load("res://SharpCodeEditor.tscn").instantiate()
			var sharp_code_edit: = (element as SharpEditorPanel)
			connect_compile(sharp_code_edit)
			active_label = element

		"TEXTURERECT":
			element = TextureRect.new()

		"TOPTEXT","BOTTOMTEXT","RIGHTTEXT","LEFTTEXT", "WIKIRICHTEXTLABEL","TEXT","RICHTEXTLABEL":
			element = WikiRichTextLabel.new()
			element.bbcode_enabled = true
			(element as WikiRichTextLabel).fit_content = true
			var font_size:int = 36
			match params.type.to_upper():
				"RIGHTTEXT":
					add_element_to_slider_holder_holder(element, Vector4(0.5,0.05,0.95,0.95), Control.PRESET_RIGHT_WIDE)
				"LEFTTEXT":
					add_element_to_slider_holder_holder(element, Vector4(0.05,0.05,0.49,0.95), Control.PRESET_LEFT_WIDE)
				"TOPTEXT":
					add_element_to_slider_holder_holder(element, Vector4(0.05,0.05,0.95,0.18), Control.PRESET_TOP_WIDE)
					font_size = 46
				"BOTTOMTEXT":
					add_element_to_slider_holder_holder(element, Vector4(0.05,0.8,0.95,0.96), Control.PRESET_BOTTOM_WIDE)
					font_size = 44
			element.add_theme_constant_override("line_separation",10)
			element.set_meta("font_size", font_size)
			for i in ["bold_font_size", "bold_italics_font_size", "italics_font_size", "mono_font_size", "normal_font_size"]:
				element.add_theme_font_size_override(i, font_size)
			active_label = element

		"LEFTIMAGE":
			element = TextureRect.new()
			add_element_to_slider_holder_holder(element, Vector4(0.0,0.0,0.5,1.0), Control.PRESET_LEFT_WIDE)
			element.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			element.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			element.set_meta("insta_appear",true)

		"RIGHTIMAGE":
			element = TextureRect.new()
			add_element_to_slider_holder_holder(element, Vector4(0.5,0.0,1.0,1.0), Control.PRESET_RIGHT_WIDE)
			element.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			element.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			element.set_meta("insta_appear",true)

		"TEXTBIG":
			element = WikiRichTextLabel.new()
			element.bbcode_enabled = true
			(element as WikiRichTextLabel).fit_content = true

			var font_size:int = 120
			for i in ["bold_font_size", "bold_italics_font_size", "italics_font_size", "mono_font_size", "normal_font_size"]:
				element.add_theme_font_size_override(i, font_size)
			active_label = element

	if element == null:
		return
	#print (params)
	if &"name" in params:
		element.name = params.name
		ui_elements[params.name] = element

	if &"var" in params:
		if params.var.has("font_size") and (element is RichTextLabel):
			for i in ["bold_font_size", "bold_italics_font_size", "italics_font_size", "mono_font_size", "normal_font_size"]:
				element.add_theme_font_size_override(i, params.var.font_size)

	if &"parent" in params and ui_elements.has(params.parent):
		if (not element.has_meta(&"already_has_parent")) and not &"already_has_parent" in params:
			ui_elements[params.parent].add_child(element, true)
		if ui_elements[params.parent] is HBoxContainer and &"text" in element:
			(element).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif (not element.has_meta(&"already_has_parent")) and not &"already_has_parent" in params:
		if is_instance_valid(active_container) and active_container != element:
			active_container.add_child(element,true)
		else:
			slider_holder.add_child(element, true)


	if &"set" in params:
		for property in (params.set as Dictionary).keys():
			#prints(element,"has",property,"?", (property in element))
			if property in element:
				if not (element.get(property) is String) and params.set[property] is String:
					element.set(property, str_to_var(params.set[property]))
				else:
					element.set(property, params.set[property])
			elif property == &"font_size" and &"text" in element:
				for i in ["bold_font_size", "bold_italics_font_size", "italics_font_size", "mono_font_size", "normal_font_size"]:
					element.add_theme_font_size_override(i, str(params.set[property]).to_int())
			elif property == &"data" and element is TextureRect and ResourceLoader.exists(params.set.data):
				(element as TextureRect).texture = load(params.set.data)
			else:
				element.set_meta(property,params.set[property])

func add_element_to_slider_holder_holder(element:Control, anchors:Vector4, layout_preset:Control.LayoutPreset):
	%SliderHolderHolder.add_child(element)
	element.set_anchors_and_offsets_preset(layout_preset)
	element.anchor_left = anchors.x
	element.anchor_top = anchors.y
	element.anchor_right = anchors.z
	element.anchor_bottom = anchors.w
	element.set_meta(&"already_has_parent", %SliderHolderHolder)

func set_active_label(params):
	#print("Set active label [%s]" % params)
	if params in ui_elements.keys() and &"text" in ui_elements[params]:
		active_label = ui_elements[params]

var cached_edited_path:Dictionary = {}

func close_slide_editor():
	if not is_instance_valid(has_slide_editor):
		return
	if not has_slide_editor.currently_editing_path.is_empty():
		cached_edited_path[has_slide_editor.currently_editing_path] = has_slide_editor.code_edit.text

	clear_current_slide()
	show_slide(current_slide_index)
	has_slide_editor.queue_free()
	has_slide_editor = null
	#reveal_all_elements()
	animating=false
	for i in 30:
		await get_tree().process_frame
	animating=false

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:
				spin()
			KEY_F4:
				toggle_spin_code_editor()
			KEY_F1:
				if not is_instance_valid(has_slide_editor):
					has_slide_editor = load("res://slide_editor.tscn").instantiate()
					%Control.add_child(has_slide_editor)
					has_slide_editor.tree_exiting.connect(func(): has_slide_editor = null)
					has_slide_editor.open_file_path(last_parsed_slide_path, cached_edited_path)
				else:
					if not has_slide_editor.currently_editing_path.is_empty():
						cached_edited_path[has_slide_editor.currently_editing_path] = has_slide_editor.code_edit.text

					clear_current_slide()
					parse_slide_file(has_slide_editor.currently_editing_path)
					has_slide_editor.queue_free()
					has_slide_editor = null
			KEY_RIGHT:
				#prints("key right pressed",is_compiling,editor_focused,animating,revealed_elements,current_slide_elements.size())
				if not has_slide_editor:
					if revealed_elements >= current_slide_elements.size():
						animating = false
					if (not is_compiling) and (not editor_focused) and (not has_slide_editor):
						if revealed_elements < current_slide_elements.size():
							if is_instance_valid(current_slide_elements[revealed_elements]) and current_slide_elements[revealed_elements] is WikiRichTextLabel and current_slide_elements[revealed_elements].is_typing:
								var wrl:WikiRichTextLabel = current_slide_elements[revealed_elements]
								if wrl.is_waiting_for_next_step:
									wrl.is_waiting_for_next_step = false
									return
								else:
									current_slide_elements[revealed_elements].skip_typing()
							elif not animating:
								next_slide()
						elif not animating:
							next_slide()
			KEY_LEFT:
				if (not is_compiling) and (not editor_focused) and (not has_slide_editor):
					previous_slide()
			KEY_DOWN:
				if (not is_compiling) and (not editor_focused) and (not has_slide_editor):
					if revealed_elements == current_slide_elements.size():
						next_slide()
						await get_tree().process_frame
					for element in current_slide_elements:
						if element is WikiRichTextLabel and element.is_typing:
							element.skip_typing()
					reveal_all_elements()
			KEY_UP:
				if (not is_compiling) and (not editor_focused) and (not has_slide_editor):
					previous_slide()
					await get_tree().process_frame
					reveal_all_elements()
			KEY_ESCAPE:
				close_slide_editor()
				var current_focus_control = get_viewport().gui_get_focus_owner()
				if current_focus_control:
					current_focus_control.release_focus()
			KEY_ENTER,KEY_KP_ENTER:
				if event.is_pressed() and (event as InputEventWithModifiers).alt_pressed:
					swap_fullscreen_mode()
			KEY_C:
				if (not is_compiling) and (not editor_focused) and (not has_slide_editor):
					if event.is_pressed() and (event as InputEventWithModifiers).ctrl_pressed and not editor_focused:
						DisplayServer.clipboard_set(convert_slide_to_html(last_text_slide))

func swap_fullscreen_mode():
	if editor_focused and is_instance_valid(current_editor_focused):
		var codeedit = current_editor_focused
		codeedit = codeedit.find_parent("SharpEditorPanel*").get_parent()
		if codeedit.get_parent() == %Control and codeedit.has_meta("previous_parent"):
			%Control.remove_child(codeedit)
			codeedit.get_meta("previous_parent").add_child(codeedit)
			(codeedit.get_meta("previous_parent") as Node).move_child(codeedit,codeedit.get_meta("previndex"))
			codeedit.size = codeedit.get_meta("prevsize")
			codeedit.position = codeedit.get_meta("prevposition")
			var found_node = YEngine.find_node_with_type(codeedit,"CodeEdit")
			if is_instance_valid(found_node):
				found_node.grab_focus()
			return
		else:
			codeedit.set_meta("previous_parent",codeedit.get_parent())
			codeedit.set_meta("prevsize",codeedit.size)
			codeedit.set_meta("prevposition",codeedit.position)
			codeedit.set_meta("previndex",codeedit.get_index())
			codeedit.get_parent().remove_child(codeedit)
			%Control.add_child(codeedit)
			codeedit.size = %Control.size
			codeedit.position = %Control.position
			var found_node = YEngine.find_node_with_type(codeedit,"CodeEdit")
			if is_instance_valid(found_node):
				found_node.grab_focus()
			return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func next_slide():
	if is_instance_valid(current_typing_element) and current_typing_element.is_typing:
		current_typing_element.skip_typing()
	#prints("next slide pressed",is_compiling,editor_focused,animating,revealed_elements,current_slide_elements.size())
	await get_tree().process_frame
	if revealed_elements >= current_slide_elements.size():
		animating = false
	if is_compiling or editor_focused or animating:
		return
	#print("Next slide currennt revealed_elements %d size current slides %d revealing next %s"% [revealed_elements, current_slide_elements.size(), current_slide_elements[revealed_elements].name if revealed_elements < current_slide_elements.size() else "NONE"])
	if revealed_elements < current_slide_elements.size():
		reveal_element(revealed_elements)
	elif current_slide_index < slides.size() - 1:
		current_slide_index += 1
		show_slide(current_slide_index)
	for i in 2:
		await get_tree().process_frame
	#prints ("Animating",animating,"Revealed",revealed_elements,"Amount",current_slide_elements.size())
	if not animating and revealed_elements == 0 and current_slide_elements.size() > 0:
		reveal_element(0)

func previous_slide():
	if is_compiling or editor_focused:
		return
	if current_slide_index > 0:
		reveal_all_elements()
		await get_tree().process_frame
		visited_slides.erase(current_slide_index)
		current_slide_index -= 1
		show_slide(current_slide_index)
	else:
		visited_slides.erase(current_slide_index)
		await get_tree().process_frame
		await get_tree().process_frame
		show_slide(current_slide_index)

static func format_code_block(code: String, _language: String = "csharp") -> String:
	var formatted_code = code.strip_edges()
	formatted_code = formatted_code.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
	return '<pre class="line-numbers"><code class="language-csharp">%s</code></pre>\n<br>' % formatted_code

func convert_markdown_to_bbcode(text: String) -> String:
	var lines = text.split("\n")
	var command_lines = {}
	var code_blocks = {}
	var placeholder_prefix = "COMMANDPLACEHOLDER"
	var code_placeholder_prefix = "CODEPLACEHOLDER"
	var placeholder_count = 0
	var code_placeholder_count = 0
	var in_code_block = false
	var current_code_block = ""

	# Step 1 & 2: Identify and replace command lines and code blocks
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		if line.begins_with("=>"):
			var placeholder = placeholder_prefix + str(placeholder_count)
			command_lines[placeholder] = lines[i]
			lines[i] = placeholder
			placeholder_count += 1
			if line.to_upper().begins_with("=> NEW CODEEDIT") or line.to_upper().begins_with("=> CODE") or line.to_upper().begins_with("=> CONSOLE"):
				in_code_block = true
				current_code_block = ""
			else:
				if in_code_block:
					in_code_block = false
					var code_placeholder = code_placeholder_prefix + str(code_placeholder_count)
					code_blocks[code_placeholder] = current_code_block
					lines[i-1] = code_placeholder
					code_placeholder_count += 1
		elif in_code_block:
			current_code_block += lines[i] + "\n"
			lines[i] = ""
		elif line == "[[/]]" and in_code_block:
			in_code_block = false
			var code_placeholder = code_placeholder_prefix + str(code_placeholder_count)
			code_blocks[code_placeholder] = current_code_block
			lines[i] = code_placeholder
			code_placeholder_count += 1

	if in_code_block:
		in_code_block = false
		var code_placeholder = code_placeholder_prefix + str(code_placeholder_count)
		code_blocks[code_placeholder] = current_code_block
		lines.push_back(code_placeholder)
		code_placeholder_count += 1
	# Step 3: Join lines back into a single string
	text = "\n".join(lines)

	# Bold
	var bold_regex = RegEx.new()
	bold_regex.compile("\\*\\*(.+?)\\*\\*|__(.+?)__")
	var results = bold_regex.search_all(text)
	for result in results:
		var content = result.get_string(1) if result.get_string(1) else result.get_string(2)
		text = text.replace(result.get_string(), "[b]" + content + "[/b]")

	# Italic
	var italic_regex = RegEx.new()
	italic_regex.compile("\\*(.+?)\\*|_(.+?)_")
	results = italic_regex.search_all(text)
	for result in results:
		var content = result.get_string(1) if result.get_string(1) else result.get_string(2)
		text = text.replace(result.get_string(), "[i]" + content + "[/i]")

	# Strikethrough
	var colorful_regex = RegEx.new()
	colorful_regex.compile("\\^\\^(.+?)\\^\\^")
	results = colorful_regex.search_all(text)
	for result in results:
		text = text.replace(result.get_string(), "[color=468bbe]" + result.get_string(1) + "[/color]")


	var wave_regex = RegEx.new()
	wave_regex.compile("~\\^(.+?)\\^~")
	results = wave_regex.search_all(text)
	for result in results:
		text = text.replace(result.get_string(), "[wave]" + result.get_string(1) + "[/wave]")

	var strikethrough_regex = RegEx.new()
	strikethrough_regex.compile("~~(.+?)~~")
	results = strikethrough_regex.search_all(text)
	for result in results:
		text = text.replace(result.get_string(), "[s]" + result.get_string(1) + "[/s]")

	var table_regex = RegEx.new()
	table_regex.compile("\\|(.+)\\|\\n\\|[-:\\|\\s]+\\|\\n((\\|.+\\|\\n)+)")
	results = table_regex.search_all(text)
	for result in results:
		var header = result.get_string(1).strip_edges()
		var body = result.get_string(2)

		var columns = header.split("|", false)
		var num_columns = columns.size()

		var bbcode_table = "[table=%d]" % num_columns

		# Header row
		for cell in columns:
			bbcode_table += "[cell bg=2066b8][color=white][b]      %s      [/b][/color][/cell]" % cell.strip_edges()

		# Body rows
		var rows = body.split("\n", false)
		for i in range(rows.size()):
			var row = rows[i]
			var cells = row.split("|", false)
			var bg_color = "light_blue" if i % 2 == 0 else ""
			for cell in cells:
				bbcode_table += "[cell bg=%s]%s[/cell]" % [bg_color, cell.strip_edges()]

		bbcode_table += "[/table]"
		text = text.replace(result.get_string(), bbcode_table)
	text = text.replace("[/font[/i]size]","[/font_size]").replace("[font[i]size=","[font_size=")

	# Step 5: Replace placeholders with original command lines and code blocks
	lines = text.split("\n")
	for i in range(lines.size()):
		if lines[i].begins_with(placeholder_prefix):
			lines[i] = command_lines[lines[i]]
		elif lines[i].begins_with(code_placeholder_prefix):
			lines[i] = code_blocks[lines[i]]
	return "\n".join(lines)

static func convert_slide_to_html(slide_content: String) -> String:
	var html = ""
	var lines = slide_content.replace("|| ||","").split("\n")
	var in_list = false
	var list_type = ""
	var list_indent = 0
	var list_buffer = ""
	var _ordered_list_index = 0
	var in_code_block = false
	var code_buffer = ""
	var code_language = "csharp"

	for line in lines:
		var stripped_line = line.strip_edges()

		#prints("Stripped: [%s]" % stripped_line,stripped_line.begins_with("=> New CodeEdit"),"In code block? %s"%in_code_block,code_buffer)

		if in_code_block:
			if stripped_line == "[[/]]" or stripped_line.begins_with("=>"):
				html += format_code_block(code_buffer, code_language)
				in_code_block = false
				code_buffer = ""
				if stripped_line.begins_with("=>"):
					continue  # Skip command line processing
			else:
				code_buffer += line + "\n"
				continue
		if stripped_line.begins_with("[[code:"):
			in_code_block = true
			code_language = stripped_line.split(":")[1].trim_suffix("]]")
			continue

		if stripped_line.to_upper().begins_with("=> NEW CODEEDIT") or stripped_line.to_upper().begins_with("=> CODE"):
			if in_code_block:
				html += format_code_block(code_buffer, code_language)
				in_code_block = false
			in_code_block = true
			code_language = "csharp"
			if in_list:
				html += html_finish_list(list_type, list_buffer)
				in_list = false
				list_buffer = ""
			html += "<br>\n"
			continue

		if stripped_line.is_empty():
			if in_list:
				html += html_finish_list(list_type, list_buffer)
				in_list = false
				list_buffer = ""
			html += "<br>\n"
			continue
		if stripped_line.begins_with("=>") or stripped_line.begins_with("//"):
			if in_code_block:
				html += format_code_block(code_buffer, code_language)
				in_code_block = false
			if in_list:
				html += html_finish_list(list_type, list_buffer)
				in_list = false
				list_buffer = ""
			continue

		if stripped_line.begins_with("- ") or stripped_line.begins_with("* "):
			if in_code_block:
				html += format_code_block(code_buffer, code_language)
				in_code_block = false
			if not in_list or list_type != "ul":
				if in_list:
					html += html_finish_list(list_type, list_buffer)
				in_list = true
				list_type = "ul"
				list_buffer = ""
			var indent = line.length() - line.strip_edges(true, false).length()
			list_buffer += handle_list_item(stripped_line.substr(2), indent, list_indent, list_type)
			list_indent = indent
		elif stripped_line.match("^\\d+\\.\\s.*"):
			if in_list and list_type == "ul":
				html += html_finish_list(list_type, list_buffer)
				in_list = false
				list_buffer = ""
			if not in_list:
				html += "<ol>\n"
				in_list = true
				list_type = "ol"
			_ordered_list_index += 1
			html += "<li>" + convert_bbcode_to_html(stripped_line.split(".", true, 1)[1].strip_edges()) + "</li>\n"
		else:
			if in_list:
				html += html_finish_list(list_type, list_buffer)
				in_list = false
				list_buffer = ""
				list_indent = 0
			if in_code_block:
				html += format_code_block(code_buffer, code_language)
				in_code_block = false
			if stripped_line.begins_with("# "):
				html += "<h2><span style=\"color: #2066b8;\">" + convert_bbcode_to_html(stripped_line.substr(2)) + "</span></h2>\n"
			elif stripped_line.begins_with("## "):
				html += "<h3><span style=\"color: #2066b8;\">" + convert_bbcode_to_html(stripped_line.substr(3)) + "</span></h3>\n"
			else:
				html += convert_bbcode_to_html(stripped_line) + "<br>\n"

	if in_list:
		html += html_finish_list(list_type, list_buffer)
		in_list = false

	if in_code_block:
		html += format_code_block(code_buffer, code_language)
		in_code_block = false

	html += "</div>\n"
	return html

static func handle_list_item(item: String, indent: int, prev_indent: int, list_type: String, index: int = 0) -> String:
	var result = ""
	#if indent > prev_indent:
		#result += "<li><" + list_type + ">\n"
	#el
	if indent < prev_indent:
		result += "</" + list_type + "></li>\n"
	elif indent == prev_indent and prev_indent > 0:
		result += "</li>\n"

	if list_type == "ol":
		result += "<li value='" + str(index) + "'>"
	else:
		result += "<li>"
	#print("result [%s] item [%s] prev_indent [%d] indent [%d]" % [result, item, prev_indent,indent])
	result += convert_bbcode_to_html(item)

	if indent == 0:
		result += "</li>\n"

	return result

static func html_finish_list(list_type: String, list_buffer: String) -> String:
	var closing_tags = ""
	var indent_level = 0
	#print("Finishing html list %s buffer [%s] indent level %d" % [list_type,list_buffer,indent_level])
	for _char in list_buffer:
		if _char == '<' and list_buffer.substr(list_buffer.find(_char) + 1, 2) == list_type:
			indent_level += 1
		elif _char == '<' and list_buffer.substr(list_buffer.find(_char) + 1, 3) == "/" + list_type:
			indent_level -= 1
	for i in range(max(indent_level,1)):
		closing_tags += "</li></" + list_type + ">"

	return "<" + list_type + ">\n" + list_buffer + closing_tags + "\n"

static func convert_bbcode_to_html(text: String) -> String:
	#print(text)
	# Convert basic BBCode to HTML
	text = text.replace("[b]", "<strong>").replace("[/b]", "</strong>")
	text = text.replace("[i]", "<em>").replace("[/i]", "</em>")
	text = text.replace("[u]", "<u>").replace("[/u]", "</u>")
	text = text.replace("[center]", "<div style='text-align: center;'>").replace("[/center]", "</div>")
	text = text.replace("[right]", "<div style='text-align: right;'>").replace("[/right]", "</div>")

	# Convert color BBCode
	var color_regex = RegEx.new()
	color_regex.compile("\\[color=(#?\\w+)\\](.*?)\\[/color\\]")
	var results = color_regex.search_all(text)
	for result in results:
		var color = result.get_string(1)
		var content = result.get_string(2)
		text = text.replace(result.get_string(), "<span style='color: " + color + ";'>" + content + "</span>")

	# Convert font size BBCode
	var size_regex = RegEx.new()
	size_regex.compile("\\[font_size=(\\d+)\\](.*?)\\[/font_size\\]")
	results = size_regex.search_all(text)
	for result in results:
		var size = result.get_string(1)
		var content = result.get_string(2)
		text = text.replace(result.get_string(), "<span style='font-size: " + size + "px;'>" + content + "</span>")

	# Convert table BBCode
	var table_regex = RegEx.new()
	table_regex.compile("\\[table=(\\d+)\\](.*?)\\[/table\\]")
	results = table_regex.search_all(text)
	for result in results:
		var columns = result.get_string(1)
		var table_content = result.get_string(2)
		var html_table = "<table style='width:100%; border-collapse: collapse;'>"

		var cells = table_content.split("[cell")
		cells.remove_at(0)  # Remove empty first element

		for i in range(cells.size()):
			if i % int(columns) == 0:
				if i != 0:
					html_table += "</tr>"
				html_table += "<tr>"

			var cell = cells[i]
			var bg_match = RegEx.new()
			bg_match.compile("bg=(\\w+)\\]")
			var bg_result = bg_match.search(cell)
			var bg_color = bg_result.get_string(1) if bg_result else ""

			var cell_content = cell.split("]", true, 1)[1].trim_suffix("[/cell")
			var style = "" if bg_color.is_empty() else " style='background-color:#%s;'" % bg_color
			if style.contains("##"):
				style = style.replace("##","#")
			html_table += "<td%s>%s</td>" % [style,cell_content.replace("[/cell]","")]

		html_table += "</tr></table>"
		text = text.replace(result.get_string(), html_table)

	return text
