extends EditorImportPlugin

func _get_importer_name():
	return "spriter.importer"

func _get_visible_name():
	return "Spriter (.scon)"

func _get_recognized_extensions():
	return ["scon"]

func _get_save_extension():
	return "tscn"

func _get_resource_type():
	return "PackedScene"

func _get_import_options(path, preset):
	return []

func _import(source_file, save_path, options, platform_variants, gen_files):
	if source_file.ends_with(".scon"):
		
		var data = SpriterParserJSON.parse(source_file)
		var scenes = SpriterBuilder.build_scene(data)
		
		#print("--- SPRITER NORMALIZED DATA ---")
		#print(JSON.stringify(data, "\t"))
		
		
		if scenes.size() > 0:
			return ResourceSaver.save(scenes[0],save_path + ".tscn")
		return ERR_CANT_CREATE
		

	return ERR_SKIP
'''
func _import(source_file, save_path, options, platform_variants, gen_files):
	var data

	if source_file.ends_with(".scon"):
		data = SpriterParserJSON.parse(source_file)
	else:
		push_error("SCML todavía no implementado")
		return ERR_UNAVAILABLE

	var scene = SpriterBuilder.build_scene(data)
	return ResourceSaver.save(scene, save_path + ".tscn")'''
