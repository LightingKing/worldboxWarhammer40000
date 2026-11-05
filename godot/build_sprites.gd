extends SceneTree

## Turns art/sprites/<civ>.json into WorldBox unit frames.
##
## For each civ it writes, under
## src/FortyKBox/GameResources/actors/species/civs/<id>/:
##   main/   adult body: walk_N.png, walk_N_item.png grip markers,
##           generated swim_N.png and the NML sprites.json
##   child/  the same for the optional child body
## plus the species icon, and art/preview/<id>.png for review.
## See art/SPRITE_SPEC.md.

const RESERVED := {
	"K0": "#FF00FF", "K1": "#DE00DE", "K2": "#A700A7", "K3": "#7F007F", "K4": "#580058",
	"J0": "#00EFEF", "J1": "#00DBDB", "J2": "#00BCBC", "J3": "#009E9E", "J4": "#007777",
	"S0": "#B8FF96", "S1": "#00FF00", "S2": "#00AF00", "S3": "#4A831F",
	"L": "#FFD800",
}
const WATER_LINE := "#D1E3EB"
const MARKER := "#FF0000"
const SWIM_DROP := 3
const PREVIEW_SCALE := 8

# Vanilla human building sizes; the footprint on the map is fixed, so the
# art must stay within BUILDING_SLACK px of these. See art/BUILDING_SPEC.md.
const BUILDING_SIZES := {
	"tent": Vector2i(8, 8), "house_0": Vector2i(14, 13), "house_1": Vector2i(15, 16),
	"house_2": Vector2i(16, 18), "house_3": Vector2i(18, 18), "house_4": Vector2i(23, 19),
	"house_5": Vector2i(24, 24), "hall_0": Vector2i(29, 24), "hall_1": Vector2i(29, 30),
	"hall_2": Vector2i(33, 33), "watch_tower": Vector2i(11, 25), "barracks": Vector2i(28, 29),
	"temple": Vector2i(24, 33),
}
const BUILDING_SLACK := 2
# Map icon (mini_0) sizes, as vanilla.
const MINI_SIZES := {
	"tent": Vector2i(5, 3), "house_0": Vector2i(3, 3), "house_1": Vector2i(3, 3), "house_2": Vector2i(3, 3),
	"house_3": Vector2i(5, 3), "house_4": Vector2i(7, 3), "house_5": Vector2i(7, 3),
	"hall_0": Vector2i(7, 5), "hall_1": Vector2i(7, 5), "hall_2": Vector2i(7, 5),
	"watch_tower": Vector2i(3, 2), "barracks": Vector2i(7, 5), "temple": Vector2i(5, 4),
}
const RUBBLE := "#6E6A64"
const SCAFFOLD := "#8A5A2B"
const SCAFFOLD_DARK := "#5E3C1C"

# Preview schemes: kingdom ramp, secondary ramp, skin ramp.
const SCHEMES := [
	[["#E0473C", "#C93A30", "#A32D25", "#7F221C", "#5C1814"], ["#F2D16B", "#DDBB55", "#BF9E40", "#9A7F30", "#735E22"], ["#F2C79B", "#D9A87A", "#B5855C", "#8A6243"]],
	[["#4A7BD6", "#3D68B8", "#305495", "#244072", "#192D52"], ["#E6E6E6", "#CCCCCC", "#A8A8A8", "#858585", "#616161"], ["#C68B5E", "#A87248", "#875A37", "#634128"]],
	[["#E8C13A", "#CFA82E", "#AA8A24", "#86691A", "#614B12"], ["#2E2E2E", "#262626", "#1E1E1E", "#161616", "#0E0E0E"], ["#8FCB5A", "#6FAE40", "#538A2E", "#3B6620"]],
]

var _root := ""
var _errors: Array[String] = []


func _init() -> void:
	_root = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var sprite_dir := _root.path_join("art/sprites")
	var built := 0
	for file in DirAccess.get_files_at(sprite_dir):
		if not file.ends_with(".json") or file.begins_with("_"):
			continue
		if _build_civ(sprite_dir.path_join(file)):
			built += 1
	var building_dir := _root.path_join("art/buildings")
	var building_sets := 0
	if DirAccess.dir_exists_absolute(building_dir):
		for file in DirAccess.get_files_at(building_dir):
			if file.ends_with(".json") and not file.begins_with("_") and _build_buildings(building_dir.path_join(file)):
				building_sets += 1
	for error in _errors:
		printerr(error)
	print("Built %d civ sprite set(s) and %d building set(s), %d error(s)." % [built, building_sets, _errors.size()])
	quit(1 if _errors.size() > 0 else 0)


