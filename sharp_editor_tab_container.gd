extends TabContainer



func _on_tab_changed(tab):
	await get_tree().process_frame
	#prints(tab,get_minimum_size())
	if tab == -1:
		size.y = get_minimum_size().y
		position.y = size.y
		property_list_changed.emit()
