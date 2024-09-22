extends Node

# Maps type indices to their string representation.
const TYPE_MAP := {
	TYPE_BOOL: "boolean",
	TYPE_INT: "whole number",
	TYPE_STRING: "text string",
	TYPE_VECTOR2: "2D vector",
	TYPE_RECT2: "2D rectangle",
	TYPE_VECTOR3: "3D vector",
	TYPE_TRANSFORM2D: "2D transform",
	TYPE_PLANE: "plane",
	TYPE_QUATERNION: "quaternion",
	TYPE_AABB: "axis-aligned bounding box",
	TYPE_BASIS: "basis",
	TYPE_TRANSFORM3D: "3D transform",
	TYPE_COLOR: "color",
	TYPE_NODE_PATH: "node path",
	TYPE_RID: "resource's unique ID",
	TYPE_OBJECT: "object",
	TYPE_DICTIONARY: "dictionary",
	TYPE_ARRAY: "array",
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
	TYPE_PACKED_INT32_ARRAY: "PoolIntArray"
}

# Caches regexes to highlight code in text.
var _REGEXES := {}
# Intended to be used as a constant
var _REGEX_REPLACE_MAP := {}

const COLOR_CLASS := Color(0.666667, 0, 0.729412)
const COLOR_MEMBER := Color(0.14902, 0.776471, 0.968627)
const COLOR_KEYWORD := Color(1, 0.094118, 0.321569)
const COLOR_QUOTES := Color(1, 0.960784, 0.25098)
const COLOR_COMMENTS := Color(0.290196, 0.294118, 0.388235)
const COLOR_NUMBERS := Color(0.922, 0.580, 0.200)
const KEYWORDS := [

	# Basic keywords.
	"var",
	"const",
	"func",
	"signal",
	"enum",
	"class",
	"static",
	"extends",
	"self",

	# Control flow keywords.
	"if",
	"elif",
	"else",
	"not",
	"and",
	"or",
	"in",
	"for",
	"do",
	"while",
	"match",
	"switch",
	"case",
	"break",
	"continue",
	"pass",
	"return",
	"is",

	# Godot-specific keywords.
	"onready",
	"export",
	"tool",
	"setget",
	"breakpoint",
	"remote", "sync",
	"master", "puppet", "slave",
	"remotesync", "mastersync", "puppetsync",

	# Primitive data types.
	"bool",
	"int",
	"float",
	"null",
	"true", "false",

	# Global GDScript namespace.
	"Color8",
	"ColorN",
	"abs",
	"acos",
	"asin",
	"assert",
	"atan",
	"atan2",
	"bytes2var",
	"cartesian2polar",
	"ceil",
	"char",
	"clamp",
	"convert",
	"cos",
	"cosh",
	"db2linear",
	"decials",
	"dectime",
	"deg2rad",
	"dict2inst",
	"ease",
	"expo",
	"floor",
	"fmod",
	"fposmod",
	"funcref",
	"hash",
	"inst2dict",
	"instance_from_id",
	"inverse_lerp",
	"is_inf",
	"is_nan",
	"len",
	"lerp",
	"linear2db",
	"load",
	"log",
	"max",
	"min",
	"nearest_po2",
	"parse_json",
	"polar2cartesian",
	"pow",
	"preload",
	"print",
	"print_stack",
	"printerr",
	"printraw",
	"prints",
	"printt",
	"rad2deg",
	"rand_range",
	"rand_seed",
	"randf",
	"randi",
	"randomize",
	"range",
	"range_lerp",
	"round",
	"seed",
	"sign",
	"sin",
	"sinh",
	"sqrt",
	"stepify",
	"str",
	"str2var",
	"tan",
	"tanh",
	"to_json",
	"type_exists",
	"typeof",
	"validate_json",
	"var2bytes",
	"var2str",
	"weakref",
	"wrapf",
	"wrapi",
	"yield",

	"PI", "TAU", "INF", "NAN",

]

