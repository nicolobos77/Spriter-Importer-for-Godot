class_name SpriterBuilder

static func build_scene(data: Dictionary) -> Array[PackedScene]:
	# New scene to add every entity on Spriter
	var scenes: Array[PackedScene] = []
	# Loop through entities array
	for entity in data.get("entities", []):
		var root = _create_entity_root(entity)
		_build_static_pose(data, entity, root)

		var packed = PackedScene.new()
		packed.pack(root)
		scenes.append(packed)
	return scenes
	
static func _create_entity_root(entity: Dictionary) -> Node2D:
	var root = Node2D.new()
	root.name = entity.get("name", "Entity")
	root.z_as_relative = false
	root.y_sort_enabled = false
	
	var skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton"
	skeleton.set_meta("path",NodePath("Skeleton"))
	#root.add_child(skeleton)
	
	var slots = Node2D.new()
	slots.z_as_relative = false
	slots.y_sort_enabled = false
	slots.name = "Slots"
	root.add_child(slots)

	# guardamos referencia
	root.set_meta("skeleton", skeleton)
	root.set_meta("slots", slots)
	
	return root

static func _build_static_pose(
	data: Dictionary,
	entity: Dictionary,
	root: Node2D
) -> void:
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	root.add_child(anim_player)
	anim_player.owner = root

	var animations = entity.get("animations", [])
	if animations.is_empty():
		return

	var bone_info = entity.get("bone_info",[])
	var anim = animations[0]
	var mainline = anim.get("mainline", {})
	var timeline = anim.get("timeline", {})
	var keys = mainline.get("key", [])
	if keys.is_empty():
		return

	var first_key = keys[0]
	
	var skeleton: Skeleton2D = root.get_meta("skeleton")
	var slots : Node2D = root.get_meta("slots")

	var bone_nodes = _create_bones(first_key.get("bone_ref", []), skeleton, timeline,bone_info)
	root.add_child(skeleton)

	_build_objects(
		data,
		entity,
		first_key,
		root,
		skeleton,
		bone_nodes
	)
	
	var slot_nodes = root.get_meta("slot_nodes", {})

	root.set_meta("bone_nodes", bone_nodes)
	root.set_meta("bones_data", entity.get("bones", {}))
	
	for bone in bone_nodes:
		bone_nodes[bone].owner = root
	slots.owner = root
	skeleton.owner = root
	
	var library = AnimationLibrary.new()
	anim_player.add_animation_library("", library)
	
	for animat in animations:
		#var tracks = {}
		var tracks = {
			"bone": {},
			"obj": {}
		}
		var animation = Animation.new()
		animation.length = float(animat.get("length", 0.0))
		animation.step = 0.0
		
		var looping = animat.get("looping",true)
		animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
		var mainlines = animat.get("mainline",{})
		var timelines = animat.get("timeline",[])
		var m_keys = mainlines.get("key",[])
		var first_keys = {
			"bone": {},
			"obj": {}
		}

		var last_keys = {
			"bone": {},
			"obj": {}
		}
		# Recorro los keyframes
		var last_rot = {
			"bone": {},
			"obj": {}
		}
		for main_kindex in m_keys.size():
			#for main_key in m_keys:
			var main_key = m_keys[main_kindex]
			# Obtengo los keyframes de huesos
			var key_time = float(main_key.get("time",0))
			var bone_refs = main_key.get("bone_ref",[])
			var obj_refs = main_key.get("object_ref",[])
			for bone_ref in bone_refs:
				var bone_id = int(bone_ref.get("id",0))
				var bone_key = int(bone_ref.get("key",0))
				var timeline_id = int(bone_ref.get("timeline",0))
				var tl = timelines[timeline_id]
				var ttype = tl.get("object_type","sprite")
				var tname = tl.get("name")
				var obj_id = int(tl.get("obj",0))
				var tkeys = tl.get("key",[])
				if ttype == "bone" and tkeys.size() > bone_key:
					var tkey = tkeys[bone_key]
					var is_first = not last_rot["bone"].has(bone_id)

					var bone = tkey.get("bone",{})
					# Transformación
					var spin =  int(tkey.get("spin",1)) # -1 para girar antihorario, 0 girar horario
					var angle = float(bone.get("angle",0.0))
					var target_rot = -deg_to_rad(angle)
					var prev_rot = last_rot["bone"].get(bone_id, target_rot)
					var obx = float(bone.get("x",0.0))
					var oby = float(bone.get("y",0.0))
					var sx = float(bone.get("scale_x",1.0))
					var sy = float(bone.get("scale_y",1.0))
					
					var time = float(tkey.get("time",0)) / 1000.0
					var rbone = bone_nodes.get(str(bone_id))
					if rbone == null:
						continue
					#var btrack = _ensure_bone_tracks(animation,tracks,bone_id,rbone)
					var btrack = _ensure_bone_tracks(animation, tracks["bone"], bone_id, rbone)
					animation.track_insert_key(btrack.pos,time, Vector2(obx, -oby))
					
					var fixed_rot: float

					if is_first:
						# PRIMER KEYFRAME → valor directo, SIN acumulación
						fixed_rot = target_rot
					else:
						fixed_rot = spriter_fix_angle(
							prev_rot,
							target_rot,
							spin
						)
					
					last_rot["bone"][bone_id] = fixed_rot
					animation.track_insert_key(btrack.rot, time, fixed_rot)
					
					if not first_keys["bone"].has(bone_id):
						first_keys["bone"][bone_id] = {
							"pos": Vector2(obx, -oby),
							"rot": fixed_rot,
							"spin": spin
						}

					last_keys["bone"][bone_id] = {
						"pos": Vector2(obx, -oby),
						"rot": fixed_rot,
						"spin": spin
					}
			for obj_ref in obj_refs:
				var obj_id = int(obj_ref.get("id",0))
				var obj_key = int(obj_ref.get("key",0))
				var timeline_id = int(obj_ref.get("timeline",0))
				var z_index = int(obj_ref.get("z_index",0))
				var tl = timelines[timeline_id]
				var ttype = tl.get("object_type","sprite")
				var tname = tl.get("name")
				var tkeys = tl.get("key",[])
				if ttype == "sprite" and tkeys.size() > obj_key:
					var tkey = tkeys[obj_key]
					var obj = tkey.get("object",{})
					var spin =  int(tkey.get("spin",1)) # -1 para girar antihorario, 0 girar horario
					var angle = float(obj.get("angle",0.0))
					var target_rot = -deg_to_rad(angle)
					var prev_rot = last_rot["obj"].get(timeline_id, target_rot)
					var obx = float(obj.get("x",0.0))
					var oby = float(obj.get("y",0.0))
					var sx = float(obj.get("scale_x",1.0))
					var sy = float(obj.get("scale_y",1.0))
					
					var flip_h = sx < 0.0
					var flip_v = sy < 0.0

					sx = abs(sx)
					sy = abs(sy)
					
					var file = int(obj.get("file",-1))
					var folder = int(obj.get("folder",-1))
					var sprite_data = _get_sprite_data(data, folder, file)
					var time = float(main_key.get("time",0)) / 1000.0
					var robj : Node2D = slot_nodes.get(str(timeline_id))
					if robj == null:
						continue
					robj.z_as_relative = false
					robj.y_sort_enabled = false
					var otrack = _ensure_obj_tracks(animation, tracks["obj"], timeline_id, robj)
					animation.track_insert_key(otrack.pos,time, Vector2(obx, -oby))
					animation.track_insert_key(otrack.scale,time, Vector2(sx, sy))
					animation.track_insert_key(otrack.z_index,time,z_index)
					animation.track_insert_key(otrack.flip_h, time, flip_h)
					animation.track_insert_key(otrack.flip_v, time, flip_v)
					
					if not sprite_data.is_empty():
						var tex = _get_or_load_texture(data, sprite_data)
						if tex != null:
							animation.track_insert_key(otrack.tex, time, tex)
					var fixed_rot = spriter_fix_angle(
						prev_rot,
						target_rot,
						spin
					)
					last_rot["obj"][timeline_id] = fixed_rot
					animation.track_insert_key(otrack.rot, time, fixed_rot)
					
					if not first_keys["obj"].has(timeline_id):
						first_keys["obj"][timeline_id] = {
							"pos": Vector2(obx, -oby),
							"rot": fixed_rot,
							"scale": Vector2(sx, sy),
							"spin": spin
						}

					last_keys["obj"][timeline_id] = {
						"pos": Vector2(obx, -oby),
						"rot": fixed_rot,
						"scale": Vector2(sx, sy),
						"spin": spin
					}
		if looping:
			var end_time = animation.length
			
			for bone_id in first_keys["bone"].keys():
				var btrack = tracks["bone"][bone_id]
				var first = first_keys["bone"][bone_id]
				if first  == null:
					continue
				
				var last = last_keys["bone"][bone_id]
				var loop_rot = spriter_fix_angle(
					last.rot,
					first.rot,
					last.get("spin",1)
				)
				
				animation.track_insert_key(btrack.pos, end_time, first.pos)
				animation.track_insert_key(btrack.rot, end_time, first.rot)
			for obj_id in first_keys["obj"].keys():
				var otrack = tracks["obj"].get(obj_id)
				if otrack == null:
					continue

				var first = first_keys["obj"][obj_id]
				var last = last_keys["obj"][obj_id]
				var loop_rot = spriter_fix_angle(
					last.rot,
					first.rot,
					last.get("spin",1)
				)

				animation.track_insert_key(otrack.pos, end_time, first.pos)
				animation.track_insert_key(otrack.scale, end_time, first.scale)
				animation.track_insert_key(otrack.rot, end_time, first.rot)
		library.add_animation(animat.get("name", "anim"), animation)

