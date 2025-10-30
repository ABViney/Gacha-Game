extends Node

#region config file stuff
var _CONFIG_FILE_PATH := "res://config.cfg"
var _CONFIG_SECTION_TITLE := "CONFIG"
var _CONFIG_TITLE_KEY := "window_title"
var _CONFIG_WIDTH_KEY := "width"
var _CONFIG_HEIGHT_KEY := "height"
var _CONFIG_MUSIC_PATH_KEY := "music"
#endregion

#region config state
var window_title : String
var window_width : int
var window_height : int

var path_to_music : String
#endregion

func _ready() -> void:
	print("Setting up configuration")
	_load_configuration()
	print("%s %s %s %s" % [window_title, window_width, window_height, path_to_music])


# Update the config.
# Returns true if the config was successfully updated AND saved
func update_config(config : Variant) -> void:
	var default_config := _create_default_config()
	
	if config != null and config.has_window_title:
		window_title = config.window_title
	else:
		window_title = default_config.window_title
	if config != null and config.has_window_size:
		window_width = config.window_width
		window_height = config.window_height
	else:
		window_width = default_config.window_width
		window_height = default_config.window_height
	if config != null and config.has_music:
		path_to_music = config.path_to_music
	else:
		path_to_music = default_config.path_to_music
	
	var error = _save_configuration()
	if error != OK:
		print_debug("Failed to save config to %s. Error code: %s" % [_CONFIG_FILE_PATH, error])
	
	EventBus.app_configured.emit()


func _load_configuration() -> void:
	var config_file := ConfigFile.new()
	var config := AppConfig.new()
	var error = config_file.load(_CONFIG_FILE_PATH)
	
	if error != OK:
		# No config created yet. Update with the default config settings
		print("Config file not found, loading default config...")
		update_config(null)
		return
	else:
		print("Config file found, loading settings from disk")
		# Set up a config object to update the app configuration's state with
		
		# title
		if config_file.has_section_key(_CONFIG_SECTION_TITLE, _CONFIG_TITLE_KEY):
			config.window_title = String(config_file.get_value(_CONFIG_SECTION_TITLE, _CONFIG_TITLE_KEY))
			config.has_window_title = true
		
		# widthxheight
		if config_file.has_section_key(_CONFIG_SECTION_TITLE, _CONFIG_WIDTH_KEY) and config_file.has_section_key(_CONFIG_SECTION_TITLE, _CONFIG_HEIGHT_KEY):
			config.window_width = int(config_file.get_value(_CONFIG_SECTION_TITLE, _CONFIG_WIDTH_KEY))
			config.window_height = int(config_file.get_value(_CONFIG_SECTION_TITLE, _CONFIG_HEIGHT_KEY))
			config.has_window_size = true
		
		# music
		if config_file.has_section_key(_CONFIG_SECTION_TITLE, _CONFIG_MUSIC_PATH_KEY):
			config.path_to_music = String(config_file.get_value(_CONFIG_SECTION_TITLE, _CONFIG_MUSIC_PATH_KEY))
			config.has_music = true
	update_config(config)

func _save_configuration() -> Error:
	print("Saving configuration to disk.")
	var config := ConfigFile.new()
	config.set_value(_CONFIG_SECTION_TITLE, _CONFIG_TITLE_KEY, window_title)
	config.set_value(_CONFIG_SECTION_TITLE, _CONFIG_WIDTH_KEY, window_width)
	config.set_value(_CONFIG_SECTION_TITLE, _CONFIG_HEIGHT_KEY, window_height)
	config.set_value(_CONFIG_SECTION_TITLE, _CONFIG_MUSIC_PATH_KEY, path_to_music)
	return config.save(_CONFIG_FILE_PATH)

func _create_default_config() -> AppConfig:
	var config = AppConfig.new()
	config.window_title = "Gacha Game"
	config.window_width = 300
	config.window_height = 300
	config.path_to_music = "res://sounds/music/mario_wii_item_music.ogg"
	return config
