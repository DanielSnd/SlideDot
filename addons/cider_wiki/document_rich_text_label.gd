@tool
class_name WikiRichTextLabel
extends RichTextLabel

const WikiTab = preload("wiki_tab.gd")

var wiki_tab: WikiTab

var _highlight_line: int
var _highlight_t: float = 1.0: set = _set_highlight_t

var _syntax_highlighters: Dictionary = {}
var _code_blocks := []

var meta_label_container: PanelContainer = null
var meta_label: Label = null

signal spoke(letter: String, letter_index: int, speed: float)
signal finished_typing()

var is_typing: bool = false
var is_waiting_for_next_step:bool = false
var characters_per_second: float = 50.0  # New variable to control typing speed
var skip_action: String = "ui_cancel"

var _waiting_seconds: float = 0
var _original_text: String = ""

func _ready() -> void:
	visible_characters_behavior = TextServer.VisibleCharactersBehavior.VC_CHARS_AFTER_SHAPING
	if Engine.is_editor_hint() and Engine.get_singleton("EditorInterface").get_edited_scene_root() and Engine.get_singleton("EditorInterface").get_edited_scene_root().is_ancestor_of(self):
		var gdscript_highlighter := preload("highlighters/gdscript_highlighter.tres").duplicate(true)
		_syntax_highlighters["gdscript"] = gdscript_highlighter
		return

	if get_child_count() > 1:
		meta_label_container = $MetaLabelContainer
		meta_label = $MetaLabelContainer/MetaLabel
	get_v_scroll_bar().value_changed.connect(_on_v_scroll_bar_value_changed)

	if meta_label_container != null:
		meta_label_container.add_theme_stylebox_override("panel", get_theme_stylebox("PanelForeground", "EditorStyles"))
	var type_color: Color = Color.SKY_BLUE
	var usertype_color:Color = Color.DARK_CYAN

	if (Engine.is_editor_hint()) and Engine.has_singleton("EditorInterface") and is_instance_valid(Engine.get_singleton("EditorInterface")) and Engine.get_singleton("EditorInterface").has_method("get_editor_settings") and is_instance_valid(Engine.get_singleton("EditorInterface").get_editor_settings()):
		type_color = Engine.get_singleton("EditorInterface").get_editor_settings()["text_editor/theme/highlighting/engine_type_color"]
		usertype_color = Engine.get_singleton("EditorInterface").get_editor_settings()["text_editor/theme/highlighting/user_type_color"]

	var gdscript_highlighter := preload("highlighters/gdscript_highlighter.tres").duplicate(true)
	gdscript_highlighter.clear_keyword_colors()
#
	## Engine types
	#var types := ClassDB.get_class_list()
	#for t: String in types:
		#gdscript_highlighter.add_keyword_color(t, type_color)
#
	## User types
	#var global_classes := ProjectSettings.get_global_class_list()
	#for d: Dictionary in global_classes:
		#gdscript_highlighter.add_keyword_color(d.class, usertype_color)
