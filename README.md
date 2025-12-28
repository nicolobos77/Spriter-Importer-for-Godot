# Spriter (.scon) Importer for Godot

A Godot plugin that imports Spriter (.scon) models and converts them into playable Godot scenes.
```
⚠️ Work in progress
This plugin currently supports skeletons, sprites, and simple animations.
Bone scaling is not implemented yet.
```
# Features

- Imports Spriter (.scon) models

- Creates a Godot scene from the Spriter model

- Supports:

  - Skeleton hierarchy

  - Sprites

  - Simple animations

- Animations are played using Godot’s AnimationPlayer

- Compatible with animation signals such as animation_finished

# Current Limitations

- ❌ Bone scaling is not supported

- ❌ Advanced animation features may not work yet

- ❌ Complex constraints are not implemented

# Installation

1. Copy the plugin folder into your Godot project:
```
res://addons/spriter_importer/
```

2. Enable the plugin in:
```
Project Settings → Plugins
```
# Usage
## Importing a Spriter Model

1. Place your Spriter model folder (including the .scon file and images) inside your project, for example:
```
res://assets/sprite/SPRITER_MODEL/
```

2. The plugin will generate a Godot scene from the Spriter model.

3. Instance the generated scene in your game.

## Playing Animations

The generated scene contains:

- A *Skeleton2D*

- An *AnimationPlayer* inside the skeleton

You can control animations directly via the *AnimationPlayer*.

## Example

This example cycles through all animations in a Spriter model and plays them sequentially:
```GDSCRIPT
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
			AnimPlay.play("Walk", 1, 0.5)
		"Walk":
			AnimPlay.play("Jump", 1, 0.5)
		"Jump":
			AnimPlay.play("Stand", 1, 0.5)
```
# Notes

- If an animation does not loop, you can use the animation_finished signal to chain animations.

- Loop behavior can be controlled via Animation.loop_mode.

# Godot Version

- Developed for Godot 4.5

# Roadmap

- Planned improvements:

  - Bone scaling support

  - Better animation accuracy

  - Support for more Spriter features

  - Bug fixes and optimizations