static func spriter_fix_angle(prev: float, raw: float, spin: int) -> float:
	var delta := wrapf(raw - prev, -PI, PI)

	# si spin contradice el delta corto, IGNORARLO
	if spin > 0 and delta < 0.0:
		pass
	elif spin < 0 and delta > 0.0:
		pass

	return prev + delta

static func _get_sprite_data(data: Dictionary, folder: int, file: int) -> Dictionary:
	var sprite_id = "%d:%d" % [folder, file]
	var sprites = data.get("sprites", {})

	if not sprites.has(sprite_id):
		push_warning("Sprite no encontrado: " + sprite_id)
		return {}

	return sprites[sprite_id]

static func _get_or_load_texture(data: Dictionary, sprite_data: Dictionary) -> Texture2D:
	if not data.has("textures"):
		data["textures"] = {}

	var path: String = sprite_data.path
	if data["textures"].has(path):
		return data["textures"][path]

	var base_path: String = data.get("base_path", "res://")
	var full_path = base_path.path_join(path)

	if not ResourceLoader.exists(full_path):
		push_warning("No existe textura: " + full_path)
		return null

	var tex: Texture2D = load(full_path)
	if tex == null:
		return null

	data["textures"][path] = tex
	return tex

static func _ensure_bone_tracks(
	animation: Animation,
	tracks : Dictionary,
	bone_id: int,
	bone: Bone2D
) -> Dictionary:

	if not tracks.has(bone_id):
		tracks.set(bone_id, {})
		var parent = bone.get_parent()
		var path = NodePath(str(parent.get_meta("path","Skeleton/%s" % bone.name),"/",bone.name))
		bone.set_meta("path",path)
		var pos = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(pos, str(path, ":position"))

		var rot = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(rot, str(path, ":rotation"))
		
		tracks[bone_id] = {
			"pos": pos,
			"rot": rot
		}

	return tracks.get(bone_id,{})

