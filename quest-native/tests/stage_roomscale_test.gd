extends RefCounted
## The project asks OpenXR for the Local Floor space (the player's own boundary), and the
## Summit's VR spot follows a court set anywhere in the room.


static func run(check: Callable) -> void:
	var key := "xr/openxr/reference_space"
	var value := int(ProjectSettings.get_setting(key, -1))
	var hint := ""
	for prop: Dictionary in ProjectSettings.get_property_list():
		if String(prop.name) == key:
			hint = String(prop.hint_string)
	var names := hint.split(",")
	check.call(names.size() == 3 and names.find("Local Floor") == 2, "space: Godot's reference spaces are %s (Local Floor = 2)" % hint)
	check.call(value == 2 and value < names.size() and names[value] == "Local Floor",
		"space: the project uses the Local Floor space (%d)" % value)
	# The Summit on a VR court set off the origin and turned: the goal's spot, wherever it is.
	var vb := Basis(Vector3.UP, -0.9).scaled(Vector3.ONE / 2.0)
	var gr := Transform3D(vb, Vector3(1.2, 0, -0.8) - vb * Vector3(0, 0, 9.7))
	var spot := SummitMode.vr_spot(gr)
	var goal := gr * Vector3(0, 0, SummitMode.GOAL_AIM_Z)
	check.call(spot.is_equal_approx(Vector3(goal.x, 0.04, goal.z)), "roomscale: the Summit stands where a turned, moved court's goal is (%s)" % spot)