#
	## Autoloads
	#var autoloads := ProjectSettings.get_property_list().filter(func (x): return x.name.begins_with("autoload/"))
	#for p: Dictionary in autoloads:
		#if ProjectSettings.get_setting(p.name).begins_with("*"):
			#gdscript_highlighter.add_keyword_color((p.name as String).trim_prefix("autoload/"), usertype_color)

	_syntax_highlighters["gd"] = gdscript_highlighter
	_syntax_highlighters["gdscript"] = gdscript_highlighter

	var color_keyword:Color = Color("68abef",1.0)
	var syntax_highlighter = gdscript_highlighter
	(syntax_highlighter as CodeHighlighter).clear_color_regions()
	(syntax_highlighter as CodeHighlighter).add_color_region("\"", "\"", Color("c6a859"))
	(syntax_highlighter as CodeHighlighter).add_color_region("//", "", Color(0.55,0.55,0.55), true)
	(syntax_highlighter as CodeHighlighter).add_keyword_color("int ",Color(0.7,0.4,0.4))
	(syntax_highlighter as CodeHighlighter).add_keyword_color("string ",Color(0.7,0.4,0.4))
	syntax_highlighter.add_keyword_color("abstract ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("as ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("base ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("bool ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("break ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("byte ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("case ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("catch ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("char ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("checked ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("class ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("const ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("continue ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("decimal ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("default ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("delegate ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("do ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("double ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("else ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("enum ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("event ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("explicit ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("extern ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("false ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("finally ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("fixed ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("float ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("for ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("foreach ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("goto ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("f ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("mplicit ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("n ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nt ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nterface ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nternal ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("s ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("lock ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("long ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("namespace ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("new ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("null ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("object ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("operator ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("out ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("override ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("params ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("private ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("protected ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("public ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("readonly ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ref ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("return ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("sbyte ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("sealed ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("short ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("sizeof ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("stackalloc ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("static ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("string ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("struct ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("switch ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("his ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("hrow ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("rue ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ry ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ypeof ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("uint ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ulong ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("unchecked ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("unsafe ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ushort ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("using ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("virtual ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("void ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("volatile ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("while ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("add ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("alias ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("ascending ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("async ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("await ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("by ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("descending ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("dynamic ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("equals ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("from ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("get ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("global ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("group ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nto ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("join ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("let ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("nameof ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("on ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("orderby ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("partial ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("remove ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("select ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("set ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("value ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("var ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("when ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("where ", Color(color_keyword))
	syntax_highlighter.add_keyword_color("yield ", Color(color_keyword))


func _draw() -> void:
	if _highlight_t == 1.0:
		return
	var accent_color := get_theme_color("accent_color", "Editor")
	var highlight_rect := _get_line_rect(_highlight_line)
	var alpha := clampf(remap(_highlight_t, 0.5, 1.0, 1.0, 0.0), 0.0, 1.0)
	draw_rect(highlight_rect, accent_color * Color(1, 1, 1, 0.33 * alpha), false, 2.0)
	draw_rect(highlight_rect, accent_color * Color(1, 1, 1, 0.17 * alpha), true)

func set_page(page: WikiTab.Page, page_text: String) -> void:
	text = ""
	for c in _code_blocks:
		if c.code_edit:
			c.code_edit.queue_free()
	var res := enhance_bbcode(page_text, page)
	var enhanced_bbcode: String = res[0]
	_code_blocks = res[1]
	text = enhanced_bbcode
	var text_sans_bbcode = get_parsed_text()
	stop_indexes.clear()
	#print(text_sans_bbcode)
	var pipe_index :int = text_sans_bbcode.findn("|| ||")
	#print("[%d] pipe index " % pipe_index, text_sans_bbcode.contains("|| ||"))
	while pipe_index != -1:
		stop_indexes.push_back(pipe_index)
		var new_compiled = text_sans_bbcode.substr(0, pipe_index) + text_sans_bbcode.substr(pipe_index + 5)
		text_sans_bbcode = new_compiled
		pipe_index = text_sans_bbcode.findn("|| ||", pipe_index)
	#print(stop_indexes)
	#print(text_sans_bbcode)
	text = text.replace("|| ||","")
	#print("Text after ",text)
	_update_code_blocks(true)

func highlight_line(line: int) -> void:
	_highlight_line = line
	_highlight_t = 0
	create_tween().tween_property(self, "_highlight_t", 1.0, 1.0)
	get_v_scroll_bar().value += _get_line_rect(_highlight_line).get_center().y - size.y / 2.0

var stop_indexes := []

func enhance_bbcode(page_text: String, page: WikiTab.Page = null) -> Array:
	var compiled := ""
	var code_snippets := []
	var i: int = 0
	while i < page_text.length():
		var j := page_text.find("[[", i)
		if j == -1:
			compiled += page_text.substr(i)
			break

		var k := page_text.find("]]", j + 2)
		if k == -1:
			compiled += page_text.substr(i)
			break

		compiled += page_text.substr(i, j - i)

		var tag_text := page_text.substr(j + 2, k - (j + 2))
		if tag_text.begins_with("img:") and is_instance_valid(page):
			tag_text = tag_text.trim_prefix("img:")
			compiled += "[img]%s[/img]" % [str(page.images).path_join(tag_text)]
		elif tag_text.begins_with("code:"):
			var l := page_text.find("[[/]]", k + 2)
			if l == -1:
				l = page_text.length()
			var snippet_text := page_text.substr(k + 2, l - (k + 2)).trim_prefix("\n").trim_suffix("\n")
			var code_edit := CodeEdit.new()
			code_edit.editable = false
			code_edit.gutters_draw_line_numbers = true
			code_edit.scroll_fit_content_height = true
			code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			code_edit.autowrap_mode = TextServer.AUTOWRAP_WORD
			code_edit.deselect_on_focus_loss_enabled = true
			code_edit.syntax_highlighter = _syntax_highlighters.get(tag_text.trim_prefix("code:"), null)
			code_edit.text = snippet_text
			add_child(code_edit)
			code_edit.size.y = code_edit.get_minimum_size().y
			code_snippets.append({ code_edit = code_edit, pos_y = 0 })
			var TS := TextServerManager.get_primary_interface()
			var rid := get_theme_font("normal_font").get_rids()[0]
			var spacing := TS.font_get_spacing(rid, TextServer.SPACING_TOP) + TS.font_get_spacing(rid, TextServer.SPACING_BOTTOM)
			var asc100 := TS.font_get_ascent(rid, 100) + TS.font_get_descent(rid, 100) + spacing
			var sz := ceili(lerpf(0, 100, inverse_lerp(0, asc100, code_edit.get_minimum_size().y)))
			compiled += "[color=transparent][font_size=%s]_[/font_size]{code_block %s}[/color]" % [sz, code_snippets.size() - 1]
			k = l + 3
		elif tag_text.begins_with("page:"):
			tag_text = tag_text.trim_prefix("page:")
			compiled += "[url=cider:%s]%s[/url]" % [tag_text, tag_text.get_file().trim_prefix(">")]
		else:
			compiled += "[url=cider:%s]%s[/url]" % [tag_text, tag_text.get_file().trim_prefix(">")]

		i = k + 2
	compiled = compiled.replace("\n [/font_size]\n[ul]","\n [/font_size][ul]")
	if not Engine.is_editor_hint():
		compiled = TextUtils.bbcode_add_code_color(compiled)
	stop_indexes.clear()
	# Find and remove " ||" occurrences, saving the preceding indexes

	return [compiled, code_snippets]

func _set_highlight_t(v: float) -> void:
	_highlight_t = v
	queue_redraw()

func _get_line_rect(line: int) -> Rect2:
	var line_ofs := get_line_offset(_highlight_line)
	return Rect2(
		Vector2(0, line_ofs - get_v_scroll_bar().value + 1),
		Vector2(size.x, get_line_offset(_highlight_line + 1) - line_ofs + 2))

func _update_code_blocks(reset: bool = false) -> void:
	await get_tree().process_frame
	for i in _code_blocks.size():
		var c: Dictionary = _code_blocks[i]
		if reset:
			var line := get_character_line(get_parsed_text().find("_{code_block %s}" % i))
			c.pos_y = get_line_offset(line + 1) - c.code_edit.get_minimum_size().y + 2
		c.code_edit.position.y = c.pos_y - get_v_scroll_bar().value
		c.code_edit.size.x = size.x - (get_v_scroll_bar().size.x - 2 if get_v_scroll_bar().visible else 0)
		c.code_edit.size.y = c.code_edit.get_minimum_size().y

func _on_meta_clicked(meta: Variant) -> void:
	var url := str(meta)
	if url.begins_with("cider:"):
		var page_path: String = wiki_tab.make_absolute(url.substr(6))
		if page_path in wiki_tab.page_collection:
			wiki_tab.open_page(page_path)
		else:
			wiki_tab.create_page_dialog.path_label.text = page_path.get_base_dir().path_join("")
			wiki_tab.create_page_dialog.page_name_line_edit.text = page_path.get_file()
			wiki_tab.create_page_dialog.show()
	elif url.begins_with("res:"):
		var parts := url.rsplit("#", true, 1)
		var path := parts[0]
		var fragment := parts[1] if parts.size() == 2 else ""
		match path.get_extension():
			"tscn", "scn":
				Engine.get_singleton("EditorInterface").open_scene_from_path(path)
				if fragment != "":
					var node = Engine.get_singleton("EditorInterface").get_edited_scene_root().get_node_or_null(fragment)
					if not node:
						printerr("Node not found in scene: ", url)
					else:
						Engine.get_singleton("EditorInterface").get_selection().clear()
						Engine.get_singleton("EditorInterface").edit_node(node)
			"gd":
				var script := ResourceLoader.load(path, "Script") as Script
				var line := -1
				if fragment.is_valid_int():
					line = fragment.to_int()
				elif fragment != "":
					var regex := RegEx.create_from_string("(?m)^((static\\s+)?func|(static\\s+)?var|@onready var|@export[^\n]*var)\\s+%s[^a-zA-Z0-9_]" % [fragment])
					var reg_m := regex.search(script.source_code)
					if not reg_m:
						printerr("Member not found in script: ", url)
					else:
						line = 1 + script.source_code.count("\n", 0, reg_m.get_start())
				Engine.get_singleton("EditorInterface").set_main_screen_editor("Script")
				Engine.get_singleton("EditorInterface").edit_script(script, line)
			_:
				Engine.get_singleton("EditorInterface").select_file(path)
	else:
		OS.shell_open(url)

func _on_meta_hover_started(meta: Variant) -> void:
	if meta_label != null:
		meta_label.text = str(meta)
		meta_label_container.show()

func _on_meta_hover_ended(meta: Variant) -> void:
	if meta_label != null:
		meta_label.text = ""
		meta_label_container.hide()

func _on_v_scroll_bar_value_changed(value: float) -> void:
	_update_code_blocks()

func _on_resized() -> void:
	_update_code_blocks(true)

func _process(delta: float) -> void:
	if is_typing:
		if is_waiting_for_next_step:
			return
		if visible_characters < get_total_character_count():
			_type_next(delta)
		else:
			is_typing = false
			finished_typing.emit()
			set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if is_typing and event.is_action_pressed(skip_action):
		skip_typing()

func type_out() -> void:
	_original_text = text
	visible_characters = 0
	is_typing = true
	set_process(true)

func skip_typing() -> void:
	is_waiting_for_next_step = false
	visible_characters = get_total_character_count()
	is_typing = false
	finished_typing.emit()
	set_process(false)

func _type_next(delta: float) -> void:
	var characters_to_type: float = characters_per_second * delta
	var new_visible_characters: int = mini(visible_characters + ceili(characters_to_type), get_total_character_count())

	if (not stop_indexes.is_empty()) and new_visible_characters >= stop_indexes[0]:
		is_waiting_for_next_step = true
		new_visible_characters = stop_indexes[0] - 1
		stop_indexes.pop_front()

	for i in range(visible_characters, new_visible_characters):
		spoke.emit(_original_text[i], i, 1.0)
	#if not stop_indexes.is_empty():
		#prints(visible_characters, stop_indexes[0])
	visible_characters = new_visible_characters
