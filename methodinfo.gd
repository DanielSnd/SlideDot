class_name RMethodInfo extends RefCounted
var return_type: String = "void"
var method_name: String = "method"
var method_class_name: String = ""
var method_namespace_name: String = ""
var is_static_method: bool = false
var is_static_class: bool = false
var has_console_request:bool = false

func set_method_info(info: Dictionary):
	method_name = info.get("name", method_name)
	return_type = info.get("return", return_type)
	method_class_name = info.get("class", method_class_name)
	method_namespace_name = info.get("namespace", method_namespace_name)
	is_static_method = info.get("static_method", 1 if is_static_method else 0) == 1
	is_static_class = info.get("static_class", 1 if is_static_class else 0) == 1
