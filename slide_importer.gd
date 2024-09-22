class_name SlideImporter
extends CanvasLayer

@onready var editor_menu_buttons = %EditorMenuButtons
@onready var code_edit = %LeftCodeEdit
@onready var file_dialog:FileDialog = %FileDialog

var opening_folder:bool = false
# Called when the node enters the scene tree for the first time.
func _ready():
	var menubutton:MenuButton = %EditorMenuButtons
	var popupmenu:PopupMenu = menubutton.get_popup()
	popupmenu.add_icon_item(load("res://addons/cider_wiki/icons/icon_create_sub.svg"),"Export")
	popupmenu.add_icon_item(load("res://addons/cider_wiki/icons/icon_create_sub.svg"),"Export to html")
	popupmenu.add_icon_item(load("res://addons/cider_wiki/icons/icon_save.svg"),"Import")
	popupmenu.add_item("Load Slide Folder")
	popupmenu.add_item("Back to slides")
	popupmenu.index_pressed.connect(file_menu_index_pressed.bind(popupmenu))

	var syntax_highlighter: = CodeHighlighter.new()
	# BBCode tags
	syntax_highlighter.add_color_region("[", "]", Color.DEEP_SKY_BLUE)
	# => commands
	syntax_highlighter.add_color_region("=>"," ",Color.DARK_SALMON,false)
	# One-line comments
	syntax_highlighter.add_color_region("//", "", Color.DIM_GRAY, true)
	syntax_highlighter.add_color_region("**", "**", Color.AQUA)
	# Specific BBCode tags
	var bbcode_keywords = ["b", "i", "u", "s", "center", "right", "table", "cell"]
	for keyword in bbcode_keywords:
		syntax_highlighter.add_keyword_color(keyword, Color.MEDIUM_SLATE_BLUE)
	# Color names
	var color_keywords = ["white", "black", "red", "green", "blue", "yellow", "web_gray", "light_blue"]
	for color in color_keywords:
		syntax_highlighter.add_keyword_color(color, Color.CORNSILK)
	# Numbers
	syntax_highlighter.number_color = Color.DEEP_SKY_BLUE
	syntax_highlighter.symbol_color = Color.YELLOW_GREEN
	syntax_highlighter.function_color = Color.CORNFLOWER_BLUE
	syntax_highlighter.member_variable_color = Color.AQUAMARINE
	# Function calls (for potential future use)
	code_edit.syntax_highlighter = syntax_highlighter

	file_dialog = FileDialog.new()
	add_child(file_dialog)

	# Configure the FileDialog
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.use_native_dialog = true
	#file_dialog.add_filter("*.txt ; Text files")

	# Connect the file_selected signal to our callback function
	file_dialog.files_selected.connect(_on_file_selected)
	file_dialog.dir_selected.connect(_on_folder_selected)

func save_slides():
	var slide_text = code_edit.text
	var initial_slide_lines = slide_text.split("\n",true)
	for i in initial_slide_lines.size():
		if initial_slide_lines[i].begins_with("======="):
			var split_thing = initial_slide_lines[i].split(" ",false,1)
			if split_thing.size()>1:
				initial_slide_lines[i] = "=========================== %s" % split_thing[1]

	slide_text = "\n".join(initial_slide_lines)

	var slides = slide_text.split("===========================")
	var slide_number = 0

	for slide:String in slides:
		if slide.strip_edges().is_empty():
			continue

		var lines = slide.split("\n")
		var title = lines[0].strip_edges()

		if title.is_empty():
			continue
		lines.remove_at(0)
		slide = "\n".join(lines)

		var processed_slide = replace_spaces_with_tabs(slide)
		var file_name = "%02d_%s.txt" % [slide_number, title.to_lower().to_snake_case().validate_filename()]
		var file_path = currently_editing_path.path_join(file_name)
		print("Saving %s" % file_path)
		if not DirAccess.dir_exists_absolute(file_path.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		file.store_string(processed_slide.strip_edges())
		file.close()

		print("Saved slide: " + file_name)
		slide_number += 1

func _on_folder_selected(path: String):
	currently_editing_path = path
	# This function will be called when a file is selected for saving
	print("Selected path for saving: ", path)
	if opening_folder:
		SlideManager.slidesdirabsolute = path+"\\"
		get_tree().change_scene_to_file("res://main.tscn")
	else:
		save_slides()

func _on_file_selected(path: String):
	currently_editing_path = path
	# This function will be called when a file is selected for saving
	print("Selected path for saving: ", path)
	# Here you can implement your file saving logic
	#if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		#DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	#if FileAccess.file_exists(path):
		#DirAccess.remove_absolute(path)
	#var file = FileAccess.open(path,FileAccess.WRITE_READ)
	#file.store_string(code_edit.text)

var currently_editing_path = ""
func open_save_dialog():
	if file_dialog.visible:
		return
	# Set the initial directory and file name
	if currently_editing_path.is_empty():
		file_dialog.current_dir = OS.get_executable_path().get_base_dir()
		file_dialog.current_file = "new_slide.txt"
		file_dialog.current_path = file_dialog.current_dir
	else:
		print(currently_editing_path.get_base_dir())
		print(currently_editing_path.get_basename())
		file_dialog.current_dir = currently_editing_path.get_base_dir()
		file_dialog.current_file = currently_editing_path.get_basename()
	# Show the dialog
	file_dialog.popup_centered_ratio(0.7)

func file_menu_index_pressed(index: int,popup:PopupMenu):
	var pressed :String = popup.get_item_text(index)
	#print (pressed)
	if pressed == "New":
		code_edit.text = ""
	elif pressed == "Import":
		opening_folder = false
		open_save_dialog()
	elif pressed == "Load Slide Folder":
		opening_folder = true
		open_save_dialog()
	elif pressed == "Back to slides":
		get_tree().change_scene_to_file("res://main.tscn")
	elif pressed == "Export":
		code_edit.text = ""
		for slide_path:String in SlideManager.slides:
			var slide_name :String = slide_path.get_basename().get_file().split("_",false,1)[1].capitalize().replace("_"," ")
			code_edit.text += "=========================== %s\n" % slide_name
			code_edit.text += FileAccess.open(slide_path,FileAccess.READ).get_as_text()
			code_edit.text += "\n"

	elif pressed == "Export to html":
		code_edit.text = ""
		for slide_path:String in SlideManager.slides:
			var slide_name :String = slide_path.get_basename().get_file().split("_",false,1)[1].capitalize().replace("_"," ")
			code_edit.text += "=========================== %s\n" % slide_name
			code_edit.text += SlideManager.convert_slide_to_html(FileAccess.open(slide_path,FileAccess.READ).get_as_text())
			code_edit.text += "\n"



func replace_spaces_with_tabs(text: String) -> String:
	var lines = text.split("\n")
	var processed_lines = []

	for line in lines:
		var space_count = 0
		for char in line:
			if char == ' ':
				space_count += 1
			else:
				break

		var tab_count = space_count / 4  # Assuming 4 spaces per tab
		var processed_line = "\t".repeat(tab_count) + line.strip_edges()
		processed_lines.append(processed_line)

	return "\n".join(processed_lines)
