extends SkeletonModifier3D
## Scales one bone (and everything skinned or attached to it) after the animation pose is
## applied, e.g. a smaller hood on the Necromancer. Add as a child of the Skeleton3D.

var bone_name := "head"
var factor := 1.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var b := sk.find_bone(bone_name)
	if b < 0:
		return
	# absolute (the rigs never key head scale), so it can never compound across frames
	sk.set_bone_pose_scale(b, Vector3.ONE * factor)
