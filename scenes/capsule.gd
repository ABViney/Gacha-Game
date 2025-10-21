extends Node2D

@onready var capsule_bottom_half : Sprite2D = $CapsuleBottomHalfSprite
@onready var reward_sprite : Sprite2D = $RewardSprite
@onready var flavor_text : Label = $FlavorTextLabel

var color : Color:
	get:
		return color
	set(value):
		color = value
		_update_capsule_color()


func _init(reward : Reward):
	color = reward.capsule_color.to_html(false)
	

func _ready() -> void:
	#_update_capsule_color(Image.load_from_file())
	pass


func _update_capsule_color() -> void:
	var input_file : String
	var output_file : String
	# godot methods return strings representing file paths. These strings are raw
	# and retain spaces
	if OS.is_debug_build():
		print("debug mode")
		input_file = ProjectSettings.globalize_path("res://images/capsule-bottom-half.png")
		output_file = ProjectSettings.globalize_path("res://cache/%s.png" % color)
	else:
		print("prod mode")
		input_file = OS.get_executable_path().get_base_dir().path_join("images/capsule-bottom-half.png")
		output_file = OS.get_executable_path().get_base_dir().path_join("cache/%s.png" % color)
	print("Input file: `%s`\nOutput file: `%s`" % [input_file, output_file])
	
	if not FileAccess.file_exists(output_file):
		print("Variant not found, creating from template...")
		# since we're using imagemagick via CLI to create variants, we need escaped 
		# paths to point to. Only character i'm aware of that needs to be escaped is
		# space.
		var escaped_input_file = input_file.replace(" ", "\\ ")
		var escaped_output_file = output_file.replace(" ", "\\ ")
		# Creating a variant of the capsule bottom for use in this instance. Variants are cached for
		# future use. Might wanna clear this if Jane really likes using random colors
		# first string is input file, second string is color, third string is output file
		var cmd : String = "convert {0} -fuzz 100% -fill \\\"{1}\\\" -opaque \\\"#000000\\\" {2}".format([escaped_input_file, color.to_html(false), escaped_output_file])
		# This function invokes a program with arguments. Obvious, yeah. What isn't as obvious is 
		# that it will wrap your arguments in quotes for you. It does have caveats for platform
		# specific terminals, like CMD.exe, PowerShell, and Bash, that the first argument might not
		# be wrapped if it is specifying arguments for the terminal (-c in the event of /bin/bash
		OS.execute("/bin/bash", ["-c", cmd])
		print("Capsule variant created")
		assert(FileAccess.file_exists(output_file), "Failed to create variant or i dunno where it ended up teehee")
	
	$CapsuleBottomHalf.texture = ImageTexture.create_from_image(Image.load_from_file(output_file))
