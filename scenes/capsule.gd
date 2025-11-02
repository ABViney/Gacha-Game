extends Node2D
class_name Capsule

static var opening_sounds : Array[AudioStream]
static var closing_sounds : Array[AudioStream]
static var dropping_sounds : Array[AudioStream]

static var initial_sounds_loaded : bool = false;

@onready var capsule_bottom_half : Sprite2D = $CapsuleBottomHalfSprite
@onready var reward_sprite : Sprite2D = $RewardSprite
@onready var flavor_text : Label = $FlavorTextLabel
@onready var animation_player : AnimationPlayer = $AnimationPlayer

@onready var audio_stream_player : AudioStreamPlayer = $AudioStreamPlayer

var physics_enabled := true

var _color : Color = Color.BLACK
@export var color : Color:
	get:
		return _color
	set(value):
		_color = value
		# If the capsule is already in the scene tree, we can change its texture
		if (self.is_node_ready()):
			_update_capsule_color()

func _ready() -> void:
	if not initial_sounds_loaded:
		_load_sounds()
	_update_capsule_color()

#region Animation

func play_open_animation() -> void:
	animation_player.play("open capsule")
	await animation_player.animation_finished

#endregion Animation

#region Playback
func _play_open_sound() -> void:
	_play_random_sound_from(opening_sounds)

func _play_close_sound() -> void:
	_play_random_sound_from(closing_sounds)

func _play_drop_sound() -> void:
	_play_random_sound_from(dropping_sounds)

func _play_random_sound_from(sounds : Array[AudioStream]) -> void:
	audio_stream_player.stream = sounds[randi() % (sounds.size()-1)]
	audio_stream_player.play()

func _load_sounds() -> void:
	# function loads all sound files as AudioStream instances from the specified folder
	var get_sound_files_in_folder = func (folder_path) -> Array[AudioStream]:
		print("Loading sound files from: %s" % folder_path)
		var audio_streams : Array[AudioStream] = []
		var dir = DirAccess.open(folder_path)
		if dir:
			var files : PackedStringArray = dir.get_files()
			for file : String in files:
				var resource = ResourceLoader.load(folder_path.path_join(file))
				if resource is AudioStream:
					audio_streams.append(resource)
		else:
			print_debug("Failed to open directory at %s\nError message: " % [folder_path, DirAccess.get_open_error()])
		return audio_streams
	
	if OS.is_debug_build():
		opening_sounds = get_sound_files_in_folder.call("res://sounds/capsule/open")
		closing_sounds = get_sound_files_in_folder.call("res://sounds/capsule/close")
		dropping_sounds = get_sound_files_in_folder.call("res://sounds/capsule/drop")
	else:
		# TODO: Gotta figure out where these files will be when exported.
		opening_sounds = get_sound_files_in_folder.call(OS.get_executable_path().get_base_dir().path_join("sounds/capsule/open"))
		closing_sounds = get_sound_files_in_folder.call(OS.get_executable_path().get_base_dir().path_join("sounds/capsule/close"))
		dropping_sounds = get_sound_files_in_folder.call(OS.get_executable_path().get_base_dir().path_join("sounds/capsule/drop"))
	
	initial_sounds_loaded = true
#endregion Playback

func _update_capsule_color() -> void:
	var input_file : String
	var output_file : String
	var color_string : String = color.to_html(false)
	# godot methods return strings representing file paths. These strings are raw
	# and retain spaces
	if OS.is_debug_build():
		input_file = ProjectSettings.globalize_path("res://images/capsule-bottom-half.png")
		output_file = ProjectSettings.globalize_path("res://cache/%s.png" % color_string)
	else:
		input_file = OS.get_executable_path().get_base_dir().path_join("images/capsule-bottom-half.png")
		output_file = OS.get_executable_path().get_base_dir().path_join("cache/%s.png" % color_string)
	
	if not FileAccess.file_exists(output_file):
		print("Variant not found, creating from template...")
		
		## This code is obsolete. I can do this using Godot built-ins. Keeping
		## for future reference, however, as it is informative.
		# since we're using imagemagick via CLI to create variants, we need escaped 
		# paths to point to. Only character i'm aware of that needs to be escaped is
		# space.
		#var escaped_input_file = input_file.replace(" ", "\\ ")
		#var escaped_output_file = output_file.replace(" ", "\\ ")
		# Creating a variant of the capsule bottom for use in this instance. Variants are cached for
		# future use. Might wanna clear this if Jane really likes using random colors
		# first string is input file, second string is color, third string is output file
		#var cmd : String = "convert {0} -fuzz 100% -fill \\\"#{1}\\\" -opaque \\\"#000000\\\" {2}".format([escaped_input_file, color_string, escaped_output_file])
		#print(cmd)
		# This function invokes a program with arguments. Obvious, yeah. What isn't as obvious is 
		# that it will wrap your arguments in quotes for you. It does have caveats for platform
		# specific terminals, like CMD.exe, PowerShell, and Bash, that the first argument might not
		# be wrapped if it is specifying arguments for the terminal (-c in the event of /bin/bash
		#OS.execute("/bin/bash", ["-c", cmd])
		## End of obsolete code
		
		# New recolor op using Godot Image class
		var template := Image.new()
		template.load(input_file)
		for y in range(template.get_height()):
			for x in range(template.get_width()):
				var original_pixel = template.get_pixel(x, y)
				template.set_pixel(x, y, Color(color.r, color.g, color.b, original_pixel.a))
		template.save_png(output_file)
		
		assert(FileAccess.file_exists(output_file), "Failed to create variant or i dunno where it ended up teehee")
		print("Capsule variant created")
		capsule_bottom_half.texture = ImageTexture.create_from_image(template)
	else:
		capsule_bottom_half.texture = ImageTexture.create_from_image(Image.load_from_file(output_file))
