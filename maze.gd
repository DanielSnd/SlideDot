extends Control

# Size of each cell in the grid
@export var cell_size = 20
# Number of rows and columns in the grid
@export var rows = 20
@export var cols = 20
@export var wall_line = 2
@export var empty_line = 1

@export var current_seed:String
@export var player_color:Color
@export var start_color:Color
@export var end_color:Color
@export var grid_empty_color:Color
@export var character_color:Color = Color(1, 0, 0) # Red color for the character

var execute_command_speed:float = 0.15
# 2D array to store the maze structure
var maze = []
# Stack for DFS
var stack = []
# Directions for moving in the grid
var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

# Character position and direction
var character_position = Vector2i(0, 0)
var character_direction = Vector2i(1, 0) # Initially facing right

var char_pos_visual:Vector2 = Vector2(0.0,0.0)
var char_dir_visual:Vector2 = Vector2(1.0,0.0)

func _ready():
	# Initialize the maze with walls
	_initialize_maze()
	# Generate the maze with a distinct solution
	_generate_maze()
	queue_redraw()
	position += Vector2(10.0,10.0)
	if (commands.syntax_highlighter as CodeHighlighter).color_regions.is_empty():
		(commands.syntax_highlighter as CodeHighlighter).add_color_region("   ","", Color.AQUA, true)

func _process(_delta):
	if Input.is_action_just_pressed(&"ui_focus_next"):
		_initialize_maze()
		_generate_maze()
		queue_redraw()
	if Input.is_action_just_pressed(&"ui_focus_prev"):
		generate_for_names()
		_initialize_maze()
		_generate_maze()
		queue_redraw()

	if Input.is_action_just_pressed("escape"):
		if commands.has_focus():
			commands.release_focus()
		else:
			_initialize_maze()
			_generate_maze()
			queue_redraw()
	if Input.is_action_just_pressed("ui_up") and not commands.has_focus():
		MoveForward()
	if Input.is_action_just_pressed("ui_left") and not commands.has_focus():
		TurnLeft()
	if Input.is_action_just_pressed("ui_right") and not commands.has_focus():
		TurnRight()
	if Input.is_action_just_pressed("ui_down") and not commands.has_focus():
		execute_commands()
	if Input.is_action_just_pressed(&"minus") and not commands.has_focus():
		execute_command_speed -= 0.03
		execute_command_speed = clampf(execute_command_speed,0.02,5.0)
	if Input.is_action_just_pressed(&"plus") and not commands.has_focus():
		execute_command_speed += 0.03
		execute_command_speed = clampf(execute_command_speed,0.02,5.0)
	queue_redraw()

@onready var commands = %Commands
@onready var rich_text_label = %RichTextLabel


func generate_for_names():
	if commands.get_line_count() > executing_id:
		rich_text_label.text = """[b]%s[/b]
[b]Possible commands:[/b]
➡️ Move Forward [color=999][i](Move the arrow in the direction it's pointing)[/i][/color]
 ⤴️   Turn Left [color=999][i](Rotate Counter-clockwise[/i][/color]
 ⤵️   Turn Right [color=999][i](Rotate Clockwise[/i][/color]""" % commands.get_line(executing_id)
		current_seed = commands.get_line(executing_id).strip_edges().to_upper()
		_initialize_maze()
		_generate_maze()
		queue_redraw()
	executing_id += 1
	if executing_id >= commands.get_line_count():
		executing_id = 0


