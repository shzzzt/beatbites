"""Generates assets/ui_theme.tres (the shared UI theme). Run from the project folder:
    python tools/make_theme.py assets/ui_theme.tres
Edit the colors/sizes below, re-run, then reopen the project in Godot."""
import sys

def c(hexstr, a=1.0):
    h = hexstr.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.6g}, {g:.6g}, {b:.6g}, {a:.6g})"

PURPLE = "#5B4494"
INK = "#3B2A66"
MUTED = "#6B58A0"
SHADOW = "#D9C8F5"

subs = []  # (id, type, props)

def box(id_, bg, border=None, bw=8, shadow=None, soff=12, m=(16, 16, 16, 16), border_a=1.0):
    p = [
        f"content_margin_left = {m[0]:.1f}", f"content_margin_top = {m[1]:.1f}",
        f"content_margin_right = {m[2]:.1f}", f"content_margin_bottom = {m[3]:.1f}",
        f"bg_color = {c(bg)}",
    ]
    if border and bw > 0:
        p += [f"border_width_left = {bw}", f"border_width_top = {bw}",
              f"border_width_right = {bw}", f"border_width_bottom = {bw}",
              f"border_color = {c(border, border_a)}"]
    if shadow:
        p += [f"shadow_color = {c(shadow)}", "shadow_size = 1", f"shadow_offset = Vector2(0, {soff})"]
    subs.append((id_, "StyleBoxFlat", p))
    return id_

def empty(id_):
    subs.append((id_, "StyleBoxEmpty", []))
    return id_

items = []  # resource lines

def button_variation(name, bg, pressed_bg, *, base=True, border=PURPLE, shadow=SHADOW, m=16, bw=8):
    n = box(f"{name}Normal", bg, border, bw, shadow, 12, (m, m, m, m))
    pr = box(f"{name}Pressed", pressed_bg, border, bw, shadow, 4 if shadow else 0, (m, m, m, m))
    prefix = "Button" if name == "Pink" else name
    if prefix != "Button":
        items.append(f'{prefix}/base_type = &"Button"')
    items.append(f'{prefix}/styles/normal = SubResource("{n}")')
    items.append(f'{prefix}/styles/hover = SubResource("{n}")')
    items.append(f'{prefix}/styles/pressed = SubResource("{pr}")')
    items.append(f'{prefix}/styles/hover_pressed = SubResource("{pr}")')
    return prefix

def panel_variation(name, sb_id, base="PanelContainer"):
    if name != base:
        items.append(f'{name}/base_type = &"{base}"')
    items.append(f'{name}/styles/panel = SubResource("{sb_id}")')

def label_variation(name, *, font=None, size=None, color=None, shadow=None, soff=None, base="Label"):
    items.append(f'{name}/base_type = &"{base}"')
    if color:
        items.append(f"{name}/colors/font_color = {c(color)}")
    if shadow:
        items.append(f"{name}/colors/font_shadow_color = {c(shadow)}")
        items.append(f"{name}/constants/shadow_offset_x = {soff}")
        items.append(f"{name}/constants/shadow_offset_y = {soff}")
    if size:
        items.append(f"{name}/font_sizes/font_size = {size}")
    if font:
        items.append(f'{name}/fonts/font = {font}')

TITLE_FONT = 'ExtResource("2_title")'
SEMI_FONT = 'SubResource("BodySemiBold")'

# ---------------- Buttons ----------------
button_variation("Pink", "#FFCCE5", "#FFC0DF")
button_variation("BlueButton", "#BFE2FF", "#B2DAFF")
button_variation("PurpleButton", "#DCCCFF", "#D0BFFA")
button_variation("WhiteButton", "#FFFFFF", "#F6F0FF")
button_variation("PaleButton", "#F6F0FF", "#EFE4FF")
button_variation("IconButton", "#EFE4FF", "#DCCCFF", m=20)
# Tap zones (gameplay): no shadow, pastel borders.
for name, bg, border, pressed in (("TapZoneLeft", "#EAF5FF", "#C7E6FF", "#C7E6FF"),
                                  ("TapZoneRight", "#FFEFF7", "#FFC9E3", "#FFC9E3")):
    n = box(f"{name}Normal", bg, border, 8, None, 0)
    p = box(f"{name}Pressed", pressed, border, 8, None, 0)
    items += [f'{name}/base_type = &"Button"',
              f'{name}/styles/normal = SubResource("{n}")', f'{name}/styles/hover = SubResource("{n}")',
              f'{name}/styles/pressed = SubResource("{p}")', f'{name}/styles/hover_pressed = SubResource("{p}")']