static func _ensure_obj_tracks(
	animation: Animation,
	tracks : Dictionary,
	obj_id: int,
	obj: Node2D
) -> Dictionary:

	if not tracks.has(obj_id):
		tracks.set(obj_id, {})
		var parent = obj.get_parent()
		
		var path : NodePath
		# Si el padre ya tiene path (bone o Slots)
		if parent.has_meta("path"):
			path = NodePath("%s/%s" % [parent.get_meta("path"), obj.name])
		else:
			path = NodePath("Slots/%s" % obj.name)
			
		obj.set_meta("path",path)
		var pos = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(pos, str(path, ":position"))

		var rot = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(rot, str(path, ":rotation"))
		
		var scale = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(scale, str(path, ":scale"))
		
		var ztrack = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_interpolation_type(ztrack,Animation.INTERPOLATION_NEAREST)
		animation.value_track_set_update_mode(ztrack,Animation.UPDATE_DISCRETE)
		animation.track_set_path(ztrack, str(path, ":z_index"))
		
		var tex_track = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_interpolation_type(tex_track,Animation.INTERPOLATION_NEAREST)
		animation.value_track_set_update_mode(tex_track,Animation.UPDATE_DISCRETE)
		animation.track_set_path(tex_track, "%s:texture" % path)
		
		var flip_h_track = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(flip_h_track, str(path, ":flip_h"))
		animation.track_set_interpolation_type(flip_h_track, Animation.INTERPOLATION_NEAREST)
		animation.value_track_set_update_mode(flip_h_track, Animation.UPDATE_DISCRETE)

		var flip_v_track = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(flip_v_track, str(path, ":flip_v"))
		animation.track_set_interpolation_type(flip_v_track, Animation.INTERPOLATION_NEAREST)
		animation.value_track_set_update_mode(flip_v_track, Animation.UPDATE_DISCRETE)

		tracks[obj_id] = {
			"pos": pos,
			"rot": rot,
			"scale": scale,
			"z_index" : ztrack,
			"tex": tex_track,
			"flip_h": flip_h_track,
			"flip_v": flip_v_track
		}

	return tracks.get(obj_id,{})

