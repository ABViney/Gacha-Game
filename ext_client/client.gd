extends Control
class_name ClientView

@onready var _client: WebSocketClient = $WebSocketClient
@onready var _log_dest: RichTextLabel = $Panel/VBoxContainer/RichTextLabel
@onready var _line_edit: CodeEdit = $Panel/VBoxContainer/Send/LineEdit
@onready var host: LineEdit = $Panel/VBoxContainer/Connect/Host

func info(msg: String) -> void:
	print(msg)
	_log_dest.add_text(str(msg) + "\n")


#region Client signals
func _on_web_socket_client_connection_closed() -> void:
	var ws := _client.get_socket()
	info("Client just disconnected with code: %s, reason: %s" % [ws.get_close_code(), ws.get_close_reason()])


func _on_web_socket_client_connected_to_server() -> void:
	info("Client connected to: %s" % _client.get_socket().get_connected_host())


func _on_web_socket_client_message_received(message: String) -> void:
	info("%s" % message)
#endregion

#region UI signals
func _on_send_pressed() -> void:
	if _line_edit.text.is_empty():
		return

	info("Sending message: %s" % [_line_edit.text])
	_client.send(_line_edit.text)
	_line_edit.text = ""


func _on_connect_toggled(pressed: bool) -> void:
	if not pressed:
		_client.close()
		return

	if host.text.is_empty():
		return

	info("Connecting to host: %s." % [host.text])
	var err := _client.connect_to_url(host.text)
	if err != OK:
		info("Error connecting to host: %s. Error code: %s" % [host.text, err])
		return
#endregion
