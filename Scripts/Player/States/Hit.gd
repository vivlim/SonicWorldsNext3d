extends PlayerState


func _physics_process(delta):
	parent.animator.play("hurt")
	# gravity
	parent.movement2d.y += parent.grv/GlobalFunctions.div_by_delta(delta)
	
	# exit if on floor
	if parent.ground and parent.movement2d.y >= 0:
		parent.movement2d.x = 0
		parent.set_state(parent.STATES.NORMAL)
