extends RefCounted
class_name JSONContext

## A valid request to the gacha machine always has a [COMMAND] index.
## Requests have either:
### One index: 
#### If [COMMAND] is "CRANK" "KICK" or "GET_REWARDS"
## Two indexes:
### If [COMMAND] is "CONFIGURE" or "LOAD_MACHINE"
#### The second index will be [CONFIG] if [COMMAND] is "CONFIGURE"
#### or [REWARDS] if [COMMAND] is "LOAD_MACHINE"

# The peer that sent this message
var sender : int
# The raw request string
var raw_request : String
# The parsed request string
var request : Dictionary
# The formatted response
var response : Dictionary


# Recognized commands
enum Command {
	CONFIG, # Configure the app
	CRANK, # Retrieve a reward
	GET_REWARDS, # Get remaining rewards
	KICK, # Kick the app
	LOAD_MACHINE, # Load the app with new rewards
}


# Recognized indexes
var has_command_field : bool
var command : Command # Which command is specified

var has_config_field : bool
var config : AppConfig # Description of a new app configuration

var has_rewards_field : bool
var rewards : Array # Array of Rewards


func _init(peer_id : int, raw_json_request : String) -> void:
	sender = peer_id
	raw_request = raw_json_request


# Format and return an OK response
func format_ok_response(data : Dictionary = {} ) -> String:
	response.set("status", "ok")
	for key in data.keys():
		response.set(key, data[key])
	return JSON.stringify(response)

# Format and return an ERROR response
func format_error_response(error_messages : PackedStringArray) -> String:
	response.set("status", "error")
	response.set("error", ", ".join(error_messages))
	return JSON.stringify(response)
