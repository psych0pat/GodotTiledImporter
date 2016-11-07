tool
extends EditorPlugin

var button = null
var window = null

func get_name():
	return "Tiled Importer"

func _enter_tree():
	button = Button.new()
	button.set_text("Import Tiled Map")
	button.connect("pressed",self,"_clickedButton")
	add_control_to_container(CONTAINER_TOOLBAR,button)

func _exit_tree():
	button.free()
	button = null

func _clickedButton():
	print('CLICK')
	#get_tree().change_scene("ImportTiled.tscn")
	window = preload("ImportTiled.tscn")
	#print(window)
	add_child(window.instance())
