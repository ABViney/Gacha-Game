@abstract
extends Node
class_name Middleware

var _next_middleware : Middleware

func _init(next_middleware : Middleware = null) -> void:
	_next_middleware = next_middleware

# overwrite this in inheritors
@abstract
func invoke(json_context : JSONContext) -> String

func next(json_context : JSONContext) -> String:
	if _next_middleware == null:
		return JSON.stringify(json_context.response.data)
	@warning_ignore("redundant_await")
	return await _next_middleware.invoke(json_context)