var executing_id:int = 0
func execute_commands():
	executing_id += 1
	var starting_executing_id:int = executing_id
	var last_executed_line:int = 0
	if commands.get_line_count() > 0:
		rich_text_label.text = """[b]%s[/b]
[b]Possible commands:[/b]
➡️ Move Forward [color=999][i](Move the arrow in the direction it's pointing)[/i][/color]
 ⤴️   Turn Left [color=999][i](Rotate Counter-clockwise[/i][/color]
 ⤵️   Turn Right [color=999][i](Rotate Clockwise[/i][/color]""" % commands.get_line(0)
		current_seed = commands.get_line(0).strip_edges().to_upper()
		_initialize_maze()
		_generate_maze()
		queue_redraw()
		for i in commands.get_line_count():
			if executing_id != starting_executing_id:
				break
			if i == 0:
				continue
			last_executed_line = i
			if commands.get_line_count() > i - 1 and (commands.get_line(i-1) as String).begins_with("   "):
				commands.set_line(i-1, (commands.get_line(i-1) as String).substr(3))
			commands.set_line(i,"   %s" % (commands.get_line(i) as String))
			if (commands.get_line(i) as String).to_upper().begins_with("F") or  (commands.get_line(i) as String).to_upper().begins_with("   F") or (commands.get_line(i) as String).to_upper().contains("FO") or (commands.get_line(i) as String).to_upper().contains("FR")  or (commands.get_line(i) as String).to_upper().contains("FW"):
				MoveForward()
				await get_tree().create_timer(execute_command_speed * 2.0).timeout
				continue
			if executing_id != starting_executing_id:
				break
			if (commands.get_line(i) as String).to_upper().begins_with("L")  or  (commands.get_line(i) as String).to_upper().begins_with("   L")or (commands.get_line(i) as String).to_upper().contains("LE") or (commands.get_line(i) as String).to_upper().contains("LF")  or (commands.get_line(i) as String).to_upper().contains("LT"):
				TurnLeft()
				await get_tree().create_timer(execute_command_speed).timeout
				continue
			if executing_id != starting_executing_id:
				break
			if (commands.get_line(i) as String).to_upper().begins_with("R")  or  (commands.get_line(i) as String).to_upper().begins_with("   R") or (commands.get_line(i) as String).to_upper().contains("RI") or (commands.get_line(i) as String).to_upper().contains("RG")  or (commands.get_line(i) as String).to_upper().contains("RIG")  or (commands.get_line(i) as String).to_upper().contains("RT"):
				TurnRight()
				await get_tree().create_timer(execute_command_speed).timeout
				continue
			if executing_id != starting_executing_id:
				break

	if commands.get_line_count() > last_executed_line and (commands.get_line(last_executed_line) as String).begins_with("   "):
		commands.set_line(last_executed_line, (commands.get_line(last_executed_line) as String).substr(3))
	if executing_id == starting_executing_id:
		executing_id = 0

func _initialize_maze():
	maze = []
	for row in range(rows):
		var maze_row = []
		for col in range(cols):
			maze_row.append({
				"top": true,
				"right": true,
				"bottom": true,
				"left": true,
				"visited": false
			})
		maze.append(maze_row)

func _generate_maze():
	var start = Vector2i(0, 0)
	var end = Vector2i(cols - 1, rows - 1)
	stack.append(start)
	maze[start.y][start.x]["visited"] = true
	seed(current_seed.hash())
	var ytwn:= YTween.create_unique_tween(self, 3)
	character_position = Vector2i.ZERO
	character_direction = Vector2i.RIGHT
	ytwn.tween_property(self, "char_pos_visual", Vector2.ZERO,1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK,1.88)
	ytwn.parallel().tween_property(self, "char_dir_visual", Vector2.RIGHT,1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK,1.88)
	while stack.size() > 0:
		var current = stack[stack.size() - 1]
		var neighbors = _get_unvisited_neighbors(current)

		if neighbors.size() > 0:
			var next = neighbors[randi() % neighbors.size()]
			_remove_wall(current, next)
			stack.append(next)
			maze[next.y][next.x]["visited"] = true
		else:
			stack.pop_back()

	# Ensure the end cell is reachable if the stack is empty
	if stack.size() == 0:
		stack.append(end)
	_ensure_path_to_end(end)

func _get_unvisited_neighbors(cell):
	var neighbors = []
	for direction in directions:
		var neighbor = cell + direction
		if neighbor.x >= 0 and neighbor.x < cols and neighbor.y >= 0 and neighbor.y < rows:
			if not maze[neighbor.y][neighbor.x]["visited"]:
				neighbors.append(neighbor)
	return neighbors

func _remove_wall(current, next):
	var dx = next.x - current.x
	var dy = next.y - current.y

	if dx == 1:
		maze[current.y][current.x]["right"] = false
		maze[next.y][next.x]["left"] = false
	elif dx == -1:
		maze[current.y][current.x]["left"] = false
		maze[next.y][next.x]["right"] = false
	elif dy == 1:
		maze[current.y][current.x]["bottom"] = false
		maze[next.y][next.x]["top"] = false
	elif dy == -1:
		maze[current.y][current.x]["top"] = false
		maze[next.y][next.x]["bottom"] = false

func _ensure_path_to_end(end):
	var current = stack[stack.size() - 1]
	while current != end:
		var direction = (end - current).normalized()
		var next = current + direction.round()
		if next.x >= 0 and next.x < cols and next.y >= 0 and next.y < rows:
			if not maze[next.y][next.x]["visited"]:
				_remove_wall(current, next)
				maze[next.y][next.x]["visited"] = true
		current = next

