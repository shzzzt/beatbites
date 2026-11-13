class_name PauseMenu
extends CanvasLayer
# Pause button + pause panel (mockup 06). Level.gd adds this to every level and
# decides what pausing means (offline: freeze the game; online: keeps going).

signal opened
signal resumed
signal restart_requested
signal quit_requested

const SOUND_ON_COLOR := Color("#3E7A12")
const SOUND_OFF_COLOR := Color("#B02C6C")

var online: bool = false # Set by Level before adding this node.

@onready var pause_button: Button = $PauseButton
@onready var overlay: Control = $Overlay
@onready var restart_button: Button = %Restart
@onready var quit_button: Button = %Quit


func _ready() -> void:
	overlay.hide()
	pause_button.pressed.connect(open)
	%Resume.pressed.connect(close)
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	%Sound.pressed.connect(_on_sound_pressed)
	quit_button.pressed.connect(func() -> void: quit_requested.emit())

	# You can't pause the other phone, so online has no Restart and keeps running.
	restart_button.visible = not online
	%Note.visible = online
	quit_button.text = "LEAVE MATCH" if online else "QUIT TO MENU"
	update_sound_chip()

	# Android's back button opens this menu instead of closing the app.
	get_tree().quit_on_go_back = false


func _exit_tree() -> void:
	get_tree().quit_on_go_back = true # Menus outside levels use the normal back.


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay.visible:
			close()
		else:
			open()
	elif what == NOTIFICATION_APPLICATION_PAUSED and not online:
		open() # The phone went to the home screen or got a call.


# Level fills in the "LV 3 · Snack · 23 / 40 bites" line when the menu opens.
func set_info(text: String) -> void:
	%Info.text = text


func open() -> void:
	if overlay.visible or not pause_button.visible:
		return # Already open, or pausing is switched off.
	overlay.show()
	pause_button.hide()
	opened.emit()


func close() -> void:
	if not overlay.visible:
		return
	overlay.hide()
	pause_button.show()
	resumed.emit()


# Level calls this when the attempt ends, so nobody pauses a finished level.
func disable() -> void:
	overlay.hide()
	pause_button.hide()


func _on_sound_pressed() -> void:
	GameState.toggle_sound()
	update_sound_chip()


func update_sound_chip() -> void:
	%ChipText.text = "ON" if GameState.sound_on else "OFF"
	%ChipText.add_theme_color_override("font_color",
		SOUND_ON_COLOR if GameState.sound_on else SOUND_OFF_COLOR)
