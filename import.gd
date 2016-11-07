tool

extends WindowDialog

var error_popup
var file_dialog
var file_name
var node_name_line_edit
var corres_array = []

const FLIPPED_HORIZONTALLY_FLAG = 0x80000000
const FLIPPED_VERTICALLY_FLAG   = 0x40000000
const FLIPPED_DIAGONALLY_FLAG   = 0x20000000

var only_used_tiles


func _ready():
	error_popup = get_node("ImportButton/ErrorPopup")
	file_dialog = get_node("SelectFileButton/FileDialog")
	file_name = get_node("FileName")
	node_name_line_edit = get_node("NodeNameLineEdit")
	popup_centered()

func createTileset(var data, var cell_size, var onlyused, var layers): # data = tileset_data = map_data[tilesets]
	var ts = TileSet.new()
	var size = cell_size

	if (onlyused) : #create a list containing the ids of all the Tiled tilesets tiles which are effectively used in the map
		for l in layers:
			var i = 0
			for y in range(0, l["height"]):
				for x in range(0, l["width"]):
					#get the gid as a string first, to prevent rounding error
					var strgid = str(l["data"][i])
					var gid = int(strgid)
					if (gid != 0):
						#read the flags from gid
						var flipped_horizontally = (gid & FLIPPED_HORIZONTALLY_FLAG)
						var flipped_vertically = (gid & FLIPPED_VERTICALLY_FLAG)
						var flipped_diagonally = (gid & FLIPPED_DIAGONALLY_FLAG)
						#clear the flags to get the actual tile id
						#print("\n before the rotation flags are cleared it is : ", gid)
						gid &= ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)

						corres_array.append(gid)
					i += 1

	for t in data:
		var path = file_name.get_text().get_base_dir() + "/" + t["image"]
		var file = File.new()
		if (!file.file_exists(path)):
			showPopup("couldn't find the tileset: " + path)
			return false
		var texture = load(path)
		texture.set_flags(0)
		var width = texture.get_width()
		width -= width % int(cell_size.x)
		var height = texture.get_height()
		height -= height % int(cell_size.y)
		var count = t["firstgid"]
		var spacing
		if t.has("spacing"):
			spacing = t["spacing"]
		else:
			spacing = 0
		var margin
		if t.has("margin"):
			margin = t["margin"]
		else:
			margin = 0
		var tiles
		if t.has("tiles"):
			tiles = t["tiles"]
		for y in range(margin, height, cell_size.y + spacing):
			for x in range(margin, width, cell_size.x + spacing):
				var intcount = int(count)
				if ( !onlyused || ( onlyused && ( corres_array.find(intcount) != -1))): #when onlyused is true, the tile from Tiled tileset is imported in Godot tileset only if it is used in the map
					var xy = Vector2(x, y)
					var rect = Rect2(xy, size)
					ts.create_tile(count)
					ts.tile_set_texture(count, texture)
					ts.tile_set_region(count, rect)
					var id = str(count - int(t["firstgid"]))

					if t.has("tiles"):
						for tile in tiles:
							if tile == id and tiles[tile].has("objectgroup"):
								for obj in tiles[tile]["objectgroup"]["objects"]:
									if !obj.has("polyline") and !obj.has("polygon") and !obj.has("ellipse"):
										var w = obj["width"]
										var h = obj["height"]
										var xx = obj["x"]
										var yy = obj["y"]
										var rectshape = RectangleShape2D.new()
										rectshape.set_extents(Vector2(w/2, h/2))
										ts.tile_set_shape(count, rectshape)
										ts.tile_set_shape_offset(count, Vector2(w/2 + xx, h/2 + yy))
									elif obj.has("ellipse"):
										var w = obj["width"]
										var h = obj["height"]
										var xx = obj["x"]
										var yy = obj["y"]
										if w == h:
											var circleshape = CircleShape2D.new()
											circleshape.set_radius(w/2)
											ts.tile_set_shape(count, circleshape)
											ts.tile_set_shape_offset(count, Vector2(w/2 + xx, h/2 + yy))
										else:
											var capsuleshape = CapsuleShape2D.new()
											capsuleshape.set_radius(w/2)
											capsuleshape.set_height(h/2)
											ts.tile_set_shape(count, capsuleshape)
											ts.tile_set_shape_offset(count, Vector2(w/2 + xx, h/2 + yy))
									elif obj.has("polygon"):
										var polygonshape = ConvexPolygonShape2D.new()
										var vectorarray = Vector2Array()

										var xx = obj["x"]
										var yy = obj["y"]

										for point in obj["polygon"]:
											vectorarray.push_back(Vector2(point["x"] + xx, point["y"] + yy))

										polygonshape.set_points(vectorarray)
										ts.tile_set_shape(count, polygonshape)
										ts.tile_set_shape_offset(count, Vector2(0, 0))
									elif obj.has("polyline"):
										var polygonshape = ConcavePolygonShape2D.new()
										var vectorarray = Vector2Array()

										var xx = obj["x"]
										var yy = obj["y"]

										for point in obj["polyline"]:
											vectorarray.push_back(Vector2(point["x"] + xx, point["y"] + yy))

										polygonshape.set_segments(vectorarray)
										ts.tile_set_shape(count, polygonshape)
										ts.tile_set_shape_offset(count, Vector2(0, 0))
				count += 1

	return ts