static func _build_objects(
	data: Dictionary,
	entity: Dictionary,
	main_key: Dictionary,
	root: Node2D,
	skeleton: Skeleton2D,
	bone_nodes: Dictionary
) -> void:
	var slots: Node2D = root.get_meta("slots")
	var objects = entity.get("objects", {})
	var z = 0

	var slot_nodes = {}

	for ref in main_key.get("object_ref", []):
		var z_index = int(ref.get("z_index",z))
		
		var obj_id = int(ref.get("id"))
		var timeline_id = int(ref.get("timeline"))
		
		var obj = objects.get(timeline_id)
		if obj == null or obj.get("type") != "sprite":
			continue

		var parent: Node2D = slots

		if ref.has("parent") and bone_nodes.has("%d" % ref.parent):
			parent = bone_nodes["%d" % ref.parent]

		var sprite = _create_sprite_from_object(
			data,
			obj,
			parent,
			root,
			z_index
		)

		#sprite.name = str(timeline_id)
		slot_nodes[str(timeline_id)] = sprite

		z = z_index + 1

	root.set_meta("slot_nodes", slot_nodes)

static func _create_bones(
	bone_refs: Array,
	skeleton: Skeleton2D,
	timeline : Array,
	bone_info : Dictionary) -> Dictionary:

	var bone_nodes = {}

	for bref in bone_refs:
		var timeline_id = int(bref.get("timeline",-1))
		if(timeline_id == -1):
			continue
		var tl = timeline[timeline_id]
		var tl_name = tl.get("name")
		var tl_id = int(tl.get("id",-1))
		
		var bone = Bone2D.new()
		bone.name = tl_name
		
		var bone_id = int(bref.get("id"))
		var bone_keys = tl.get("key")
		var bone_key = bone_keys[0]
		var bone_data = bone_key.get("bone",{})
		var binfo = bone_info[tl_name]
				
		bone.position = Vector2(bone_data.get("x",0),-bone_data.get("y",0))
		bone.rotation = -(bone_data.get("angle",0) / 180) * PI
		var sx = float(bone_data.get("scale_x", 1.0))
		var sy = float(bone_data.get("scale_y", 1.0))
		
		bone.length = binfo.get("length",1)
		bone.rest = bone.transform
		bone.set_autocalculate_length_and_angle(false)
		_ensure_parent_end(bone,bone_nodes)
		
		if bref.has("parent"):
			var parent_id = int(bref.parent)
			var parent_bone: Bone2D = bone_nodes["%d" % parent_id]
			
			#_ensure_parent_end(parent_bone,bone_nodes)
			parent_bone.add_child(bone)
		else:
			skeleton.add_child(bone)
		bone_nodes["%d" % bone_id] = bone
		
	return bone_nodes

