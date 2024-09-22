extends HSlider

var stream_length:float = 0.0
var streamplayer:VideoStreamPlayer
# Called when the node enters the scene tree for the first time.
func _ready():
	streamplayer = (get_parent() as VideoStreamPlayer)
	await get_tree().process_frame
	stream_length = streamplayer.get_stream_length()
	print(stream_length)
	max_value = stream_length
	min_value = 0
	value_changed.connect(on_value_changed)
	await get_tree().process_frame
	if max_value < 0.001:
		max_value = 22

var ignore_value_changed_callback:bool = false
func on_value_changed(new_value:float):
	if not ignore_value_changed_callback and is_instance_valid(streamplayer):
		#streamplayer.paused=true
		#await get_tree().process_frame
		streamplayer.stream_position = new_value
		#await get_tree().process_frame
		#streamplayer.paused=false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_instance_valid(streamplayer):
		ignore_value_changed_callback = true
		value = get_parent().stream_position
		ignore_value_changed_callback = false