func _fail(source: String, message: String) -> void:
	_errors.append("%s: %s" % [source.get_file(), message])


func _build_civ(path: String) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		_fail(path, "not a JSON object")
		return false
	var id: String = data.get("id", "")
	if not id.is_valid_identifier():
		_fail(path, "missing or invalid id")
		return false
	var size: Array = data.get("size", [])
	if size.size() != 2:
		_fail(path, "size must be [width, height]")
		return false

	var palette = _parse_palette(path, data.get("palette", {}))
	if palette == null:
		return false

	var adult = _parse_set(path, "", data.get("frames", {}), int(size[0]), int(size[1]), palette, true)
	if adult == null:
		return false
	var sets := [adult]
	var civ_dir := _root.path_join("src/FortyKBox/GameResources/actors/species/civs/%s" % id)
	_write_set(civ_dir.path_join("main"), adult)

	# Optional child body on its own canvas, same palette. The game reads it
	# from <civ>/child when the species has a baby form.
	var child_dir := civ_dir.path_join("child")
	if data.has("child"):
		var child_data: Dictionary = data["child"]
		var child_size: Array = child_data.get("size", [])
		if child_size.size() != 2:
			_fail(path, "child.size must be [width, height]")
			return false
		var child = _parse_set(path, "child.", child_data.get("frames", {}), int(child_size[0]), int(child_size[1]), palette, false)
		if child == null:
			return false
		_write_set(child_dir, child)
		sets.append(child)
	elif DirAccess.dir_exists_absolute(child_dir):
		_clear_dir(child_dir)
		DirAccess.remove_absolute(child_dir)

	_write_preview(id, sets)
	_write_icon(id, adult["walk"][0])
	print("%s: %dx%d adult%s" % [id, int(size[0]), int(size[1]), ", child" if sets.size() > 1 else ""])
	return true


func _parse_palette(path: String, source: Dictionary):
	var palette := {}
	var reserved_hexes := RESERVED.values()
	for key in source:
		var value: String = source[key]
		if key.length() != 1:
			_fail(path, "palette key '%s' must be one character" % key)
			return null
		if value == "clear":
			palette[key] = Color(0, 0, 0, 0)
		elif RESERVED.has(value):
			palette[key] = Color.html(RESERVED[value])
		elif value.begins_with("#") and value.length() == 7 and Color.html_is_valid(value):
			if value.to_upper() in reserved_hexes or value.to_upper() == WATER_LINE:
				_fail(path, "palette '%s' uses reserved colour %s as a custom hex; use its key" % [key, value])
				return null
			palette[key] = Color.html(value)
		else:
			_fail(path, "palette '%s' has invalid value '%s'" % [key, value])
			return null
	return palette


## Reads walk_0..walk_N from a frames dictionary; null after an error.
## Adults need an item grip in every frame; for children it is optional and
## frames without one get no marker.
func _parse_set(path: String, label: String, frames: Dictionary, w: int, h: int, palette: Dictionary, require_item: bool):
	var walk := []
	var items := []
	while frames.has("walk_%d" % walk.size()):
		var name := label + "walk_%d" % walk.size()
		var frame: Dictionary = frames["walk_%d" % walk.size()]
		var rows: Array = frame.get("rows", [])
		if rows.size() != h:
			_fail(path, "%s has %d rows, expected %d" % [name, rows.size(), h])
			return null
		var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var row: String = rows[y]
			if row.length() != w:
				_fail(path, "%s row %d is %d wide, expected %d" % [name, y, row.length(), w])
				return null
			for x in w:
				var ch := row[x]
				if not palette.has(ch):
					_fail(path, "%s row %d uses undefined palette key '%s'" % [name, y, ch])
					return null
				image.set_pixel(x, y, palette[ch])
		if image.is_invisible():
			_fail(path, "%s is empty" % name)
			return null
		var item: Array = frame.get("item", [])
		if item.is_empty() and not require_item:
			items.append(null)
		elif item.size() != 2 or int(item[0]) < 0 or int(item[0]) >= w or int(item[1]) < 0 or int(item[1]) + 3 > h:
			_fail(path, "%s needs item [x, y] inside the canvas" % name)
			return null
		else:
			items.append(Vector2i(int(item[0]), int(item[1])))
		walk.append(image)
	if walk.size() < 4:
		_fail(path, "%sframes need walk_0..walk_3 with no gaps (found %d)" % [label, walk.size()])
		return null
	for key in frames:
		if not (key as String).begins_with("walk_") or int((key as String).trim_prefix("walk_")) >= walk.size():
			_fail(path, "unexpected frame '%s%s' (only contiguous walk_N frames are allowed)" % [label, key])
			return null
	return {"walk": walk, "items": items, "swim": []}


