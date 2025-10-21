extends RefCounted
class_name Reward

var id : String # ID to specify what reward this is
var img_uri : String # Path to an image on the system to represent this reward
var flavor_text : String # Flavor text to present w/ this reward
var remaining_count : int:
	get: return remaining_count
	set(value):
		if value >= 0:
			remaining_count = value
		else:
			remaining_count = 0
var capsule_color : Color # The color of the capsule this reward comes in
