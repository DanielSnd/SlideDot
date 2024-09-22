class_name QuizConverterUI
extends CanvasLayer

@onready var question_parser = %QuestionParser
@onready var editor_menu_buttons = %EditorMenuButtons
@onready var help_button = %HelpButton
@onready var left_code_edit = %LeftCodeEdit
@onready var right_code_edit = %RightCodeEdit
@onready var markup_help = %MarkupHelp
@onready var markup_help_text = %MarkupHelpText
@onready var file_dialog = %FileDialog
@onready var convert_button = %Convert

func _ready():
	var menubutton:MenuButton = %EditorMenuButtons
	var popupmenu:PopupMenu = menubutton.get_popup()
	popupmenu.add_icon_item(load("res://addons/cider_wiki/icons/icon_create.svg"),"New")
	popupmenu.add_icon_item(load("res://addons/cider_wiki/icons/icon_save.svg"),"Save")
	popupmenu.add_item("Back to slides")
	popupmenu.add_item("Copy Examples")

	setup_markup_highlighting(left_code_edit)
	setup_csv_highlighting(right_code_edit)

	for i in popup_buttons_to_have:
		popupmenu.add_item(i)

	popupmenu.index_pressed.connect(file_menu_index_pressed.bind(popupmenu))
	convert_button.pressed.connect(on_convert_pressed)
	help_button.pressed.connect(on_help_button_pressed)
	markup_help.close_requested.connect(on_markup_help_close_requested)

func setup_markup_highlighting(code_edit: CodeEdit):
	var syntax = code_edit.syntax_highlighter as CodeHighlighter
	if not syntax:
		syntax = CodeHighlighter.new()
		code_edit.syntax_highlighter = syntax

	# Question type
	syntax.add_keyword_color("WR", Color.LIGHT_BLUE)
	syntax.add_keyword_color("SA", Color.LIGHT_GREEN)
	syntax.add_keyword_color("M", Color.LIGHT_CORAL)
	syntax.add_keyword_color("MC", Color.LIGHT_SALMON)
	syntax.add_keyword_color("TF", Color.LIGHT_YELLOW)
	syntax.add_keyword_color("MS", Color.LIGHT_PINK)
	syntax.add_keyword_color("O", Color.LIGHT_CYAN)

	# Metadata
	syntax.add_keyword_color("Points:", Color.ORANGE)
	syntax.add_keyword_color("Difficulty:", Color.ORANGE)
	syntax.add_keyword_color("Image:", Color.ORANGE)
	syntax.add_keyword_color("Feedback:", Color.ORANGE)
	syntax.add_keyword_color("Scoring:", Color.ORANGE)
	syntax.add_keyword_color("Input Box:", Color.ORANGE)
	syntax.add_keyword_color("Initial Text:", Color.ORANGE)
	syntax.add_keyword_color("Answer Key:", Color.ORANGE)

	# Hints
	syntax.add_color_region("{{", "}}", Color.YELLOW)
	syntax.add_color_region("||", "", Color.DIM_GRAY, true)

	# Correct answers and separators
	syntax.add_keyword_color("*", Color.GREEN)
	syntax.add_keyword_color("=>", Color.MAGENTA)
	syntax.add_keyword_color("||", Color.MAGENTA)

	# Question separator
	syntax.add_keyword_color("---", Color.GRAY)