func _clear_dir(dir: String) -> void:
	for stale in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(stale))


## Writes one body sheet folder: walk frames, grip markers, generated swim
## frames, and the NML sprites.json with their pivots and marker rects.
func _write_set(out_dir: String, set: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_clear_dir(out_dir)
	var walk: Array = set["walk"]
	var items: Array = set["items"]
	var specific := []
	for i in walk.size():
		var frame: Image = walk[i]
		var w := frame.get_width()
		var h := frame.get_height()
		frame.save_png(out_dir.path_join("walk_%d.png" % i))

		if items[i] != null:
			# The game positions the held item from the marker sprite's rect
			# inside its texture, so the marker keeps the full canvas and the
			# rect in sprites.json selects the 1x3 grip column (bottom-origin).
			var grip: Vector2i = items[i]
			var marker := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
			for dy in 3:
				marker.set_pixel(grip.x, h - 1 - (grip.y + dy), Color.html(MARKER))
			marker.save_png(out_dir.path_join("walk_%d_item.png" % i))
			specific.append({
				"Path": "walk_%d_item.png" % i,
				"RectX": grip.x, "RectY": grip.y, "RectW": 1, "RectH": 3,
				"PivotX": 0.5, "PivotY": 0.175, "PixelsPerUnit": 1,
			})

		var swim_frame := _make_swim(frame)
		swim_frame.save_png(out_dir.path_join("swim_%d.png" % i))
		specific.append({"Path": "swim_%d.png" % i, "PivotX": 0.5, "PivotY": 0.1, "PixelsPerUnit": 1})
		set["swim"].append(swim_frame)

	var settings := {"Default": {"PivotX": 0.5, "PivotY": 0.0, "PixelsPerUnit": 1}, "Specific": specific}
	var settings_file := FileAccess.open(out_dir.path_join("sprites.json"), FileAccess.WRITE)
	settings_file.store_string(JSON.stringify(settings, "  "))
	settings_file.close()


## Species icon for the toolbar, knowledge window and kingdom lists:
## walk_0 in the civ's display colours (art/sprites/_icons.json), x2,
## outlined, on a 28x28 canvas like vanilla icons.
func _write_icon(id: String, frame: Image) -> void:
	var scheme: Array = SCHEMES[0]
	var schemes = JSON.parse_string(FileAccess.get_file_as_string(_root.path_join("art/sprites/_icons.json")))
	if typeof(schemes) == TYPE_DICTIONARY and schemes.has(id):
		var s: Dictionary = schemes[id]
		scheme = [s["K"], s["J"], s["S"]]
	var art := _recolour(frame, scheme)
	art.resize(frame.get_width() * 2, frame.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var icon := Image.create_empty(28, 28, false, Image.FORMAT_RGBA8)
	var origin := Vector2i((28 - art.get_width()) / 2, 28 - art.get_height() - 3)
	icon.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), origin)
	var outlined: Image = icon.duplicate()
	var outline := Color.html("#1C1C1C")
	for y in 28:
		for x in 28:
			if icon.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.x < 28 and n.y >= 0 and n.y < 28 and icon.get_pixel(n.x, n.y).a > 0.0:
					outlined.set_pixel(x, y, outline)
					break
	var icon_dir := _root.path_join("src/FortyKBox/GameResources/ui/Icons/w40k")
	DirAccess.make_dir_recursive_absolute(icon_dir)
	outlined.save_png(icon_dir.path_join("%s.png" % id))


