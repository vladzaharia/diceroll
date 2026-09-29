extends RefCounted
## App-icon scenarios for the screenshot harness (tools/shot.gd). Art lives in tools/icon/.
##  app_icon        the shipped icon (IconArt.FINAL), full-bleed square
##  icon_<concept>  every concept (IconArt.CONCEPTS: hero, hero_dark, solo, tumble, doubles, knight, orbit, tile)
## Render square, in the background only:
##   tools/shoot.sh app_icon /abs/icon.png 1024x1024 --wait=2
## tools/icon/build_icons.sh (tools/export.sh icon) renders + derives every icon asset.

const ART := preload("res://tools/icon/icon_art.gd")


static func names() -> PackedStringArray:
	var out := PackedStringArray(["app_icon"])
	for c in ART.CONCEPTS:
		out.append("icon_" + c)
	return out


static func build(name: String) -> Node:
	var concept := ""
	if name == "app_icon":
		concept = ART.FINAL
	elif name.begins_with("icon_") and name.substr(5) in ART.CONCEPTS:
		concept = name.substr(5)
	else:
		return null
	var n: Control = ART.new()
	n.concept = concept
	return n