func _init() -> void:
	_REGEXES["code"] = RegEx.new()
	_REGEXES["func"] = RegEx.new()
	_REGEXES["number"] = RegEx.new()
	_REGEXES["string"] = RegEx.new()
	_REGEXES["symbol"] = RegEx.new()
	_REGEXES["format"] = RegEx.new()


	_REGEXES["code"].compile("\\[code\\](.+?)\\[\\/code\\]")
	_REGEXES["func"].compile("(?<func>func)")
	_REGEXES["number"].compile("(?<number>-?\\d+(\\.\\d+)?)")
	_REGEXES["string"].compile("(?<string>[\"'].+[\"'])")
	_REGEXES["symbol"].compile("(?<symbol>[a-zA-Z][a-zA-Z0-9_]+|[a-zA-Z])")
	_REGEXES["format"].compile("[\"\\-']?\\d+(\\.\\d+)?[\"']?|[\"'].+[\"']|[a-zA-Z0-9_]+")

	_REGEX_REPLACE_MAP = {
		"func": "[color=#%s]$func[/color]" % COLOR_KEYWORD.to_html(false),
		"number": "[color=#%s]$number[/color]" % COLOR_NUMBERS.to_html(false),
		"symbol": "[color=#%s]$symbol[/color]" % COLOR_MEMBER.to_html(false),
		"string": "[color=#%s]$string[/color]" % COLOR_QUOTES.to_html(false),
	}


func bbcode_add_code_color(bbcode_text := "") -> String:
	var regex_matches: Array = _REGEXES["code"].search_all(bbcode_text)
	var index_delta := 0

	for regex_match in regex_matches:
		var index_offset = regex_match.get_start() + index_delta
		var initial_length: int = regex_match.strings[0].length()
		var match_string: String = regex_match.strings[1]

		var colored_string := ""
		# The algorithm consists of finding all regex matches of a-zA-Z0-9_ and \d.\d
		# Then formatting these regex matches, and adding the parts in-between
		# matches to the formatted string.
		var to_format: Array = _REGEXES["format"].search_all(match_string)
		var last_match_end := -1
		for match_to_format in to_format:
			var match_start: int = match_to_format.get_start()
			if last_match_end == -1 and match_start > 0:
				colored_string += match_string.substr(0, match_start)
			if last_match_end != -1:
				colored_string += match_string.substr(last_match_end, match_start - last_match_end)
			var part: String = match_to_format.get_string()
			for regex_type in [
				"string",
				"func",
				"symbol",
				"number",
			]:
				var replaced: String = _REGEXES[regex_type].sub(
					part, _REGEX_REPLACE_MAP[regex_type], false
				)
				if part != replaced:
					colored_string += replaced
					last_match_end = match_to_format.get_end()
					break

		colored_string += match_string.substr(last_match_end)
		if colored_string == "":
			colored_string = match_string
		colored_string = "[code]" + colored_string + "[/code]"
		bbcode_text = bbcode_text.erase(index_offset, initial_length)
		bbcode_text = bbcode_text.insert(index_offset, colored_string)
		index_delta += (colored_string.length() - initial_length)

	return bbcode_text


func convert_type_index_to_text(type: int) -> String:
	if type in TYPE_MAP:
		return TYPE_MAP[type]
	else:
		printerr("Type value %s should be a member of the TYPE_* enum, but it is not.")
		return "[ERROR, nonexistent type value %s]" % type


# Call this function to ensure that changes to the formatter don't change color highlighting.
func _test_formatting() -> String:
	#var color_keyword := COLOR_KEYWORD.to_html(false)
	var color_number := COLOR_NUMBERS.to_html(false)
	var color_symbol := COLOR_MEMBER.to_html(false)
	var color_string := COLOR_QUOTES.to_html(false)
	# Pairs of strings that would be inside of [code] bbcode tags and their formatted output.
	# We omit the [code] tags in the dictionary for readability, they get added in the tests.
	var test_pairs := {
		"[0, 1, 2]": "[[color=#eb9433]0[/color], [color=#eb9433]1[/color], [color=#eb9433]2[/color]]",
		"-10": "[color=#" + color_number + "]-10[/color]",
		"\"Some string.\"": "[color=#" + color_string + "]\"Some string.\"[/color]",
		"add_order()": "[color=#" + color_symbol + "]add_order[/color]()",
		"Vector2(2, 0)": "[color=#" + color_symbol + "]Vector2[/color]([color=#" + color_number + "]2[/color], [color=#" + color_number + "]0[/color])",
		"use_item(item)": "[color=#" + color_symbol + "]use_item[/color]([color=#" + color_symbol + "]item[/color])",
		"=": "=",
		">": ">",
	}
	var return_test_result = ""
	for input_text in test_pairs:
		var expected_output: String = "[code]%s[/code]" % test_pairs[input_text]
		var output := bbcode_add_code_color("[code]%s[/code]" %  input_text)
		return_test_result += output
		assert(output == expected_output, "Expected output '%s' but got '%s' instead." % [expected_output, output])
	return return_test_result