## Sinks the figure about 40 % of its height (at most SWIM_DROP rows, at
## least one, so short bodies like scarabs stay visible) and draws a water
## line where it meets the surface, like vanilla swim frames.
func _make_swim(frame: Image) -> Image:
	var w := frame.get_width()
	var h := frame.get_height()
	var used := frame.get_used_rect()
	var drop := clampi(int(used.size.y * 0.4), 1, SWIM_DROP)
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h - 2 - drop, -1, -1):
		var target := y + drop
		if target > h - 3:
			continue
		for x in w:
			out.set_pixel(x, target, frame.get_pixel(x, y))
	for x in w:
		var touches := false
		for dx in [-1, 0, 1]:
			var sx: int = x + dx
			if sx >= 0 and sx < w and out.get_pixel(sx, h - 3).a > 0.0:
				touches = true
		if touches:
			out.set_pixel(x, h - 2, Color.html(WATER_LINE))
	return out


func _recolour(image: Image, scheme: Array) -> Image:
	var out: Image = image.duplicate()
	var map := {}
	for i in 5:
		map[RESERVED["K%d" % i]] = Color.html(scheme[0][i])
		map[RESERVED["J%d" % i]] = Color.html(scheme[1][i])
	for i in 4:
		map[RESERVED["S%d" % i]] = Color.html(scheme[2][i])
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var hex := "#" + c.to_html(false).to_upper()
			if map.has(hex):
				out.set_pixel(x, y, map[hex])
	return out


## Stacks one preview block per body (adult first, then child).
func _write_preview(id: String, sets: Array) -> void:
	var blocks := []
	var width := 0
	var height := 0
	for set in sets:
		var block := _preview_block(set)
		blocks.append(block)
		width = max(width, block.get_width())
		height += block.get_height()
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.html("#2B2F36"))
	var y := 0
	for block in blocks:
		var image: Image = block
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(0, y))
		y += image.get_height()
	var preview_dir := _root.path_join("art/preview")
	DirAccess.make_dir_recursive_absolute(preview_dir)
	sheet.save_png(preview_dir.path_join("%s.png" % id))


## Every walk and swim frame at x8 in each scheme, then a true-size strip
## (x3) on grass.
func _preview_block(set: Dictionary) -> Image:
	var walk: Array = set["walk"]
	var swim: Array = set["swim"]
	var items: Array = set["items"]
	var w: int = (walk[0] as Image).get_width()
	var h: int = (walk[0] as Image).get_height()
	var cell := Vector2i(w * PREVIEW_SCALE + 8, h * PREVIEW_SCALE + 8)
	var cols := walk.size() * 2
	var true_row := h * 3 + 8
	var sheet := Image.create_empty(cols * cell.x + 8, SCHEMES.size() * cell.y + true_row + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.html("#2B2F36"))
	for s in SCHEMES.size():
		for i in walk.size():
			for k in 2:
				var frame: Image = walk[i] if k == 0 else swim[i]
				var big := _recolour(frame, SCHEMES[s])
				if k == 0 and items[i] != null:
					# Grip marker preview: a dim red dot on the hand.
					var p: Vector2i = items[i]
					big.set_pixel(p.x, h - 1 - p.y, big.get_pixel(p.x, h - 1 - p.y).lerp(Color.RED, 0.6))
				big.resize(w * PREVIEW_SCALE, h * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
				var origin := Vector2i(8 + (i * 2 + k) * cell.x, 8 + s * cell.y)
				var bg := Color.html("#5E8F3A") if k == 0 else Color.html("#3C6FA8")
				sheet.fill_rect(Rect2i(origin, Vector2i(w * PREVIEW_SCALE, h * PREVIEW_SCALE)), bg)
				sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), origin)
	# True-size strip on grass, three schemes, enlarged x3 so it is visible
	# but still shows how little detail survives at game scale.
	var strip_y := 8 + SCHEMES.size() * cell.y
	sheet.fill_rect(Rect2i(Vector2i(8, strip_y), Vector2i(cols * cell.x - 8, h * 3)), Color.html("#5E8F3A"))
	for s in SCHEMES.size():
		for i in walk.size():
			var small := _recolour(walk[i], SCHEMES[s])
			small.resize(w * 3, h * 3, Image.INTERPOLATE_NEAREST)
			var origin := Vector2i(8 + (s * walk.size() + i) * (w * 3 + 4), strip_y)
			sheet.blend_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), origin)
	return sheet


## --- Buildings -------------------------------------------------------------

## Game id of a building key: house_2 -> house_<civ>_2, temple -> temple_<civ>.
func _building_id(key: String, civ: String) -> String:
	var parts := key.rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		return "%s_%s_%s" % [parts[0], civ, parts[1]]
	return "%s_%s" % [key, civ]