# Locked meal card: flat lilac, the dashed border is drawn by a DashedLine (box mode) child.
lk = box("LockedCardStyle", "#F3ECFC", None, 0, None, 0, (16, 16, 16, 16))
items += ['LockedCard/base_type = &"Button"',
          f'LockedCard/styles/normal = SubResource("{lk}")', f'LockedCard/styles/disabled = SubResource("{lk}")',
          f'LockedCard/styles/hover = SubResource("{lk}")', f'LockedCard/styles/pressed = SubResource("{lk}")']

disabled = box("Disabled", "#EDE6F5", PURPLE, 8, None, 0, border_a=0.45)
focus = empty("Empty")
items += [
    f"Button/colors/font_color = {c(INK)}",
    f"Button/colors/font_disabled_color = {c(INK, 0.45)}",
    f"Button/colors/font_focus_color = {c(INK)}",
    f"Button/colors/font_hover_color = {c(INK)}",
    f"Button/colors/font_hover_pressed_color = {c(INK)}",
    f"Button/colors/font_pressed_color = {c(INK)}",
    "Button/colors/icon_hover_color = Color(1, 1, 1, 1)",
    "Button/colors/icon_pressed_color = Color(1, 1, 1, 1)",
    "Button/font_sizes/font_size = 24",
    f"Button/fonts/font = {TITLE_FONT}",
    f'Button/styles/disabled = SubResource("{disabled}")',
    f'Button/styles/focus = SubResource("{focus}")',
]

# ---------------- Panels ----------------
panel_variation("PanelContainer", box("WhitePanel", "#FFFFFF", PURPLE, 8, SHADOW, 12, (32, 32, 32, 32)))
panel_variation("HudPanel", box("HudPanelStyle", "#FFFFFF", PURPLE, 8, None, 0, (24, 16, 24, 16)))
panel_variation("InfoPanel", box("InfoPanelStyle", "#F6F0FF", "#E3D4FF", 8, None, 0, (24, 20, 24, 20)))
panel_variation("HintPanel", box("HintPanelStyle", "#EFE4FF", PURPLE, 8, None, 0, (24, 24, 24, 24)))
panel_variation("ErrorPanel", box("ErrorPanelStyle", "#FFEAF4", "#E26AA6", 8, "#F5D0E3", 12, (32, 28, 32, 32)))
panel_variation("SuccessPanel", box("SuccessPanelStyle", "#F1FBE6", "#8FD14F", 8, None, 0, (28, 20, 28, 20)))
for name, bg, border in (("TilePink", "#FFEFF7", "#FFC9E3"), ("TileBlue", "#EAF5FF", "#C7E6FF"),
                         ("TileLilac", "#F6F0FF", "#E3D4FF"), ("TileYellow", "#FFF6DB", "#FFE3A0")):
    panel_variation(name, box(f"{name}Style", bg, border, 6, None, 0, (24, 16, 24, 16)))
for name, bg, border in (("NumBlue", "#BFE2FF", PURPLE), ("NumPurple", "#DCCCFF", PURPLE),
                         ("NumPink", "#FFCCE5", PURPLE), ("NumLocked", "#E6DAFA", "#C9B6EE")):
    panel_variation(name, box(f"{name}Style", bg, border, 8, None, 0, (0, 0, 0, 0)))
panel_variation("ChipPanel", box("ChipPanelStyle", "#FFFFFF", PURPLE, 6, None, 0, (16, 6, 16, 6)))
# Throw meter boxes (plain Panel nodes).
panel_variation("ThrowOn", box("ThrowOnStyle", "#FFD66B", PURPLE, 4, None, 0, (0, 0, 0, 0)), base="Panel")
panel_variation("ThrowOff", box("ThrowOffStyle", "#EFE4FF", "#C9B6EE", 4, None, 0, (0, 0, 0, 0)), base="Panel")

# ---------------- Progress bars ----------------
pb_bg = box("BarBackground", "#EFE4FF", PURPLE, 4, None, 0, (0, 0, 0, 0))
pb_fill = box("BarFill", "#8CCBFF", None, 0, None, 0, (0, 0, 0, 0))
tug_bg = box("TugBackground", "#FF9ACD", PURPLE, 4, None, 0, (0, 0, 0, 0))
items += [f'ProgressBar/styles/background = SubResource("{pb_bg}")',
          f'ProgressBar/styles/fill = SubResource("{pb_fill}")',
          'TugBar/base_type = &"ProgressBar"',
          f'TugBar/styles/background = SubResource("{tug_bg}")',
          f'TugBar/styles/fill = SubResource("{pb_fill}")']

