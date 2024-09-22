extends TextureRect

func _process(_delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var current_focus_control = get_viewport().gui_get_focus_owner()
		if current_focus_control:
			if &"is_mouse_hovered" in current_focus_control and not current_focus_control.is_mouse_hovered:
				current_focus_control.release_focus()
