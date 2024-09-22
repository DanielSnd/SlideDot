extends Control
class_name SpinWheel

var segment_names:Array = []
var segment_colors = []
var num_segments = 0

const FONT = preload("res://ui/LilitaOne-Regular.ttf")

var current_rotation = 0.0
var spin_speed = 0.0
var is_spinning = false
var deceleration = 0.8
var deceleration_max = 4.6

var text_positions = []
signal winner_selected_emit(winner_name:String)

func _ready():
	# Example usage
	segment_colors = [Color("#FF9AA2"), Color("#FFB7B2"), Color("#FFDAC1"), Color("#E2F0CB"), Color("#B5EAD7"),
	Color("#C7CEEA"), Color("#FF8B94"), Color("#FFB6C1"), Color("#FFA07A"), Color("#98FB98"),
	Color("#87CEFA"), Color("#DDA0DD"), Color("#F0E68C"), Color("#E6E6FA"), Color("#FFA07A"),
	Color("#20B2AA"), Color("#FF69B4"), Color("#FFC0CB"), Color("#FFD700"), Color("#00CED1")]

func set_segments(names: Array):
	segment_names.clear()
	for i in names:
		segment_names.push_back([i,0.0,0.0])
	num_segments = names.size()

var spin_starting:bool = false

func _process(delta):
	if is_spinning:
		current_rotation += -spin_speed * delta
		#if not spin_starting:
			#spin_speed = max(0, spin_speed - lerp(deceleration,deceleration_max,inverse_lerp(0,25.0,spin_speed)) * delta)
#
			##if spin_speed < 0.09 and best_dot_right < 0.90:
				##spin_speed = 0.1
			#if spin_speed == 0:
				#is_spinning = false
				#determine_winner()
	queue_redraw()

func spin():
	if is_spinning:
		return
	is_spinning = true
	var ytwn: = YTween.create_unique_tween(self,3)
	for i in segment_names.size():
		ytwn.parallel().tween_method(winner_tween_method.bind(i), segment_names[i][2], 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK,1.2)
	ytwn.parallel().tween_property(self,"spin_speed", randf_range(12, 24.2), 4.42).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK,1.88)
	ytwn.tween_interval(2.0)
	ytwn.chain().tween_property(self,"spin_speed", 0.1, 8.00).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	ytwn.chain().tween_property(self,"spin_speed", 0.0, 2.00).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK,1.8)
	spin_starting = true
	await ytwn.finished_or_killed
	spin_starting = false
	is_spinning = false
	determine_winner()

func winner_tween_method(value:float,index:int):
	if index >= 0 and index < segment_names.size():
		segment_names[index][2] = value

var had_first_spin:bool = false
func determine_winner():
	var best_aligned = -1
	var winner:int = -1
	for i in segment_names.size():
		if segment_names[i][1] > best_aligned:
			best_aligned = segment_names[i][1]
			winner = i
	print(YTime.time," Winner: " + segment_names[winner][0])
	winner_selected_emit.emit(segment_names[winner][0])
	var ytwn: = YTween.create_unique_tween(self,4)
	for i in segment_names.size():
		ytwn.parallel().tween_method(winner_tween_method.bind(i), segment_names[i][2], 1.0 if winner == i else -1.0, 1.42).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK,1.88)


var best_dot_right:float = 0.0
func _draw():
	if num_segments <= 1:
		return

	var center = global_position  # Center of the wheel
	var radius = 340  # Radius of the wheel
	var text_center_Distance:float = 0.58
	var angle_per_segment = 2 * PI / num_segments
	var outline_width = 6  # Width of the segment outline

	for i in segment_names.size():

		var start_angle = i * angle_per_segment - current_rotation
		var end_angle = (i + 1) * angle_per_segment - current_rotation
		var color = segment_colors[i % segment_colors.size()]
		var use_radius = radius

		if not is_spinning:
			use_radius = radius + (segment_names[i][2] * 40)
			if segment_names[i][2] < -0.001:
				color = color.lerp(Color.SLATE_GRAY, abs(segment_names[i][2]))

		# Calculate text position and rotation
		var text_angle = ((start_angle + end_angle) / 2)
		var text_position = center + Vector2(cos(text_angle), sin(text_angle)) * (use_radius * text_center_Distance)

		var direction_to_text = (text_position - center).normalized()
		var dot_product = direction_to_text.dot(Vector2.RIGHT)
		segment_names[i][1] = max(dot_product,0.0)

		# Draw filled segment
		draw_circle_arc_poly(center, use_radius, start_angle, end_angle, color.darkened(lerp(0.25,0.8,max(0.3 - (segment_names[i][1] * segment_names[i][1]) * 0.32, 0.0))))

		# Draw segment outline
		draw_arc(center, use_radius, start_angle, end_angle, 128, color.darkened(0.6 - segment_names[i][1] * 0.25), outline_width + lerp(0.0,16.0,segment_names[i][1] * segment_names[i][1]))

		# Draw rotated text with drop shadow
		draw_rotated_text_with_shadow(FONT, text_position, segment_names[i][0], text_angle, (color as Color).lightened(0.34 + (segment_names[i][1] * segment_names[i][1]) * 0.5))

# Updated helper function to draw rotated text with drop shadow
func draw_rotated_text_with_shadow(font, text_position, text:String, angle, color, font_size:int = 36):
	var transform = Transform2D().rotated(angle)
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var offset = Vector2(-text_size.x / 2, text_size.y / 4)

	# Draw drop shadow
	draw_set_transform(text_position + Vector2(3, 3), transform.get_rotation(), Vector2.ONE)
	draw_string(font, offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color.darkened(0.72))

	# Draw main text
	draw_set_transform(text_position, transform.get_rotation(), Vector2.ONE)
	draw_string(font, offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)  # Reset transform

# Helper function to draw filled circle arc
func draw_circle_arc_poly(center, radius, angle_from, angle_to, color):
	var nb_points = 32
	var points_arc = PackedVector2Array()
	points_arc.push_back(center)
	var colors = PackedColorArray([color])

	for i in range(nb_points + 1):
		var angle_point = angle_from + i * (angle_to - angle_from) / nb_points
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)

	draw_polygon(points_arc, colors)
