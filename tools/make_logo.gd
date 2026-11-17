extends Node
# Renders Beat Bites' logo images into assets/branding/ from the game's own
# pixel art. Run it with the normal (not headless) Godot, from the project folder:
#   Godot_..._console.exe --path . res://tools/LogoMaker.tscn
# It opens a window for a moment, saves the PNGs and quits.
#
# Outputs:
#   icon_512.png              app icon (project icon / desktop window)
#   icon_192.png              classic Android launcher icon
#   icon_foreground_432.png   Android adaptive icon: art layer (transparent)
#   icon_background_432.png   Android adaptive icon: background layer
#   logo_banner.png           1280×640 banner for the README
#
# The icon is drawn on a 64×64 grid of "logical pixels" and then scaled by a
# whole number (8 → 512, 3 → 192), so the pixel art stays crisp.

const OUT_DIR: String = "res://assets/branding/"
const CATCHER = preload("res://assets/art/catcher_idle.png")
const APPLE = preload("res://assets/art/good_apple.png")
const BLUEBERRY = preload("res://assets/art/good_blueberry.png")
const DONUT = preload("res://assets/art/good_donut.png")
const CANDY = preload("res://assets/art/good_candy.png")
const PRESS_START = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const PIXELIFY = preload("res://assets/fonts/PixelifySans-VariableFont_wght.ttf")

const PINK_BG := Color("#FFCCE5")
const PINK_GLOW := Color("#FFE6F2")
const LAVENDER := Color("#FBF4FF")
const OUTLINE := Color("#5B4494")
const TITLE_PINK := Color("#D9468F")
const TITLE_BLUE := Color("#2F7FD1")
const BACK_LILAC := Color("#E3D4FF")
const SHADOW_BLUE := Color("#C7E6FF")
const SHADOW_PINK := Color("#FFC9E3")
const MUTED := Color("#6B58A0")
const SPARKLE_COLORS: Array[Color] = [Color.WHITE, Color("#BFE2FF"), Color("#F2B230"), Color("#DCCCFF")]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await render("icon_512.png", Vector2i(512, 512), true, func(root: Control) -> void:
		build_icon(root, 8, true))
	await render("icon_192.png", Vector2i(192, 192), true, func(root: Control) -> void:
		build_icon(root, 3, true))
	# Adaptive icon: Android crops it to a circle/squircle, so the art is
	# smaller (5 units) and centered, staying inside the safe zone.
	await render("icon_foreground_432.png", Vector2i(432, 432), true, func(root: Control) -> void:
		var art := Control.new()
		art.position = Vector2(56, 56) # (432 - 64×5) / 2
		root.add_child(art)
		build_icon(art, 5, false))
	await render("icon_background_432.png", Vector2i(432, 432), false, func(root: Control) -> void:
		add_rect(root, Rect2(0, 0, 432, 432), PINK_BG)
		add_glow(root, Vector2(216, 236), 150.0))
	await render("logo_banner.png", Vector2i(1280, 640), false, build_banner)
	print("Logo images saved to ", ProjectSettings.globalize_path(OUT_DIR))
	get_tree().quit()


# Draws `build` into an off-screen viewport of `size` and saves it as a PNG.
func render(file: String, size: Vector2i, transparent: bool, build: Callable) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	var root := Control.new()
	root.size = Vector2(size)
	viewport.add_child(root)
	build.call(root)
	# Wait until the viewport has really been drawn.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	print("saved ", file, " ", size)
	viewport.queue_free()


# The icon art on a 64×64 grid, scaled by `unit`:
# rounded pink tile (optional), soft glow, sparkles, and the axolotl
# balancing an apple on its head.
func build_icon(root: Control, unit: int, with_tile: bool) -> void:
	var u: float = unit
	if with_tile:
		var tile := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = PINK_BG
		style.border_color = OUTLINE
		style.set_border_width_all(int(2 * u))
		style.set_corner_radius_all(int(14 * u))
		tile.add_theme_stylebox_override("panel", style)
		tile.size = Vector2(64, 64) * u
		root.add_child(tile)
		add_glow(root, Vector2(32, 37) * u, 21 * u)
	for spot in [Vector3(12, 14, 0), Vector3(51, 12, 1), Vector3(53, 42, 2), Vector3(10, 44, 3)]:
		add_sparkle(root, Vector2(spot.x, spot.y) * u, u, SPARKLE_COLORS[int(spot.z)])
	add_sprite(root, APPLE, Vector2(24, 12) * u, u) # 16×16 apple...
	add_sprite(root, CATCHER, Vector2(16, 29) * u, u) # ...on the 32×24 axolotl's head.