func _draw():
	# Draw the grid and the maze walls
	for row in range(rows):
		for col in range(cols):
			var x = col * cell_size
			var y = row * cell_size
			# Draw the walls
			var cell = maze[row][col]
			if not cell["top"]:
				draw_line(Vector2(x, y), Vector2(x + cell_size, y), Color(0, 0, 0) if cell["top"] else grid_empty_color, wall_line if cell["top"] else empty_line)
			if not cell["right"]:
				draw_line(Vector2(x + cell_size, y), Vector2(x + cell_size, y + cell_size), Color(0, 0, 0) if cell["right"] else grid_empty_color, wall_line if cell["right"] else empty_line)
			if not cell["bottom"]:
				draw_line(Vector2(x, y + cell_size), Vector2(x + cell_size, y + cell_size), Color(0, 0, 0) if cell["bottom"] else grid_empty_color, wall_line if cell["bottom"] else empty_line)
			if not cell["left"]:
				draw_line(Vector2(x, y), Vector2(x, y + cell_size), Color(0, 0, 0) if cell["left"] else grid_empty_color, wall_line if cell["left"] else empty_line)

	for row in range(rows):
		for col in range(cols):
			var x = col * cell_size
			var y = row * cell_size

			# Draw the cell
			var cell_color = Color(1, 1, 1)
			if row == rows - 1 and col == cols - 1:
				cell_color = end_color # Color the end cell red
				draw_rect(Rect2(x, y, cell_size, cell_size), cell_color)
			if row == 0 and col == 0:
				cell_color = start_color # Color the end cell red
				draw_rect(Rect2(x, y, cell_size, cell_size), cell_color)

			# Draw the walls
			var cell = maze[row][col]
			if cell["top"]:
				draw_line(Vector2(x, y), Vector2(x + cell_size, y), Color(0, 0, 0) if cell["top"] else grid_empty_color, wall_line if cell["top"] else empty_line)
			if cell["right"] and not (row == rows -1):
				draw_line(Vector2(x + cell_size, y), Vector2(x + cell_size, y + cell_size), Color(0, 0, 0) if cell["right"] else grid_empty_color, wall_line if cell["right"] else empty_line)
			if cell["bottom"]:
				draw_line(Vector2(x, y + cell_size), Vector2(x + cell_size, y + cell_size), Color(0, 0, 0) if cell["bottom"] else grid_empty_color, wall_line if cell["bottom"] else empty_line)
			if cell["left"]:
				draw_line(Vector2(x, y), Vector2(x, y + cell_size), Color(0, 0, 0) if cell["left"] else grid_empty_color, wall_line if cell["left"] else empty_line)

	# Draw the character
	_draw_character()

func _draw_character():
	var cell_center : Vector2= Vector2(char_pos_visual.x * cell_size + cell_size / 2, char_pos_visual.y * cell_size + cell_size / 2)
	var size = cell_size / 2
	var p1 = (cell_center - char_dir_visual * size * 0.3) + Vector2(char_dir_visual).rotated(PI / 2) * size * 0.4
	var p2 = (cell_center - char_dir_visual * size * 0.2) + Vector2(char_dir_visual) * size * 0.2
	var p3 = (cell_center - char_dir_visual * size * 0.3) + Vector2(char_dir_visual).rotated(-PI / 2) * size * 0.4
	var p4 = cell_center + Vector2(char_dir_visual) * size * 0.5
	var points_arc = PackedVector2Array()
	points_arc.push_back(p1)
	points_arc.push_back(p2)
	points_arc.push_back(p3)
	points_arc.push_back(p4)
	var colors = PackedColorArray([player_color])
	draw_polygon(points_arc, colors)

func MoveForward():
	char_pos_visual = Vector2(character_position) - Vector2(character_direction) * 0.1
	var next_position = character_position + character_direction
	if next_position.x >= 0 and next_position.x < cols and next_position.y >= 0 and next_position.y < rows:
		var current_cell = maze[character_position.y][character_position.x]
		var next_cell = maze[next_position.y][next_position.x]

		if character_direction == Vector2i(1, 0) and not current_cell["right"]:
			character_position = next_position
		elif character_direction == Vector2i(-1, 0) and not current_cell["left"]:
			character_position = next_position
		elif character_direction == Vector2i(0, 1) and not current_cell["bottom"]:
			character_position = next_position
		elif character_direction == Vector2i(0, -1) and not current_cell["top"]:
			character_position = next_position

	var ytwn:= YTween.create_unique_tween(self,1)
	ytwn.tween_property(self, "char_pos_visual", Vector2(character_position), 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK,1.8)

func TurnLeft():
	character_direction = Vector2i(Vector2(character_direction).rotated(-PI / 2))
	var ytwn:= YTween.create_unique_tween(self,2)
	ytwn.tween_property(self, "char_dir_visual", Vector2(character_direction), 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK,1.8)

func TurnRight():
	character_direction = Vector2i(Vector2(character_direction).rotated(PI / 2))
	var ytwn:= YTween.create_unique_tween(self,2)
	ytwn.tween_property(self, "char_dir_visual", Vector2(character_direction), 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK,1.8)

# This line intentionally left blank
