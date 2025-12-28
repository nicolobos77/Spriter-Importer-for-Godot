extends Node2D

@onready var Skeleton = $Skeleton
@onready var AnimPlay = $Skeleton/AnimationPlayer


func _ready():
	for anim_name in AnimPlay.get_animation_list():
		var anim = AnimPlay.get_animation(anim_name)
		anim.loop_mode = Animation.LOOP_NONE

	AnimPlay.connect("animation_finished", _animation_end)
	AnimPlay.play("Stand", 0.5)

func _animation_end(anim_name : String) -> void:
	match anim_name:
		"Stand":
			AnimPlay.play("Walk",1,0.5)
		"Walk":
			AnimPlay.play("Jump",1,0.5)
		"Jump":
			AnimPlay.play("Stand",1,0.5)
