extends Control

@onready var tree: Tree = $Tree
@onready var root = tree.create_item()

func _ready() -> void:
	tree.hide_root = true
	
	var child1 = tree.create_item(root)
	var child2 = tree.create_item(root)
	var subchild1 = tree.create_item(child1)
	
	subchild1.set_text(0, "Subchild1")

	var dir = DirAccess.open(get_home_directory())
	if dir:
		dir.list_dir_begin()
		while true:
			var file_name = dir.get_next()
			if file_name == "":
				break
			print(file_name)
		dir.list_dir_end()

func get_home_directory() -> String:
	var home := OS.get_environment("HOME")
	if home.is_empty():
		home = OS.get_environment("USERPROFILE")
	return home
