extends Node2D

# Listening Server
@onready var server : WebSocketServer = $WebSocketServer
@onready var machine : Machine = $Machine

# Middleware Pipeline
var middleware_pipeline : Middleware
var is_processing_message : bool #semaphore to manage response times
var message_queue : Array = [] # Queue for inbound messages to abate race conditions
var active_peers : Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect server signals
	server.client_connected.connect(_on_client_connected)
	server.message_received.connect(_on_message_recieved)
	server.client_disconnected.connect(_on_client_disconnected)
	
	# Connect EventBus signals
	EventBus.app_configured.connect(_on_app_configured)
	EventBus.rewards_modified.connect(_on_rewards_modified)
	
	var server_info_file := FileAccess.open("res://server_info.txt", FileAccess.READ)
	var port := int(server_info_file.get_line())
	var err = server.listen(port)
	if err != OK:
		print("Error listing on port %s" % port)
		return
	
	# Set up middleware pipeline
	middleware_pipeline = ValidateSchemaMiddleware.new(RoutingMiddleware.new())
	
	#region debug client window
	if (OS.is_debug_build()):
		# Create a window with an interface for testing requests/responses
		var client_window : Window = Window.new()
		client_window.title = "Websocket Client"
		client_window.mode = Window.MODE_WINDOWED
		client_window.size = Vector2i(800, 600)
		client_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
		client_window.close_requested.connect(func() : get_tree().quit()) # Close app
		
		# Instantiate the UI for this window
		var client : PackedScene = load("res://ext_client/client.tscn")
		var client_instance : ClientView  = client.instantiate()
		# Set up host field to point at server
		client_instance.ready.connect(func() : client_instance.host.text = "ws://localhost:%s" % port)
		
		client_window.add_child(client_instance)
		add_child(client_window)
		print("Created client window")
	#endregion
	
	print("listening on port %s" % port)
	
	_update_window_settings()
	print("Gacha spin ready")

func _process(_delta : float) -> void:
	if (not is_processing_message):
		if (message_queue.size() > 0):
			var message : JSONContext = message_queue.pop_front()
			_handle_message(message)

#region WebSocketServer Listeners
# When a client connects, notify them that they have connected
func _on_client_connected(peer_id : int):
	print("Client %s connected" % peer_id)
	active_peers.push_back(peer_id)
	server.send(peer_id, "Connection established" % peer_id)

# When a message is recieved by the server store its sender and data in the
# queue for processing
func _on_message_recieved(peer_id : int, message : String):
	print("Message recieved from: %s\n%s\n" % [peer_id, message])
	# convert message to JSON and handle
	# load message and sender into dictionary, store in queue
	message_queue.push_back(JSONContext.new(peer_id, message))

func _handle_message(json_context : JSONContext) -> void:
	is_processing_message = true # lock semaphore
	print("Processing message")
	var response : String = await middleware_pipeline.invoke(json_context) # process response
	print("Message processed")
	server.send(json_context.sender, response) # publish response
	is_processing_message = false # unlock semaphore

func _on_client_disconnected(peer_id : int):
	print("Client %s disconnected" % peer_id)
	active_peers.remove_at(active_peers.find(peer_id))
#endregion

#region Configuration
func _on_app_configured() -> void:
	print("Configuring window")
	_update_window_settings()

func _on_rewards_modified() -> void:
	await machine.fill_machine(RewardsPool.get_rewards())
#endregion

#region Helpers
func _update_window_settings():
	var window : Window = self.get_window()
	window.title = Configuration.window_title
	window.size = Vector2i(Configuration.window_width, Configuration.window_height)
	machine.set_music(Configuration.path_to_music)
#endregion