static func _ensure_parent_end(parent: Bone2D, bone_nodes:Dictionary):
	if parent.get_meta("is_end", false):
		return
	
	var end_name = parent.name + "_end"
	if parent.has_node(end_name):
		return

	var end = Bone2D.new()
	end.name = parent.name + "_end"
	end.position = Vector2(parent.length, 0)
	end.set_autocalculate_length_and_angle(false)
	end.set_length(1)
	end.rest = end.transform
	end.set_meta("is_end", true)
	parent.add_child(end)
	bone_nodes[end.name] = end

static func _create_sprite_from_object(
	data: Dictionary,
	obj: Dictionary,
	parent: Node2D,
	root: Node2D,
	z_index: int
) -> Sprite2D:

	var keys = obj.get("keys", [])
	if keys.is_empty():
		return

	var key = keys[0]

	var sprite = Sprite2D.new()
	sprite.name = obj.get("name", "sprite")
	sprite.centered = false
	sprite.z_as_relative = false
	sprite.y_sort_enabled = false
	
	var pos : Vector2 = key.get("position")
	sprite.position = pos
	
	var rot = key.get("rotation")
	var sscale: Vector2 = key.get("scale", Vector2.ONE)

	sprite.rotation = rot
	sprite.scale = Vector2(abs(sscale.x), abs(sscale.y))
	sprite.flip_h = sscale.x < 0
	sprite.flip_v = sscale.y < 0
	
	sprite.z_index = z_index #* 10 + key.get("z_index", 0)
	var spr = key.get("sprite")
	if spr != null:
		#_apply_texture(data, sprite, spr)
		_apply_sprite(sprite, data, spr.folder, spr.file)
	
	parent.add_child(sprite)
	sprite.owner = root
	return sprite

static func _apply_texture(data: Dictionary, sprite: Sprite2D, spr: Dictionary) -> void:
	var sprite_id = "%d:%d" % [spr.folder, spr.file]
	var sprite_data = _load_texture(data, sprite_id)

	if sprite_data.is_empty():
		return

	sprite.texture = sprite_data.texture

	var size: Vector2 = sprite_data.size
	var pivot: Vector2 = sprite_data.pivot
	#sprite.flip_v = true
	sprite.offset = Vector2(
		-size.x * pivot.x,
		size.y * (pivot.y - 1.0)
		#-size.y * pivot.y
	)

static func _apply_sprite(sprite: Sprite2D, data: Dictionary, folder: int, file: int) -> void:
	var sprite_data = _get_sprite_data(data, folder, file)
	if sprite_data.is_empty():
		return

	var tex = _get_or_load_texture(data, sprite_data)
	if tex == null:
		return

	sprite.texture = tex

	var size: Vector2 = sprite_data.size
	var pivot: Vector2 = sprite_data.pivot

	sprite.offset = Vector2(
		-size.x * pivot.x,
		size.y * (pivot.y - 1.0)
	)
	
static func _load_texture(data: Dictionary, sprite_id: String) -> Dictionary:
	var files = data.get("sprites", {})
	if not files.has(sprite_id):
		push_warning("Sprite no encontrado: " + sprite_id)
		return {}

	var info = files[sprite_id]

	var base_path: String = data.get("base_path", "res://")
	var relative_path: String = info.path # ej: "eye.png" o "Head/Head.png"

	var full_path = base_path.path_join(relative_path)
	
	if not ResourceLoader.exists(full_path):
		push_warning("Archivo no existe: " + full_path)
		return {}

	var tex = load(full_path)
	if tex == null:
		push_warning("No se pudo cargar: " + full_path)
		return {}

	return {
		"texture": tex,
		"pivot": info.pivot,
		"size": info.size,
		"path": relative_path
	}




'''static func _load_texture(data: Dictionary, sprite_id: String) -> Dictionary:
	var files = data.get("sprites", {})

	if not files.has(sprite_id):
		push_warning("Sprite no encontrado: " + sprite_id)
		return {}

	var info = files[sprite_id]
	var base_path = data.get("base_path", "")
	var path = base_path + "/" + info.path

	var tex = load(path)
	if tex == null:
		push_warning("No se pudo cargar: " + path)
		return {}

	return {
		texture = tex,
		pivot = info.pivot,
		size = info.size
	}
'''
