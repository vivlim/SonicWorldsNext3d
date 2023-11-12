extends PlayerState

func _process(_delta):
	# jumping off
	if parent.inputs[parent.INPUTS.ACTION] == 1 or parent.inputs[parent.INPUTS.ACTION2] == 1 or parent.inputs[parent.INPUTS.ACTION3] == 1:
		parent.action_jump()
	
	# if offset, flip around
	if parent.animator.current_animation == "corkScrewOffset":
		parent.sprite.flip_v = true
		parent.sprite.offset.y = 4
	

func _physics_process(delta):
	# gravity
	parent.movement2d.y += parent.grv/GlobalFunctions.div_by_delta(delta)
	
	# determine flip based on the direction
	parent.sprite.flip_h = (parent.direction < 0)
	
	# movement
	if (parent.inputs[parent.INPUTS.XINPUT] != 0):
		if (parent.movement2d.x*parent.inputs[parent.INPUTS.XINPUT] < parent.top):
			if (sign(parent.movement2d.x) == parent.inputs[parent.INPUTS.XINPUT]):
				if (abs(parent.movement2d.x) < parent.top):
					parent.movement2d.x = clamp(parent.movement2d.x+parent.acc/GlobalFunctions.div_by_delta(delta)*parent.inputs[parent.INPUTS.XINPUT],-parent.top,parent.top)
			else:
				# reverse direction
				parent.movement2d.x += parent.dec/GlobalFunctions.div_by_delta(delta)*parent.inputs[parent.INPUTS.XINPUT]
				# implament weird turning quirk
				if (sign(parent.movement2d.x) != sign(parent.movement2d.x-parent.dec/GlobalFunctions.div_by_delta(delta)*parent.inputs[parent.INPUTS.XINPUT])):
					parent.movement2d.x = 0.5*60*sign(parent.movement2d.x)
	else:
		if (parent.movement2d.x != 0):
			if (sign(parent.movement2d.x - (parent.frc/GlobalFunctions.div_by_delta(delta))*sign(parent.movement2d.x)) == sign(parent.movement2d.x)):
				parent.movement2d.x -= (parent.frc/GlobalFunctions.div_by_delta(delta))*sign(parent.movement2d.x)
			else:
				parent.movement2d.x -= parent.movement2d.x
	
	# reset state
	if parent.ground:
		if parent.animator.current_animation == "roll":
			parent.set_state(parent.STATES.ROLL)
		else:
			parent.set_state(parent.STATES.NORMAL)
			parent.animator.play("RESET")
