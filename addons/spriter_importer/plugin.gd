@tool
extends EditorPlugin

var importer

func _enable_plugin() -> void:
	
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree() -> void:
	importer = preload("res://addons/spriter_importer/spriter_importer.gd").new()
	add_import_plugin(importer)

func _exit_tree() -> void:
	remove_import_plugin(importer)
