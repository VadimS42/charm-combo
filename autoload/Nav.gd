## Nav.gd (autoload singleton, registered in project.godot as "Nav")
##
## Keyboard and controller play (round 16, for Steam Deck and gamepads). The
## game is built for the mouse, but every screen can also be played with keys
## or a pad:
##   arrows / D-pad / left stick   move the focus ring between buttons
##   Enter, Space / A              press the focused button
##   Backspace / B                 back (close a dialog or Settings, leave a list)
##   Esc / Start                   open or close Settings
##   1 / RB, 2 / X, 3 / Y          +3 Moves, Hammer, Shuffle in a chapter
##   Page Up/Down / right stick    scroll long pages (Credits, Achievements)
## The focus ring and the button hints in the top bar only show while you're
## using keys or a pad ("nav mode"). The moment the mouse moves, clicks or the
## screen is touched, they disappear again, so mouse play looks exactly as it
## did before.
##
## Screens tell Main which control to focus first and what "back" does
## (Main.nav_setup()); this file only tracks the mode and owns the actions.
extends Node

signal mode_changed(nav: bool)

## True while the player is using keys or a gamepad.
var nav_mode := false
## Whether the last key/button press came from a gamepad (hint labels show
## "A" instead of "Enter", and the mouse pointer hides).
var gamepad := false

const JOY_DEADZONE := 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_actions()


func _setup_actions() -> void:
	# Godot's ui_accept has no gamepad button out of the box.
	_add_event("ui_accept", _joy(JOY_BUTTON_A))
	_add_action("cc_back", [_key(KEY_BACKSPACE), _joy(JOY_BUTTON_B)])
	_add_action("cc_pause", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])
	_add_action("cc_item_moves", [_key(KEY_1), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	_add_action("cc_item_hammer", [_key(KEY_2), _joy(JOY_BUTTON_X)])
	_add_action("cc_item_shuffle", [_key(KEY_3), _joy(JOY_BUTTON_Y)])
	# Dialogue (VNScreen): hold to skip read lines, Auto, the Log, hide text.
	_add_action("cc_skip", [_key(KEY_CTRL), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	_add_action("cc_auto", [_key(KEY_A), _joy(JOY_BUTTON_Y)])
	_add_action("cc_log", [_key(KEY_L), _joy(JOY_BUTTON_LEFT_SHOULDER)])
	_add_action("cc_hide", [_key(KEY_H), _joy(JOY_BUTTON_X)])
	_add_action("cc_scroll_up", [_key(KEY_PAGEUP), _axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add_action("cc_scroll_down", [_key(KEY_PAGEDOWN), _axis(JOY_AXIS_RIGHT_Y, 1.0)])


func _add_action(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, JOY_DEADZONE)
	for e in events:
		_add_event(action, e)


func _add_event(action: String, e: InputEvent) -> void:
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	return e


static func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# A real movement, not the tiny synthetic motion some systems send.
		if nav_mode and (event as InputEventMouseMotion).relative.length() > 3.0:
			_set_mode(false, gamepad)
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.is_pressed():
			_set_mode(false, gamepad)
	elif event is InputEventJoypadButton:
		if event.is_pressed():
			_nav_input(true, event)
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if m.axis <= JOY_AXIS_RIGHT_Y and absf(m.axis_value) >= JOY_DEADZONE:
			_nav_input(true, event)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and _is_nav_key(k.keycode):
			_nav_input(false, event)


func _nav_input(pad: bool, event: InputEvent) -> void:
	var was_nav := nav_mode
	_set_mode(true, pad)
	var vp := get_viewport()
	var owner := vp.gui_get_focus_owner()
	if owner == null or not owner.is_visible_in_tree():
		# Nothing focused yet (fresh screen, or focus was on something that's
		# gone): put the ring on the screen's first control, and don't let
		# this press also act on it.
		if focus_default() and (_is_direction(event) or event.is_action("ui_accept")):
			vp.set_input_as_handled()
	elif not was_nav and _is_direction(event):
		# First direction press after using the mouse: show where the focus
		# is instead of moving it somewhere unexpected.
		vp.set_input_as_handled()


## Puts focus on the current screen's preferred control (Main decides which:
## an open confirm box, Settings, or the screen's own default). True if it did.
func focus_default() -> bool:
	var main := get_tree().current_scene
	if main == null or not main.has_method("default_focus_control"):
		return false
	var c = main.default_focus_control()
	if c is Control and is_instance_valid(c) and c.is_visible_in_tree() \
			and (c as Control).focus_mode != Control.FOCUS_NONE:
		(c as Control).grab_focus()
		return true
	return false


func _set_mode(on: bool, pad: bool) -> void:
	if on == nav_mode and pad == gamepad:
		return
	nav_mode = on
	gamepad = pad
	UITheme.set_rings_visible(on)
	if DisplayServer.get_name() != "headless":
		if on and pad:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		elif Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mode_changed.emit(on)


static func _is_nav_key(code: int) -> bool:
	return code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB, KEY_ENTER, KEY_KP_ENTER,
		KEY_SPACE, KEY_BACKSPACE, KEY_PAGEUP, KEY_PAGEDOWN, KEY_1, KEY_2, KEY_3]


static func _is_direction(event: InputEvent) -> bool:
	for a in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		if event.is_action(a):
			return true
	return false


## The key or button name to show for a hint ("A" on a gamepad, "Enter" on a
## keyboard). Deck and Xbox pads share the A/B/X/Y names.
func glyph(what: String) -> String:
	match what:
		"accept": return "A" if gamepad else "Enter"
		"back": return "B" if gamepad else "Backspace"
		"pause": return "Start" if gamepad else "Esc"
		"move": return "D-pad" if gamepad else "Arrows"
		"moves": return "RB" if gamepad else "1"
		"hammer": return "X" if gamepad else "2"
		"shuffle": return "Y" if gamepad else "3"
		"scroll": return "Right stick" if gamepad else "PgUp/PgDn"
		"skip": return "RB (hold)" if gamepad else "Ctrl (hold)"
		"auto": return "Y" if gamepad else "A"
		"log": return "LB" if gamepad else "L"
		"hide": return "X" if gamepad else "H"
	return what
