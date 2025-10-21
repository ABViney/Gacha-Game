extends "res://middlewares/middelware.gd"
class_name RoutingMiddleware

var machine_is_busy := false

## GDScript doesn't have DI and I don't wanna fuddle w/ making a convoluted MVC 
## solution when all I'm really handling here is JSON and telling the screen 
## to do stuff occasionally

func invoke(json_context : JSONContext) -> String:
	var COMMAND = json_context.Command
	match json_context.command:
		COMMAND.CONFIG:
			# Update the config, notify the root so it can apply changes
			return update_config(json_context)
		COMMAND.CRANK:
			return await crank_machine(json_context)
		COMMAND.GET_REWARDS:
			return get_rewards(json_context)
		COMMAND.KICK:
			return kick_machine(json_context)
		COMMAND.LOAD_MACHINE:
			return load_machine(json_context)
		
	return json_context.format_error_response(["Unable to route request"])


#region Controllers* (as close as i'm getting in this project)
func update_config(json_context : JSONContext) -> String:
	Configuration.update_config(json_context.config)
	return json_context.format_ok_response()


func crank_machine(json_context : JSONContext) -> String:
	# Check that machine isn't empty
	var reward : Variant = RewardsPool.pop_reward()
	
	if reward == null:
		EventBus.machine_empty.emit()
		return json_context.format_error_response(["Machine is empty"])
	
	# Have the machine display this reward
	EventBus.machine_cranked.emit(reward)
	# NOTE this turns this function into a coroutine, requiring it be awaited upstream
	await EventBus.reward_presented # the reward was shown on screen
	
	# Return the reward to the client
	return json_context.format_ok_response({
		"reward_id" : reward.id,
		"remaining_count" : reward.remaining_count,
		"total_rewards_left" : RewardsPool.get_total_rewards_count()})


func kick_machine(json_context : JSONContext) -> String:
	EventBus.machine_kicked.emit()
	return json_context.format_ok_response()


func get_rewards(json_context : JSONContext) -> String:
	var rewards_json_array := []
	for reward : Reward in RewardsPool.get_rewards():
		var dict := {
			"id": reward.id,
			"img_uri": reward.img_uri,
			"flavor_text": reward.flavor_text,
			"remaining_count": reward.remaining_count,
			"capsule_color": "#%s" % reward.capsule_color.to_html(false)
		}
		rewards_json_array.append(dict)
	return json_context.format_ok_response({"rewards" : rewards_json_array})


func load_machine(json_context : JSONContext) -> String:
	RewardsPool.set_reward_pool(json_context.rewards)
	return json_context.format_ok_response({"message": "New rewards persisted"})
#endregion
