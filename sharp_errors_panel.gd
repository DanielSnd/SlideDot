extends HBoxContainer

signal error_pressed(line_number, line_column)

@onready var error_button: Button = $ErrorButton
@onready var next_button: Button = $NextButton
@onready var count_label: Label = $CountLabel
@onready var previous_button: Button = $PreviousButton

## The index of the current error being shown
var error_index: int = 0:
	set(next_error_index):
		error_index = wrap(next_error_index, 0, errors.size())
		show_error()
	get:
		return error_index

## The list of all errors
var errors: Array = []:
	set(next_errors):
		errors = next_errors
		self.error_index = 0
	get:
		return errors


func _ready() -> void:
	hide()




## Move the error index to match a given line
func show_error_for_line_number(line_number: int) -> void:
	for i in range(0, errors.size()):
		if errors[i].line_number == line_number:
			self.error_index = i


## Show the current error
func show_error() -> void:
	if errors.size() == 0:
		hide()
	else:
		show()
		count_label.text = "%d of %d" % [error_index + 1, errors.size()]
		var error = errors[error_index]
		error_button.text = "Line %d Column %d  Error: %s" % [error.line_number + 1, error.column_number, error.error]

### Signals


func _on_error_button_pressed() -> void:
	error_pressed.emit(errors[error_index].line_number, errors[error_index].column_number)


func _on_previous_button_pressed() -> void:
	self.error_index -= 1
	_on_error_button_pressed()


func _on_next_button_pressed() -> void:
	self.error_index += 1
	_on_error_button_pressed()