func showPopup(text):
	print(text)
	error_popup.get_node('Label').set_text(text)
	error_popup.popup_centered()

func _on_ImportButton_pressed():
	var root_node = get_tree().get_edited_scene_root()
	if root_node == null:
		return showPopup("No root node found. Please add one before trying to import a tiled map")
	var json = File.new()
	if (json.file_exists(file_name.get_text())):
		json.open(file_name.get_text(), 1)
	else:
		return showPopup("The map file " + file_name.get_text() + " seems to not exist.")
	var map_data = {}
	var err = map_data.parse_json(json.get_as_text())
	if (err != OK):
		return showPopup("Error parsing the map file. Please make sure it's in a valid format. Currently only .json is supported")

	var tilemap_root = Node2D.new()
	print(node_name_line_edit.get_text())
	if !node_name_line_edit.get_text().empty():
		tilemap_root.set_name(node_name_line_edit.get_text())
	else:
		tilemap_root.set_name("Tile map")

	var layers = map_data["layers"]

	var tileset_data = map_data["tilesets"]
	var cell_size = Vector2(map_data["tilewidth"], map_data["tileheight"])
	var tileset = createTileset(tileset_data, cell_size, only_used_tiles, layers)

	if(!tileset):
		print("Something went wrong while creating the tileset. Make sure all files are at the right path")
		return false

	root_node.add_child(tilemap_root)
	tilemap_root.set_owner(root_node)

	var mode = TileMap.MODE_SQUARE
	if map_data["orientation"] == "isometric":
		mode = TileMap.MODE_ISOMETRIC

	for l in layers:
		print(l)
		var layer_map = TileMap.new()
		tilemap_root.add_child(layer_map)
		layer_map.set_owner(root_node)
		layer_map.set_name(l["name"])
		layer_map.set_cell_size(cell_size)
		layer_map.set_tileset(tileset)
		layer_map.set_opacity(l["opacity"])
		layer_map.set_mode(mode)
		# Sets the Z property if defined in the layer
		if (l.has("properties") and l["properties"].has("z-order") and l["properties"]["z-order"].is_valid_integer()):
			layer_map.set_z(int(l["properties"]["z-order"]))
		# Sets the offsets property if defined in the layer
		var offset = Vector2(0, 0)
		if (l.has("offsetx")):
		  offset.x = int(l["offsetx"])
		if (l.has("offsety")):
		  offset.y = int(l["offsety"])
		layer_map.set_pos(offset)
		var i = 0
		for y in range(0, l["height"]):
			for x in range(0, l["width"]):
				#get the gid as a string first, to prevent rounding error
				var strgid = str(l["data"][i])
				var gid = int(strgid)

				if (gid != 0):
					#read the flags from gid
					var flipped_horizontally = (gid & FLIPPED_HORIZONTALLY_FLAG)
					var flipped_vertically = (gid & FLIPPED_VERTICALLY_FLAG)
					var flipped_diagonally = (gid & FLIPPED_DIAGONALLY_FLAG)

					#clear the flags to get the actual tile id
					gid &= ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)
					layer_map.set_cell(x, y, gid, flipped_horizontally, flipped_vertically)
				i += 1

	return showPopup("Succesfully imported the map")

func _on_FileDialog_file_selected( path ):
	file_name.set_text(path)

func _on_SelectFileButton_pressed():
	file_dialog.popup_centered()

# the checkbox "import only used tiles" is connected with this function through a signal
func _on_UsedTilesCheckBox_toggled( pressed ):
	if (pressed):
		only_used_tiles = true
	else:
		only_used_tiles = false

func _on_ExternalCheckBox_toggled( pressed ):
	if pressed:
		file_dialog.set_access(2) # File system
	else:
		file_dialog.set_access(0) # Resources

func _on_CloseButton_pressed():
	error_popup.set_hidden(true)

func _on_CancelButton_pressed():
	queue_free()
