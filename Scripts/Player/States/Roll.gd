extends PlayerState



func _process(_delta):
	if parent.inputs[parent.INPUTS.ACTION] == 1 or parent.inputs[parent.INPUTS.ACTION2] == 1 or parent.inputs[parent.INPUTS.ACTION3] == 1:
		# use parent.action_jump("roll",false) to have jump lock similar to sonic 1-3
		# true replicates CD and Mania
		parent.action_jump("roll",true)
		parent.set_state(parent.STATES.JUMP)
	# water running
	parent.action_water_run_handle()

func _physics_process(delta):
	
	# Set air if not on floor
	if (!parent.ground):
		parent.set_state(parent.STATES.AIR,parent.currentHitbox.ROLL)
		return null
	# Set normal if speed is 0
	if (parent.movement2d.x == 0):
		parent.set_state(parent.STATES.NORMAL)
		return null
	
	# Lock vertical movement
	parent.movement2d.y = min(parent.movement2d.y,0)
	
	# Apply slope factor
	if (sign(parent.movement2d.x) != sign(sin(parent.angle-parent.gravityAngle))):
		parent.movement2d.x += (parent.slprollup*sin(parent.angle-parent.gravityAngle))/GlobalFunctions.div_by_delta(delta)
	else:
		parent.movement2d.x += (parent.slprolldown*sin(parent.angle-parent.gravityAngle))/GlobalFunctions.div_by_delta(delta)
	
	var calcAngle = rad_to_deg(parent.angle-parent.gravityAngle)
	if (calcAngle < 0):
		calcAngle += 360
	
	# drop, if speed below fall speed
	if (abs(parent.movement2d.x) < parent.fall and calcAngle >= 45 and calcAngle <= 315):
		if (round(calcAngle) >= 90 and round(calcAngle) <= 270):
			parent.disconect_from_floor()
		
		parent.horizontalLockTimer = 30.0/60.0
	
	
	
	
	if (parent.movement2d.x != 0):
		var checkX = sign(parent.movement2d.x)
		if (parent.inputs[parent.INPUTS.XINPUT] != 0 and sign(parent.movement2d.x) != parent.inputs[parent.INPUTS.XINPUT]):
			parent.movement2d.x += parent.rolldec/GlobalFunctions.div_by_delta(delta)*parent.inputs[parent.INPUTS.XINPUT]
		
		parent.movement2d.x -= (parent.rollfrc/GlobalFunctions.div_by_delta(delta))*sign(parent.movement2d.x)

		if (sign(parent.movement2d.x) != checkX):
			parent.movement2d.x -= parent.movement2d.x
	
	# clamp rolling top speed
	parent.movement2d.x = clamp(parent.movement2d.x,-parent.toproll,parent.toproll)

# stop the water run sound
func state_exit():
	parent.sfx[29].stop()
