class_name WebSocketServer
extends Node

signal message_received(peer_id: int, message: String)
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)

@export var handshake_timout := 3000

class PendingPeer:
	var connect_time: int
	var tcp: StreamPeerTCP
	var connection: StreamPeer
	var ws: WebSocketPeer

	func _init(p_tcp: StreamPeerTCP) -> void:
		tcp = p_tcp
		connection = p_tcp
		connect_time = Time.get_ticks_msec()


var tcp_server := TCPServer.new()
var pending_peers: Array[PendingPeer] = []
var peers: Dictionary


func listen(port: int) -> int:
	assert(not tcp_server.is_listening())
	return tcp_server.listen(port)


func stop() -> void:
	tcp_server.stop()
	pending_peers.clear()
	peers.clear()


func send(peer_id: int, message: String) -> int:
	var type := typeof(message)
	if peer_id <= 0:
		# Send to multiple peers, (zero = broadcast, negative = exclude one).
		for id: int in peers:
			if id == -peer_id:
				continue
			if type == TYPE_STRING:
				peers[id].send_text(message)
			else:
				peers[id].put_packet(message)
		return OK

	assert(peers.has(peer_id))
	var socket: WebSocketPeer = peers[peer_id]
	if type == TYPE_STRING:
		return socket.send_text(message)
	return socket.send(var_to_bytes(message))


func get_message(peer_id: int) -> Variant:
	assert(peers.has(peer_id))
	var socket: WebSocketPeer = peers[peer_id]
	if socket.get_available_packet_count() < 1:
		return null
	var pkt: PackedByteArray = socket.get_packet()
	if socket.was_string_packet():
		return pkt.get_string_from_utf8()
	return bytes_to_var(pkt)


func has_message(peer_id: int) -> bool:
	assert(peers.has(peer_id))
	return peers[peer_id].get_available_packet_count() > 0


func poll() -> void:
	if not tcp_server.is_listening():
		return

	while tcp_server.is_connection_available():
		var conn: StreamPeerTCP = tcp_server.take_connection()
		assert(conn != null)
		pending_peers.append(PendingPeer.new(conn))

	var to_remove := []

	for p in pending_peers:
		if not _connect_pending(p):
			if p.connect_time + handshake_timout < Time.get_ticks_msec():
				to_remove.append(p)
			continue  # Still pending.

		to_remove.append(p)

	for r: RefCounted in to_remove:
		pending_peers.erase(r)

	to_remove.clear()

	for id: int in peers:
		var p: WebSocketPeer = peers[id]
		p.poll()

		if p.get_ready_state() != WebSocketPeer.STATE_OPEN:
			client_disconnected.emit(id)
			to_remove.append(id)
			continue

		while p.get_available_packet_count():
			message_received.emit(id, get_message(id))

	for r: int in to_remove:
		peers.erase(r)
	to_remove.clear()


func _create_peer() -> WebSocketPeer:
	var ws := WebSocketPeer.new()
	#ws.supported_protocols = supported_protocols
	#ws.handshake_headers = handshake_headers
	return ws


func _connect_pending(p: PendingPeer) -> bool:
	if p.ws != null:
		# Poll websocket client if doing handshake.
		p.ws.poll()
		var state := p.ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			var id := randi_range(2, 1 << 30)
			peers[id] = p.ws
			client_connected.emit(id)
			return true  # Success.
		elif state != WebSocketPeer.STATE_CONNECTING:
			return true  # Failure.
		return false  # Still connecting.
	elif p.tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return true  # TCP disconnected.
	else:
		# TCP is ready, create WS peer.
		p.ws = _create_peer()
		p.ws.accept_stream(p.tcp)
		return false  # WebSocketPeer connection is pending.


func _process(_delta: float) -> void:
	poll()