func _build_buildings(path: String) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		_fail(path, "not a JSON object")
		return false
	var id: String = data.get("id", "")
	if not id.is_valid_identifier():
		_fail(path, "missing or invalid id")
		return false
	var palette = _parse_palette(path, data.get("palette", {}))
	if palette == null:
		return false

	var built := {}
	var buildings: Dictionary = data.get("buildings", {})
	for key in buildings:
		if not BUILDING_SIZES.has(key):
			_fail(path, "unknown building '%s'" % key)
			return false
		var rows: Array = buildings[key].get("rows", [])
		var image = _rows_to_image(path, key, rows, palette)
		if image == null:
			return false
		var target: Vector2i = BUILDING_SIZES[key]
		if absi(image.get_width() - target.x) > BUILDING_SLACK or absi(image.get_height() - target.y) > BUILDING_SLACK:
			_fail(path, "%s is %dx%d, expected about %dx%d" % [key, image.get_width(), image.get_height(), target.x, target.y])
			return false
		built[key] = image

	var out_root := _root.path_join("src/FortyKBox/GameResources/buildings/civ_main/%s" % id)
	if DirAccess.dir_exists_absolute(out_root):
		for stale_dir in DirAccess.get_directories_at(out_root):
			_clear_dir(out_root.path_join(stale_dir))
			DirAccess.remove_absolute(out_root.path_join(stale_dir))

	var generated := {}
	for key in built:
		var main: Image = built[key]
		var dir := out_root.path_join(_building_id(key, id))
		DirAccess.make_dir_recursive_absolute(dir)
		var ruin := _make_ruin(main)
		var construction := _make_construction(main)
		var mini := _make_mini(main, MINI_SIZES[key])
		main.save_png(dir.path_join("main_0.png"))
		ruin.save_png(dir.path_join("ruin_0.png"))
		construction.save_png(dir.path_join("construction_0.png"))
		mini.save_png(dir.path_join("mini_0.png"))
		var settings := {
			"Default": {"PivotX": 0.5, "PivotY": 0.1, "PixelsPerUnit": 1},
			"Specific": [{"Path": "mini_0.png", "PivotX": 0.5, "PivotY": 0.5, "PixelsPerUnit": 1}],
		}
		var file := FileAccess.open(dir.path_join("sprites.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(settings, "  "))
		file.close()
		generated[key] = [main, ruin, construction, mini]

	_write_building_preview(id, generated)
	print("%s: %d buildings" % [id, built.size()])
	return true


func _rows_to_image(path: String, name: String, rows: Array, palette: Dictionary):
	if rows.is_empty():
		_fail(path, "%s has no rows" % name)
		return null
	var w: int = (rows[0] as String).length()
	var image := Image.create_empty(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		if row.length() != w:
			_fail(path, "%s row %d is %d wide, expected %d" % [name, y, row.length(), w])
			return null
		for x in w:
			if not palette.has(row[x]):
				_fail(path, "%s row %d uses undefined palette key '%s'" % [name, y, row[x]])
				return null
			image.set_pixel(x, y, palette[row[x]])
	if image.is_invisible():
		_fail(path, "%s is empty" % name)
		return null
	return image


func _is_key_colour(c: Color) -> bool:
	return ("#" + c.to_html(false).to_upper()) in RESERVED.values()


## Roof gone, jagged broken top, greyed and darkened; kingdom colour and
## lights become rubble, like a burnt-out vanilla ruin.
func _make_ruin(main: Image) -> Image:
	var used := main.get_used_rect()
	var out := Image.create_empty(main.get_width(), main.get_height(), false, Image.FORMAT_RGBA8)
	var cut := used.position.y + int(used.size.y * 0.45)
	for x in main.get_width():
		var jag := cut + int(abs(sin(x * 1.7)) * 3.0)
		for y in range(jag, main.get_height()):
			var c := main.get_pixel(x, y)
			if c.a == 0.0:
				continue
			if _is_key_colour(c):
				c = Color.html(RUBBLE)
			else:
				var grey := c.get_luminance()
				c = Color(lerpf(c.r, grey, 0.6), lerpf(c.g, grey, 0.6), lerpf(c.b, grey, 0.6)) * 0.7
				c.a = 1.0
			out.set_pixel(x, y, c)
	return out


## Bottom third of the building as foundation, wooden scaffold above it
## inside the outline of the finished building.
func _make_construction(main: Image) -> Image:
	var used := main.get_used_rect()
	var out := Image.create_empty(main.get_width(), main.get_height(), false, Image.FORMAT_RGBA8)
	var foundation := used.end.y - maxi(2, int(used.size.y * 0.3))
	for y in range(foundation, used.end.y):
		for x in range(used.position.x, used.end.x):
			var c := main.get_pixel(x, y)
			if c.a > 0.0:
				out.set_pixel(x, y, Color.html(RUBBLE) if _is_key_colour(c) else c)
	var wood := Color.html(SCAFFOLD)
	var dark := Color.html(SCAFFOLD_DARK)
	var left := used.position.x
	var right := used.end.x - 1
	var top := used.position.y + int(used.size.y * 0.25)
	var poles := [left, right, (left + right) / 2]
	for x in poles:
		for y in range(top, foundation):
			out.set_pixel(x, y, dark)
	for y in range(top, foundation, 4):
		for x in range(left, right + 1):
			out.set_pixel(x, y, wood)
	# One diagonal brace in the left bay.
	var bay: int = poles[2] - left
	for i in range(0, mini(bay, foundation - top)):
		out.set_pixel(left + i, foundation - 1 - i, wood)
	return out


## Map icon: the building squeezed into a few pixels, each the most common
## colour of its cell (kingdom colour keys stay, so the icon is tinted).
func _make_mini(main: Image, size: Vector2i) -> Image:
	var used := main.get_used_rect()
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for cy in size.y:
		for cx in size.x:
			var x0 := used.position.x + used.size.x * cx / size.x
			var x1 := used.position.x + used.size.x * (cx + 1) / size.x
			var y0 := used.position.y + used.size.y * cy / size.y
			var y1 := used.position.y + used.size.y * (cy + 1) / size.y
			var counts := {}
			var opaque := 0
			var total := 0
			for y in range(y0, maxi(y1, y0 + 1)):
				for x in range(x0, maxi(x1, x0 + 1)):
					total += 1
					var c := main.get_pixel(x, y)
					if c.a == 0.0:
						continue
					opaque += 1
					var hex := c.to_html(false)
					counts[hex] = counts.get(hex, 0) + 1
			if opaque * 3 < total:
				continue
			var best := ""
			for hex in counts:
				if best == "" or counts[hex] > counts[best]:
					best = hex
			out.set_pixel(cx, cy, Color.html(best))
	return out


## Every building x4 in each scheme, bottom-aligned, then the generated
## ruin / construction (x2) and map icon (x4) of each in the first scheme.
func _write_building_preview(id: String, generated: Dictionary) -> void:
	var scale := 4
	var keys := []
	for key in BUILDING_SIZES:
		if generated.has(key):
			keys.append(key)
	var row_h := 0
	var width := 8
	for key in keys:
		var main: Image = generated[key][0]
		row_h = maxi(row_h, main.get_height() * scale)
		width += main.get_width() * scale + 8
	var height := (SCHEMES.size() + 1) * (row_h + 8) + 8
	var sheet := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.html("#2B2F36"))
	for s in SCHEMES.size() + 1:
		var x := 8
		var y := 8 + s * (row_h + 8)
		sheet.fill_rect(Rect2i(Vector2i(8, y), Vector2i(width - 16, row_h)), Color.html("#5E8F3A"))
		for key in keys:
			var images: Array = generated[key]
			var main: Image = images[0]
			if s < SCHEMES.size():
				var big := _recolour(main, SCHEMES[s])
				big.resize(main.get_width() * scale, main.get_height() * scale, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(x, y + row_h - big.get_height()))
			else:
				var cx := x
				for i in [1, 2, 3]:
					var part: Image = _recolour(images[i], SCHEMES[0])
					var k := 4 if i == 3 else 2
					part.resize(part.get_width() * k, part.get_height() * k, Image.INTERPOLATE_NEAREST)
					sheet.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(cx, y + row_h - part.get_height()))
					cx += part.get_width() + 2
			x += main.get_width() * scale + 8
	var preview_dir := _root.path_join("art/preview")
	DirAccess.make_dir_recursive_absolute(preview_dir)
	sheet.save_png(preview_dir.path_join("buildings_%s.png" % id))