func build_banner(root: Control) -> void:
	add_rect(root, Rect2(0, 0, 1280, 640), LAVENDER)
	# Sparkles scattered around (positions in pixels, size unit 6).
	var spots: Array[Vector2] = [
		Vector2(70, 80), Vector2(1190, 70), Vector2(560, 60), Vector2(1220, 560),
		Vector2(60, 560), Vector2(640, 590), Vector2(430, 300), Vector2(980, 600),
	]
	for i in spots.size():
		add_sparkle(root, spots[i], 6.0, SPARKLE_COLORS[i % SPARKLE_COLORS.size()])
	# Left: glow, axolotl ×10 with the apple ×6 on its head, more food falling.
	add_glow(root, Vector2(270, 380), 210.0)
	add_sprite(root, APPLE, Vector2(222, 140), 6.0)
	add_sprite(root, CATCHER, Vector2(110, 236), 10.0)
	add_sprite(root, BLUEBERRY, Vector2(70, 150), 5.0)
	add_sprite(root, DONUT, Vector2(400, 110), 5.0)
	add_sprite(root, CANDY, Vector2(1130, 210), 5.0)
	# Right: the layered title from the title screen, bigger.
	add_title(root, "BEAT", Vector2(500, 150), TITLE_PINK, SHADOW_BLUE)
	add_title(root, "BITES", Vector2(500, 300), TITLE_BLUE, SHADOW_PINK)
	var tagline := Label.new()
	tagline.add_theme_font_override("font", PIXELIFY)
	tagline.add_theme_font_size_override("font_size", 44)
	tagline.add_theme_color_override("font_color", MUTED)
	tagline.text = "Catch the beat. Eat the beat."
	tagline.position = Vector2(504, 470)
	root.add_child(tagline)


# "BEAT" / "BITES": lilac copy 16 px behind, front word with an 8 px shadow.
func add_title(root: Control, word: String, at: Vector2, color: Color, shadow: Color) -> void:
	for layer in 2:
		var label := Label.new()
		label.add_theme_font_override("font", PRESS_START)
		label.add_theme_font_size_override("font_size", 120)
		label.text = word
		if layer == 0:
			label.position = at + Vector2(16, 16)
			label.add_theme_color_override("font_color", BACK_LILAC)
		else:
			label.position = at
			label.add_theme_color_override("font_color", color)
			label.add_theme_color_override("font_shadow_color", shadow)
			label.add_theme_constant_override("shadow_offset_x", 8)
			label.add_theme_constant_override("shadow_offset_y", 8)
		root.add_child(label)


func add_sprite(root: Control, texture: Texture2D, at: Vector2, scale: float) -> void:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = at
	sprite.size = Vector2(texture.get_size()) * scale
	root.add_child(sprite)


func add_rect(root: Control, rect: Rect2, color: Color) -> void:
	var box := ColorRect.new()
	box.color = color
	box.position = rect.position
	box.size = rect.size
	root.add_child(box)


# A soft lighter circle behind the character.
func add_glow(root: Control, center: Vector2, radius: float) -> void:
	var glow := Control.new()
	glow.size = root.size
	glow.draw.connect(func() -> void: glow.draw_circle(center, radius, PINK_GLOW))
	root.add_child(glow)


# A pixel "plus" sparkle, 3 units tall and wide.
func add_sparkle(root: Control, center: Vector2, unit: float, color: Color) -> void:
	add_rect(root, Rect2(center + Vector2(-0.5, -1.5) * unit, Vector2(1, 3) * unit), color)
	add_rect(root, Rect2(center + Vector2(-1.5, -0.5) * unit, Vector2(3, 1) * unit), color)
