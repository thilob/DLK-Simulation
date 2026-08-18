extends SceneTree

var failures: int = 0

func _init():
	call_deferred("_run")

func _run():
	var scene_resource = load("res://main.tscn")
	var simulation = scene_resource.instantiate()
	root.add_child(simulation)
	await process_frame

	_expect(simulation.roof_targets.size() == 5,"Exactly five roof rescue positions must exist")
	var reachable_roof_count: int = 0
	for target in simulation.reachable_windows:
		if String(target.get_meta("target_kind","window")) == "roof":
			reachable_roof_count += 1
	if reachable_roof_count == 0:
		for roof_target in simulation.roof_targets:
			var solution: Dictionary = simulation._target_solution(roof_target)
			print("Roof debug %s: length=%.2f angle=%.2f clear=%s" % [roof_target.name,float(solution["length"]),rad_to_deg(float(solution["angle"])),str(simulation._target_pose_is_clear(solution))])
	_expect(reachable_roof_count > 0,"At least one roof rescue position must be reachable")
	_expect(simulation.quit_dialog != null,"Escape confirmation dialog must exist")
	_expect(InputMap.has_action("quit_request"),"Escape quit action must exist")
	simulation._request_quit()
	await process_frame
	_expect(simulation.quit_dialog.visible,"Quit request must open the confirmation dialog")
	simulation.quit_dialog.hide()

	if failures == 0:
		print("Rescue target and quit dialog tests passed (%d reachable roof targets)" % reachable_roof_count)
		quit(0)
	else:
		push_error("%d rescue target test(s) failed" % failures)
		quit(1)

func _expect(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)
