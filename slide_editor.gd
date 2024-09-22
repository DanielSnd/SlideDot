extends VBoxContainer
class_name SlideEditor

@onready var code_edit = %CodeEdit

var file_dialog: FileDialog

var currently_editing_path:String = ""
# Called when the node enters the scene tree for the first time.

func _ready():
	var menubutton:MenuButton = %EditorMenuButtons
	var popupmenu:PopupMenu = menubutton.get_popup()
	popupmenu.add_icon_item(load("res://addons/cider_wiki/icons/icon_create.svg"),"New")
	popupmenu.add_icon_item(load("res://addons/cider_wiki/icons/icon_save.svg"),"Save")
	popupmenu.add_icon_item(load("res://addons/cider_wiki/icons/icon_save.svg"),"Save as")
	popupmenu.add_item("Quiz Maker")
	popupmenu.add_item("Slide Importer")
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
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.use_native_dialog = true
	file_dialog.add_filter("*.txt ; Text files")

	# Connect the file_selected signal to our callback function
	file_dialog.files_selected.connect(_on_file_selected)

func open_save_dialog():
	if file_dialog.visible:
		return
	# Set the initial directory and file name
	if currently_editing_path.is_empty():
		file_dialog.current_dir = OS.get_executable_path().get_base_dir()
		file_dialog.current_file = "new_slide.txt"
		file_dialog.current_path = file_dialog.current_dir.path_join(file_dialog.current_file)
	else:
		#print(currently_editing_path.get_base_dir())
		#print(currently_editing_path.get_basename())
		file_dialog.current_dir = currently_editing_path.get_base_dir()
		file_dialog.current_file = currently_editing_path.get_basename()
		file_dialog.current_path = currently_editing_path
	# Show the dialog
	file_dialog.popup_centered_ratio(0.7)

func _on_file_selected(path: String):
	# This function will be called when a file is selected for saving
	print("Selected path for saving: ", path)
	currently_editing_path = path
	ref_to_cached_edited_path[path] = code_edit.text
	# Here you can implement your file saving logic
	if not DirAccess.dir_exists_absolute(currently_editing_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(currently_editing_path.get_base_dir())
	if FileAccess.file_exists(currently_editing_path):
		DirAccess.remove_absolute(currently_editing_path)
	var file = FileAccess.open(currently_editing_path,FileAccess.WRITE_READ)
	file.store_string(code_edit.text)

# Call this function when you want to open the save dialog
# For example, you might call this when a "Save" button is pressed
func _on_save_button_pressed():
	open_save_dialog()

var ref_to_cached_edited_path:Dictionary = {}
func open_file_path(file_path:String, cached_edited_path:Dictionary):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	ref_to_cached_edited_path = cached_edited_path
	currently_editing_path = file_path
	if cached_edited_path.has(file_path):
		code_edit.text = cached_edited_path[file_path]
	else:
		code_edit.text = file.get_as_text()

func file_menu_index_pressed(index: int,popup:PopupMenu):
	var pressed :String = popup.get_item_text(index)
	#print (pressed)
	if pressed == "New":
		code_edit.text = ""
		currently_editing_path = ""
	elif pressed == "Save":
		if not DirAccess.dir_exists_absolute(currently_editing_path.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(currently_editing_path.get_base_dir())
		if FileAccess.file_exists(currently_editing_path):
			DirAccess.remove_absolute(currently_editing_path)
		var file = FileAccess.open(currently_editing_path,FileAccess.WRITE_READ)
		file.store_string(code_edit.text)
		print("Saved at ",currently_editing_path)
	elif pressed == "Save as":
		open_save_dialog()
	elif pressed == "Quiz Maker":
		get_tree().change_scene_to_file("res://quiz_converter.tscn")
	elif pressed == "Slide Importer":
		get_tree().change_scene_to_file("res://slide_importer.tscn")

		#if currently_editing_path.is_empty():
			#push_error("PATH NOT FOUND!")
		#else:
			#if not DirAccess.dir_exists_absolute(currently_editing_path.get_base_dir()):
				#DirAccess.make_dir_recursive_absolute(currently_editing_path.get_base_dir())
			#if FileAccess.file_exists(currently_editing_path):
				#DirAccess.remove_absolute(currently_editing_path)
			#var file = FileAccess.open(currently_editing_path,FileAccess.WRITE_READ)
			#file.store_string(code_edit.text)
