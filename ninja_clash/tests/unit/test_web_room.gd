extends GutTest

const Room = preload("res://web_room.gd")

func test_invite_accepts_code_or_link_without_using_the_supplied_server() -> void:
	assert_eq(Room.parse_room(" abcdef012345 "), "ABCDEF012345")
	assert_eq(Room.parse_room("https://game.example/#room=abcdef012345"), "ABCDEF012345")
	assert_eq(Room.parse_room("https://game.example/?room=ABCDEF012345&other=yes"), "ABCDEF012345")

func test_invalid_invites_do_not_become_connection_attempts() -> void:
	for value in ["", "127.0.0.1", "ABC123", "ZZZZZZZZZZZZ", "ABCDEF0123456", "https://example.com/", "javascript:alert(1)"]:
		assert_eq(Room.parse_room(value), "", value)