# ---------------- Slider (Settings volume) ----------------
track = box("SliderTrack", "#EFE4FF", PURPLE, 4, None, 0, (0, 10, 0, 10))
track_fill = box("SliderFill", "#8CCBFF", PURPLE, 4, None, 0, (0, 10, 0, 10))
items += [f'HSlider/styles/slider = SubResource("{track}")',
          f'HSlider/styles/grabber_area = SubResource("{track_fill}")',
          f'HSlider/styles/grabber_area_highlight = SubResource("{track_fill}")',
          'HSlider/icons/grabber = ExtResource("3_grabber")',
          'HSlider/icons/grabber_highlight = ExtResource("3_grabber")']

# ---------------- Scrollbar (Credits list) ----------------
sb_track = box("ScrollTrack", "#EFE4FF", None, 0, None, 0, (6, 0, 6, 0))
sb_grab = box("ScrollGrabber", "#DCCCFF", PURPLE, 4, None, 0, (6, 0, 6, 0))
sb_grab_hi = box("ScrollGrabberHi", "#FFCCE5", PURPLE, 4, None, 0, (6, 0, 6, 0))
items += [f'VScrollBar/styles/scroll = SubResource("{sb_track}")',
          f'VScrollBar/styles/grabber = SubResource("{sb_grab}")',
          f'VScrollBar/styles/grabber_highlight = SubResource("{sb_grab_hi}")',
          f'VScrollBar/styles/grabber_pressed = SubResource("{sb_grab_hi}")']

# ---------------- LineEdit ----------------
field = box("Field", "#F6F0FF", PURPLE, 8, None, 0, (24, 8, 24, 8))
items += [f"LineEdit/colors/font_color = {c(INK)}",
          f"LineEdit/colors/font_placeholder_color = {c(MUTED, 0.75)}",
          "LineEdit/font_sizes/font_size = 36",
          f'LineEdit/styles/focus = SubResource("{focus}")',
          f'LineEdit/styles/normal = SubResource("{field}")']

# ---------------- Labels ----------------
items.append(f"Label/colors/font_color = {c(INK)}")
label_variation("TitleLabel", font=TITLE_FONT, size=40, color=INK)
label_variation("LogoLabel", font=TITLE_FONT, size=32, color="#D9468F", shadow="#FFE0EF", soff=6)
label_variation("HeroLabel", font=TITLE_FONT, size=48, color="#D9468F", shadow="#C7E6FF", soff=6)
label_variation("SectionLabel", font=TITLE_FONT, size=24, color=MUTED)
label_variation("CardTitle", font=TITLE_FONT, size=32, color=INK)
label_variation("CardBody", font=SEMI_FONT, size=32, color=INK)
label_variation("MutedLabel", size=32, color=MUTED)
label_variation("SmallMuted", size=28, color=MUTED)
label_variation("MealName", font=SEMI_FONT, size=40, color=INK)
label_variation("StatValue", font=SEMI_FONT, size=48, color=INK)
label_variation("ScoreLabel", font=TITLE_FONT, size=32, color="#C23B80")
label_variation("TinyPixel", font=TITLE_FONT, size=16, color=MUTED)

# ---------------- Write ----------------
out = ['[gd_resource type="Theme" format=3]', "",
       '[ext_resource type="FontFile" path="res://assets/fonts/PixelifySans-VariableFont_wght.ttf" id="1_body"]',
       '[ext_resource type="FontFile" path="res://assets/fonts/PressStart2P-Regular.ttf" id="2_title"]',
       '[ext_resource type="Texture2D" path="res://assets/art/ui_slider_grabber.png" id="3_grabber"]', "",
       '[sub_resource type="FontVariation" id="BodySemiBold"]',
       'base_font = ExtResource("1_body")',
       "variation_opentype = {", "2003265652: 600", "}", ""]
for id_, typ, props in subs:
    out.append(f'[sub_resource type="{typ}" id="{id_}"]')
    out += props
    out.append("")
out += ["[resource]", 'default_font = ExtResource("1_body")', "default_font_size = 28"]
out += sorted(items)
open(sys.argv[1], "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print(f"{len(subs)} styleboxes, {len(items)} theme items")
