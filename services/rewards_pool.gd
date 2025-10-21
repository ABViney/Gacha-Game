extends Node

## Singleton service for handling state, persistence, and retrieval of Rewards

var _REWARDS_POOL_FILE_PATH := "res://rewards_pool.cfg"
var _REWARD_SECTION_TITLE := "reward_%s" # template
var _REWARD_ID := "id"
var _REWARD_IMG_URI := "img_uri"
var _REWARD_FLAVOR_TEXT := "flavor_text"
var _REWARD_COUNT := "count"
var _REWARD_CAPSULE_COLOR := "capsule_color"

var _REWARD_DEFAULT_ID := "MISSING"
var _REWARD_DEFAULT_IMG_URI := str("res://images/missing_texture.png")
var _REWARD_DEFAULT_FLAVOR_TEXT := str("This field is missing (teehee)")
var _REWARD_DEFAULT_COUNT := int(0)
var _REWARD_DEFAULT_CAPSULE_COLOR := "#FFFFFF"

var rewards_pool : Array

func _ready() -> void:
	print("Setting up redeems")
	_load_reward_pool_from_disc()
	get_tree().get_root()
	EventBus.rewards_modified.connect(_save_reward_pool_to_disc)

func set_reward_pool(new_rewards : Array) -> void:
	rewards_pool = new_rewards
	EventBus.rewards_modified.emit()

func _load_reward_pool_from_disc() -> void:
	var rewards_pool_file = ConfigFile.new()
	var err := rewards_pool_file.load(_REWARDS_POOL_FILE_PATH)
	if err != OK:
		print_debug("%s not found" % _REWARDS_POOL_FILE_PATH)
		return
	
	var i = 0
	while rewards_pool_file.has_section(_REWARD_SECTION_TITLE % str(i)):
		var reward := Reward.new()
		
		# Sections iterate numerically. At some point we'll run out
		var section := _REWARD_SECTION_TITLE % str(i)
		if not rewards_pool_file.has_section(section):
			break
		
		reward.id = rewards_pool_file.get_value(section, _REWARD_ID, _REWARD_DEFAULT_ID)
		reward.img_uri = rewards_pool_file.get_value(section, _REWARD_IMG_URI, _REWARD_DEFAULT_IMG_URI)
		reward.flavor_text = rewards_pool_file.get_value(section, _REWARD_IMG_URI, _REWARD_DEFAULT_FLAVOR_TEXT)
		reward.remaining_count = rewards_pool_file.get_value(section, _REWARD_COUNT, _REWARD_DEFAULT_COUNT)
		reward.capsule_color = rewards_pool_file.get_value(section, _REWARD_CAPSULE_COLOR, _REWARD_DEFAULT_CAPSULE_COLOR)
		
		rewards_pool.append(reward)
		i+=1
	
	print("Reward pool loaded from disc")


func _save_reward_pool_to_disc() -> void:
	var rewards_pool_file = ConfigFile.new()
	for i : int in range(rewards_pool.size()):
		var section_title = _REWARD_SECTION_TITLE % str(i)
		var reward : Reward = rewards_pool[i]
		rewards_pool_file.set_value(section_title, _REWARD_ID, reward.id)
		rewards_pool_file.set_value(section_title, _REWARD_IMG_URI, reward.img_uri)
		rewards_pool_file.set_value(section_title, _REWARD_FLAVOR_TEXT, reward.flavor_text)
		#TODO: if jane wants the same pool to be used every time/every launch, we'll need a seperate
		#TODO: value for INITIAL_COUNT
		rewards_pool_file.set_value(section_title, _REWARD_COUNT, reward.remaining_count)
		rewards_pool_file.set_value(section_title, _REWARD_CAPSULE_COLOR, reward.capsule_color)
	var error := rewards_pool_file.save(_REWARDS_POOL_FILE_PATH)
	if error != OK:
		print_debug("Failed to save rewards pool")
	else:
		print("Rewards pool saved to disc")


func get_total_rewards_count() -> int:
	var total_rewards = 0
	for item : Reward in rewards_pool:
		total_rewards += item.remaining_count
	return total_rewards


func get_rewards() -> Array:
	return rewards_pool # plz don't mutate my array


# Populate the fields of the reward with the fields of the reward pulled
func pop_reward() -> Variant:
	
	# Get the sum of all rewards
	var total_rewards = get_total_rewards_count()
	
	# If the machine is empty then nothing was pulled
	if total_rewards == 0:
		return null
	
	# To get a prize, generate a random integer between 1 and the total number
	# of prizes. Then I can iterate through the prize pool, counting the number 
	# of remaining rewards for each category, and returning the one that 
	# intercepts where the random number is:
	# e.g. common = 200, rare = 50, legendary = 10
	# num = randi(1, 200+50+10)
	# num 1-200 = common
	# num 201-250 = rare
	# num 251-260 = legendary
	# The rarity of each reward type will fluctuate as that reward or other 
	# rewards are pulled, which will make the machine 'feel' more fair.
	# The caveat is that the machine must be refilled occasionally
	
	# We'll use a random number to determine what the reward will be
	var rng = randi_range(1, total_rewards)
	var reward_range := 0 # keeps track of which reward pool we're in
	
	# Use this as a reference to what reward we'll return
	var reward_type : Reward
	
	# Iterating through rewards again to find where the random number landed
	# For each reward type, we sum the remaining count and add it to the range.
	# Once that range intercepts the random number generated earlier, we've 
	# found what type of reward will be returned 
	for item : Reward in rewards_pool:
		reward_type = item
		reward_range += item.remaining_count
		if rng <= reward_range:
			break
	
	reward_type.remaining_count -= 1 # Remove one of these from the pool
	EventBus.rewards_modified.emit() # async update the updated rewards pool on disc
	return reward_type