func setup_csv_highlighting(code_edit: CodeEdit):
	var syntax = code_edit.syntax_highlighter as CodeHighlighter
	if not syntax:
		syntax = CodeHighlighter.new()
		code_edit.syntax_highlighter = syntax

	# CSV field types
	syntax.add_keyword_color("NewQuestion", Color.LIGHT_BLUE)
	syntax.add_keyword_color("Title", Color.LIGHT_GREEN)
	syntax.add_keyword_color("QuestionText", Color.LIGHT_CORAL)
	syntax.add_keyword_color("Points", Color.LIGHT_SALMON)
	syntax.add_keyword_color("Difficulty", Color.LIGHT_YELLOW)
	syntax.add_keyword_color("Image", Color.LIGHT_PINK)
	syntax.add_keyword_color("Feedback", Color.LIGHT_CYAN)
	syntax.add_keyword_color("Hint", Color.YELLOW)
	syntax.add_keyword_color("Option", Color.GREEN)
	syntax.add_keyword_color("Answer", Color.GREEN)
	syntax.add_keyword_color("Choice", Color.MAGENTA)
	syntax.add_keyword_color("Match", Color.MAGENTA)
	syntax.add_keyword_color("Item", Color.ORANGE)

	# Quotation marks for field values
	syntax.add_color_region('"', '"', Color.LIGHT_GOLDENROD, false)

	# Commas separating fields
	syntax.add_keyword_color(",", Color.GRAY)

func on_markup_help_close_requested():
	markup_help.hide()

func on_help_button_pressed():
	markup_help.show()

func on_convert_pressed():
	right_code_edit.text = question_parser.parse_questions(left_code_edit.text)

var popup_buttons_to_have:PackedStringArray = [
		"Add Multiple Choice Question", "Add Short Answer Question", "Add True/False Question", "Add Matching Question", "Add Written Response Question", "Add Multi-Select Question", "Add Ordering Question"]
func file_menu_index_pressed(index: int,popup:PopupMenu):
	var pressed :String = popup.get_item_text(index)
	var question_template = ""

	if pressed == "Copy Examples":
		DisplayServer.clipboard_set(markup_help_text.text)

	if pressed == "Back to slides":
		get_tree().change_scene_to_file("res://main.tscn")
		return

	match pressed:
		"Add Multiple Choice Question":
			question_template = """MC Your question here? {{Hint: Optional hint}}
*Correct answer || Feedback for correct answer
Incorrect answer 1 || Feedback for incorrect answer 1
Incorrect answer 2 || Feedback for incorrect answer 2
Incorrect answer 3 || Feedback for incorrect answer 3
---
"""
		"Add Short Answer Question":
			question_template = """SA Your question here? {{Hint: Optional hint}}
Input: 1,20
*Correct answer
Partially correct answer
---
"""
		"Add True/False Question":
			question_template = """TF Your statement here. {{Hint: Optional hint}}
*True || Feedback for True
False || Feedback for False
---
"""
		"Add Matching Question":
			question_template = """M Your matching question here. {{Hint: Optional hint}}
Item 1 => Match 1
Item 2 => Match 2
Item 3 => Match 3
---
"""
		"Add Written Response Question":
			question_template = """WR Your question here? {{Hint: Optional hint}}
Initial: Initial text for the answer box...
Answer: Model answer or key points to look for.
---
"""
		"Add Multi-Select Question":
			question_template = """MS Your multi-select question here? {{Hint: Optional hint}}
*Correct option 1 || Feedback for correct option 1
*Correct option 2 || Feedback for correct option 2
Incorrect option || Feedback for incorrect option
*Correct option 3 || Feedback for correct option 3
---
"""
		"Add Ordering Question":
			question_template = """
O Your ordering question here. {{Hint: Optional hint}}
First item || Feedback for first item
Second item || Feedback for second item
Third item || Feedback for third item
Fourth item || Feedback for fourth item
---
"""

	if question_template:
		if left_code_edit.has_focus():
			var cursor_pos = left_code_edit.get_caret_column()
			var line = left_code_edit.get_caret_line()
			var text = left_code_edit.get_line(line)
			var new_text = text.substr(0, cursor_pos) + question_template + text.substr(cursor_pos)
			left_code_edit.set_line(line, new_text)
			left_code_edit.set_caret_line(line + question_template.count("\n") + 1)
		else:
			left_code_edit.text += "\n" + question_template
			left_code_edit.set_caret_line(left_code_edit.get_line_count() - 1)
