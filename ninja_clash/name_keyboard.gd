extends Control
## The dialog owns editing and focus; this component only provides the key layout.

const UI := preload("res://menu_ui.gd")
const LETTER_ROWS := ["1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
signal typed(value: String)
signal erase_requested
var rows: Array = []
var uppercase := true
var _case_button: Button

func _ready() -> void:
	position = Vector2(166, 166)
	size = Vector2(468, 186)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row_index in LETTER_ROWS.size():
		var letters: String = LETTER_ROWS[row_index]
		var row: Array[Button] = []
		var left := (468.0 - (letters.length() * 47 - 5)) / 2
		for column in letters.length():
			var letter := letters[column]
			var key := UI.button(self, letter, Rect2(left + column * 47, row_index * 38, 42, 32), func(): typed.emit(letter if uppercase else letter.to_lower()), 20)
			key.focus_mode = Control.FOCUS_ALL
			row.append(key)
		rows.append(row)
	_case_button = UI.button(self, "abc", Rect2(0, 152, 96, 32), _toggle_case, 18)
	var space := UI.button(self, "SPACE", Rect2(104, 152, 190, 32), func(): typed.emit(" "), 18)
	var erase := UI.button(self, "DELETE", Rect2(302, 152, 166, 32), func(): erase_requested.emit(), 18)
	rows.append([_case_button, space, erase])
	for key in rows.back():
		key.focus_mode = Control.FOCUS_ALL

func reset_case() -> void:
	uppercase = true
	_refresh_case()

func _toggle_case() -> void:
	uppercase = not uppercase
	_refresh_case()
	Audio.play("click")

func _refresh_case() -> void:
	for i in LETTER_ROWS.size():
		for j in LETTER_ROWS[i].length():
			rows[i][j].text = LETTER_ROWS[i][j] if uppercase else LETTER_ROWS[i][j].to_lower()
	_case_button.text = "abc" if uppercase else "ABC"
