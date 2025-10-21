extends Node2D
class_name Machine

var audio_loader := AudioLoader.new()
var music := AudioStreamPlayer.new()

var is_busy : bool

func _ready() -> void:
	#self.visible = false
	EventBus.machine_cranked.connect(_on_machine_cranked)

#region Machine animations
func _on_machine_cranked(reward : Reward) -> void:
	print_debug("Machine cranked")
	music.play()
	self.visible = true
	
	if reward == null:
		push_error("Reward was null")
	
	await get_tree().create_timer(2.0).timeout
	
	# Animate machine dropping the reward
	
	
	
	# inform that reward has dropped and is displaying
	EventBus.reward_presented.emit()
	
	await get_tree().create_timer(1.0).timeout
	
	await music.finished
	self.visible = false
	# inform that machine is ready for next animation
	EventBus.machine_ready.emit()


func _on_machine_empty() -> void:
	print_debug("Machine empty")
	# play a sound


func _on_machine_kicked() -> void:
	print_debug("Machine kicked")
	# play a sound
#endregion

#region Public Helpers
func fill_machine(rewards : Array):
	pass


func set_music(path_to_music):
	# Load music from disc
	music.set_stream(audio_loader.loadfile(path_to_music))
#endregion
