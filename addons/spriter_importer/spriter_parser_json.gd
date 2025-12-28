class_name SpriterParserJSON

static func parse(path) -> Dictionary:
	var text = FileAccess.get_file_as_string(path)
	var json = JSON.parse_string(text)
	if json == null:
		push_error("JSON inválido")
		return {}
	
	var data = _normalize(json)
	data.base_path = path.get_base_dir()
	
	return data

static func _normalize(data: Dictionary) -> Dictionary:
	var result = {
		sprites = {},
		entities = []
	}
	
	_normalize_sprites(data, result)
	_normalize_entities(data, result)
	
	return result

static func _normalize_sprites(data, result):
	for folder in data.get("folder", []):
		var folder_id = int(folder["id"])
		for file in folder.get("file", []):
			var file_id = int(file["id"])
			var sprite_id = "%d:%d" % [folder_id, file_id]
			
			result.sprites[sprite_id] = {
				path = file["name"],
				size = Vector2(
					file.get("width", 0),
					file.get("height", 0)
				),
				pivot = Vector2(
					file.get("pivot_x", 0.0),
					file.get("pivot_y", 1.0)
				)
			}

static func _normalize_entities(data, result):
	for entity in data.get("entity", []):
		var obj_info = _parse_obj_info(entity)

		var ent = {
			name = entity["name"],
			bones = {},
			bone_info = {},
			objects = {},
			animations = []
		}
		
		for name in obj_info.keys():
			if obj_info[name].type == "bone":
				ent.bone_info[name] = obj_info[name]

		_normalize_animations(entity, ent, obj_info)
		result.entities.append(ent)

static func _normalize_animations(entity, ent, obj_info):
	for anim in entity.get("animation", []):
		ent.animations.append({
			name = anim["name"],
			length = anim["length"] / 1000.0,
			mainline = anim.get("mainline", {}),
			timeline = anim.get("timeline", [])
		})

		for timeline in anim.get("timeline", []):
			var tid = int(timeline["id"])
			var name = timeline.get("name", "")
			var ttype = timeline.get("object_type","sprite")

			if ttype == "bone":
				var info = obj_info.get(name, {})
				ent.bones[tid] = _parse_bone_timeline(timeline, info)
			if ttype == "sprite":
				var info = obj_info.get(name, {})
				ent.objects[tid] = _parse_object_timeline(
					timeline,
					ttype,
					info
				)

static func _parse_bone_timeline(timeline, info):
	var keys = []
	
	var base_length = info.get("length", 1)

	for key in timeline.get("key", []):
		var bone = key.get("bone", {})
		
		keys.append({
			time = key.get("time", 0) / 1000.0,
			position = Vector2(
				bone.get("x", 0),
				bone.get("y", 0)
			),
			rotation = deg_to_rad(bone.get("angle", 0)),
			scale = Vector2(
				bone.get("scale_x", 1),
				bone.get("scale_y", 1)
			),
			length = bone.get("length", base_length) # 🔥 CLAVE
		})

	return {
		name = timeline.get("name", ""),
		parent = null,
		base_length = base_length,
		keys = keys
	}

static func _parse_object_timeline(timeline, ttype, info):
	var keys = []

	for key in timeline.get("key", []):
		var obj = key.get("object", {})

		keys.append({
			time = key.get("time", 0) / 1000.0,
			position = Vector2(
				obj.get("x", 0),
				-obj.get("y", 0)
			),
			rotation = deg_to_rad(-obj.get("angle", 0)),
			scale = Vector2(
				obj.get("scale_x", 1),
				obj.get("scale_y", 1)
			),
			alpha = obj.get("a", 1),
			z_index = obj.get("z_index", 0),
			sprite = {
				folder = int(obj.get("folder", -1)),
				file   = int(obj.get("file", -1))
			}
		})

	return {
		name = timeline.get("name", ""),
		type = ttype,
		size = info.get("size", null),
		pivot = info.get("pivot", null),
		keys = keys
	}


static func _parse_obj_info(entity: Dictionary) -> Dictionary:
	var info = {}

	for obj in entity.get("obj_info", []):
		if(obj["type"] == "bone"):
			info[obj["name"]] = {
				type = obj["type"],
				length = obj.get("w",0)
			}
		else:
			info[obj["name"]] = {
				type = obj["type"],
				size = Vector2(
					obj.get("w", 0),
					obj.get("h", 0)
				),
				pivot = Vector2(
					obj.get("pivot_x", 0),
					obj.get("pivot_y", 1)
				)
			}
	return info
