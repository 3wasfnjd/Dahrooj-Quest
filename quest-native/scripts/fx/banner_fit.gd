class_name BannerFit
## The round banners (a mode's big title and its line under it) stand the same distance from
## your eyes in every mode, VR or mixed reality: each stage places them as it likes, then
## fit() slides them along the line from the eye to DIST metres, scaled by the same factor, so
## they keep the look (the angle up, the size on screen) the stage gave them.

const DIST := 3.0  # metres

## The eye (world space); main keeps it current. INF: not known yet (fit leaves them alone).
static var eye := Vector3.INF


## The first node is the banner the distance is measured to; the others move with it.
static func fit(nodes: Array) -> void:
	if eye == Vector3.INF or nodes.is_empty():
		return
	var head: Node3D = nodes[0]
	if head == null or not head.is_inside_tree():
		return
	var d := head.global_position - eye
	var dist := d.length()
	if dist < 1e-4:
		return
	var k := DIST / dist
	for n in nodes:
		var nd := n as Node3D
		if nd == null or not nd.is_inside_tree():
			continue
		nd.global_position = eye + (nd.global_position - eye) * k
		nd.scale *= k
