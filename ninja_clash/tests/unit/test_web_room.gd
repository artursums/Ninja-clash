extends GutTest

const Room = preload("res://web_room.gd")

func test_invite_accepts_code_or_link_without_using_the_supplied_server() -> void:
	assert_eq(Room.parse_room(" abcdef012345 "), "ABCDEF012345")
	assert_eq(Room.parse_room("https://game.example/#room=abcdef012345"), "ABCDEF012345")
	assert_eq(Room.parse_room("https://game.example/?room=ABCDEF012345&other=yes"), "ABCDEF012345")

func test_invalid_invites_do_not_become_connection_attempts() -> void:
	for value in ["", "127.0.0.1", "ABC123", "ZZZZZZZZZZZZ", "ABCDEF0123456", "https://example.com/", "javascript:alert(1)"]:
		assert_eq(Room.parse_room(value), "", value)

func test_json_peer_ids_preserve_existing_connections() -> void:
	var room = Room.new()
	room._active = true
	room._host = true
	room._action = "exchange"
	var connection = RefCounted.new()
	room.links[2] = {"connection": connection, "outgoing": [], "peer_ready": false, "cursor": 0}
	room._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(),
		'{"peers":[2],"links":[{"peer":2,"ack":0,"peerReady":true,"messages":[]}]}'.to_utf8_buffer())
	assert_same(room.links[2].connection, connection)
	assert_true(room.links[2].peer_ready)
	room.free()

class ConnectionStub extends RefCounted:
	func get_gathering_state() -> int:
		return WebRTCPeerConnection.GATHERING_STATE_COMPLETE

func test_signaling_waits_until_the_server_acknowledges_our_connected_state() -> void:
	var room = Room.new()
	var link = {"connection": ConnectionStub.new(), "connected": true, "peer_ready": true,
		"ready_acked": false, "outgoing": [], "cursor": 0}
	room.links[2] = link
	assert_false(room._settled(link))
	room._active = true
	room._request_body = {"links": [{"peer": 2, "ready": true}]}
	room._on_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(),
		'{"peers":[2],"links":[{"peer":2,"ack":0,"peerReady":true,"messages":[]}]}'.to_utf8_buffer())
	assert_true(link.ready_acked)
	assert_true(room._settled(link))
	room.free()
