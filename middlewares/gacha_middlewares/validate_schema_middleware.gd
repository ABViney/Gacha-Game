extends "res://middlewares/middelware.gd"
class_name ValidateSchemaMiddleware

## This class validates a request and also sets values in the context so it can be used further 
## down the pipeline.

func invoke(json_context : JSONContext) -> String:
	var error_messages : PackedStringArray = []
	
	#region validate request json
	# Attempt to convert the request to a JSON
	var json = JSON.new()
	var error = json.parse(json_context.raw_request)
	if not error == OK:
		error_messages.append("Could not parse request as JSON.")
		return json_context.format_error_response(error_messages)
	
	# The JSON shouldn't be an array or other(?) invalid structure
	if not typeof(json.data) == TYPE_DICTIONARY:
		error_messages.append("Invalid JSON format. Type recieved: %s. Expected: %s" % [type_string(typeof(json.data)), type_string(TYPE_DICTIONARY)])
		return json_context.format_error_response(error_messages)
	#endregion
	
	
	# data is a dictionary, cast it as such
	json_context.request = json.data
	
	# rather not enforce case-sensitivity. Dictionaries are by default, so we'll
	# grab the keys and populate the context with the relevant data
	var command_key : String
	var config_key : String
	var rewards_key : String
	
	# The JSON should have correctly named fields
	#region validate top-level fields
	for key : String in json_context.request.keys():
		match key.to_lower():
			"command":
				command_key = key
				json_context.has_command_field = true
			"config":
				config_key = key
				json_context.has_config_field = true
			"rewards":
				rewards_key = key
				json_context.has_rewards_field = true
			_:
				error_messages.append("[%s] is an invalid index." % key)
	#endregion
	
	# The command field must be present and should specify a known category
	#region ensure command field is present and validate value
	if not json_context.has_command_field:
		# Commands are a required field
		error_messages.append("Missing field [COMMAND] in request.")
		return json_context.format_error_response(error_messages)
	else:
		# Ensure value is a string
		if not typeof(json_context.request[command_key]) == TYPE_STRING:
			error_messages.append("Invalid value type for COMMAND. Expected: %s" % type_string(TYPE_STRING))
			return json_context.format_error_response(error_messages)
		
		var command : String = json_context.request[command_key]
		
		# There's a limited set of acceptable commands.
		match command.to_lower():
			"configure":
				json_context.command = json_context.Command.CONFIG
			"crank":
				json_context.command = json_context.Command.CRANK
			"get_rewards":
				json_context.command = json_context.Command.GET_REWARDS
			"kick":
				json_context.command = json_context.Command.KICK
			"load_machine":
				json_context.command = json_context.Command.LOAD_MACHINE
			_:
				# If an unrecognized command is passed that must be fixed 
				# before anything else will work as expected
				error_messages.append("[%s] is an unrecognized value for [COMMAND]" % command)
				return json_context.format_error_response(error_messages)
	#endregion
	
	#region validate config field contents if command is CONFIG
	if json_context.has_config_field and json_context.command == json_context.Command.CONFIG:
		# Value should be a dictionary
		if not typeof(json_context.request[config_key]) == TYPE_DICTIONARY:
			error_messages.append("Invalid JSON format for CONFIG. Type recieved: %s. Expected: %s" % [type_string(typeof(json_context.request[config_key])), type_string(TYPE_DICTIONARY)])
			return json_context.format_error_response(error_messages)
		
		var config : Dictionary = json_context.request[config_key]
		var app_config = AppConfig.new()
		
		# Verify nested fields in config
		for key : String in config:
			var field = key.to_lower()
			match field:
				"window_title":
					if not typeof(config[key]) == TYPE_STRING:
						error_messages.append("Invalid JSON format for CONFIG->WINDOW_TITLE. Type recieved: %s. Expected: %s" % [type_string(typeof(config[key])), type_string(TYPE_STRING)])
						continue
					app_config.window_title = config[key]
					app_config.has_window_title = true
				"window_size":
					if not typeof(config[key]) == TYPE_ARRAY:
						error_messages.append("Invalid JSON format for CONFIG->WINDOW_SIZE. Type recieved: %s. Expected: %s" % [type_string(typeof(config[key])), type_string(TYPE_ARRAY)])
						continue
					# Window size is an array so it can be brought in scope to simplify calls
					var window_size : Array = config[key]
					if not window_size.size() == 2:
						error_messages.append("Invalid number of arguments for CONFIG->WINDOW_SIZE. %s recieved. Expected: 2 ([x,y])" % window_size.size())
						continue
					# JSON.to_native converts numerical values to float.
					if not (typeof(window_size[0]) == TYPE_FLOAT and typeof(window_size[1] == TYPE_FLOAT)):
						error_messages.append("Invalid argument types for CONFIG->WINDOW_SIZE. Expected: [%s,%s]" % [type_string(TYPE_INT), type_string(TYPE_INT)])
						continue
					#  They must be cast to ints. Replace these values in the data w/ int types
					window_size = [int(window_size[0]), int(window_size[1])]
					if not (window_size[0] > 0 and window_size[1] > 0):
						error_messages.append("Invalid argument value for CONFIG->WINDOW_SIZE provided. Values must be positive integers greater than 0.")
					# window size is validated so it can be assigned now yippee
					app_config.window_width = window_size[0]
					app_config.window_height = window_size[1]
					app_config.has_window_size = true
				"music":
					# Verify value is a string
					if not typeof(config[key]) == TYPE_STRING:
						error_messages.append("Invalid JSON format for CONFIG->WINDOW_SIZE. Type recieved: %s. Expected: %s" % [type_string(typeof(config[key])), type_string(TYPE_STRING)])
						continue
					# Verify path points to an existing file
					if not FileAccess.file_exists(config[key]):
						error_messages.append("File specified in CONFIG->MUSIC not found at %s" % config[key])
						continue
					app_config.path_to_music = config[key]
					app_config.has_music = true
				# TODO other config stuff goes here
		
		# Assign new config to context
		json_context.config = app_config
	#endregion
	
	#region validate rewards content if command is LOAD_MACHINE
	if json_context.has_rewards_field and json_context.command == json_context.Command.LOAD_MACHINE:
		# Ensure value is an array
		if not typeof(json_context.request[rewards_key]) == TYPE_ARRAY:
			error_messages.append("Invalid JSON format for REWARDS. Type recieved: %s. Expected: %s" % [type_string(typeof(json_context.request[config_key])), type_string(TYPE_ARRAY)])
			return json_context.format_error_response(error_messages)
		
		var items : Array = json_context.request[rewards_key] # Every item defined in the request
		var reward_ids = {} # IDs must be unique. Using a dictionary to compare
		var color_regex = RegEx.create_from_string("^#?[0-9A-Fa-f]{6}$") # setup for testing hex colors
		var rewards := [] # where validated rewards are stored
		
		# Going through each entry, making sure the formats are right and
		# no IDs are reused. Validated items are stored and later assigned
		# to the context for use later.
		for i in range(items.size()):
			var item = items[i]
			var reward = Reward.new()
			# ensure element is a dictionary
			if not typeof(item) == TYPE_DICTIONARY:
				error_messages.append("Item %s in REWARDS field is: %s. Expected: %s" % [type_string(typeof(item)), type_string(TYPE_DICTIONARY)])
				continue
			
			var has_valid_id : bool = false
			var has_valid_img_uri : bool = false
			var has_valid_flavor_text : bool = false
			var has_valid_initial_count : bool = false
			var has_valid_capsule_color : bool = false
			
			# Iterating through each key
			for key : String in item:
				match key.to_lower():
					"id":
						# Ensure id is unique
						if reward_ids.has(item[key]):
							error_messages.append("Duplicate [ID] found in [REWARDS] at item %s" % i)
							continue
						reward.id = String(item[key])
						has_valid_id = true
						reward_ids.set(item[key], true) # Value is just filler. Dict is used as hashset
					"img_uri":
						if not typeof(item[key]) == TYPE_STRING:
							error_messages.append("%s provided for [IMG_URI] in REWARDS at item %s. Expected: %s" % [type_string(typeof(item[key])), i, type_string(TYPE_STRING)])
							continue
						if not FileAccess.file_exists(item[key]):
							error_messages.append("File not found for [IMG_URI] in [REWARDS] at item %s" % i)
							continue
						reward.img_uri = item[key]
						has_valid_img_uri = true
					"flavor_text":
						# this just needs to be present
						reward.flavor_text = String(item[key])
						has_valid_flavor_text = true
					"initial_count":
						# to_native converts numbers to floats. we'll cast to int later
						if not typeof(item[key]) == TYPE_FLOAT: 
							error_messages.append("Number expected for [INITIAL_COUNT] in [REWARDS] at item %s, %s found instead" % [i, type_string(typeof(item[key]))])
							continue
						if int(item[key]) <= 0:
							error_messages.append("Number greater than 0 expected for [INITIAL_COUNT] in [REWARDS] at item %s, %s found instead" % [i, int(item[key])])
							continue
						print("next line breaks")
						print(int(item[key]))
						reward.remaining_count = int(item[key])
						has_valid_initial_count = true
					"capsule_color":
						if not typeof(item[key]) == TYPE_STRING: 
							error_messages.append("%s provided for [CAPSULE_COLOR] in [REWARDS] at item %s. Expected: %s" % [type_string(typeof(item[key])), i, type_string(TYPE_STRING)])
							continue
						var result = color_regex.search(item[key])
						if not result:
							error_messages.append("Invalid hex color provided for [CAPSULE_COLOR] in [REWARDS] at item %s" % [i])
							continue
						reward.capsule_color = item[key]
						has_valid_capsule_color = true
					_:
						error_messages.append("Invalid index [%s] in [REWARDS] at item %s" % [key, i])
			
			# Check that all fields are present. If so, instantiate object and add to collection.
			# Otherwise, notify user to fix issues
			if not (has_valid_id and has_valid_img_uri and has_valid_flavor_text and has_valid_initial_count and has_valid_capsule_color):
				error_messages.append("One or more errors/missing fields in [REWARDS]")
				return json_context.format_error_response(error_messages)
			
			rewards.append(reward)
		
		json_context.rewards = rewards
	
	if error_messages.size() > 0:
		return json_context.format_error_response(error_messages)
	
	# I can't think of anything else that needs to be checked. The context should
	# be set up now and ready for routing.
	return await next(json_context)
