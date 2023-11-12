class_name PhysicsObject3D extends CharacterBody3D

func TranslateVec2(input):
	var input3d = Vector3(input.x, input.y, 0)
	var planeRot = Quaternion(Vector3(0, 1, 0), gameplayPlaneRot)
	return planeRot * input3d

func Translate3DTo2D(inputVec3):
	var planeRotReverse = Quaternion(Vector3(0, 1, 0), gameplayPlaneRot * -1)
	var unrotated = planeRotReverse * inputVec3
	return Vector2(unrotated.x, unrotated.y)

var rotation2d = 0.0
var gameplayPlaneRot = 0.0
var slopeRotAxis = Vector3(0, 0, 1)
var pixelSize = 0.001 # wild guess.

func Update3DRotation():
	var current = Quaternion($ViewportPlane.transform.basis)
	var planeRot = Quaternion(Vector3(0, 1, 0), gameplayPlaneRot)
	var slopeRot = Quaternion(Vector3(0, 0, 1), rotation2d)
	var newRot = current.slerp(planeRot.normalized(), 0.5)
	newRot = newRot.slerp(slopeRot.normalized(), 0.5)
	transform.basis = Basis(newRot)
	slopeRotAxis = planeRot * Vector3(0, 0, 1)

# Sensors
var verticalObjectCheck = RayCast3D.new()
var verticalSensorLeft = RayCast3D.new()
var verticalSensorMiddle = RayCast3D.new() # mostly used for edge detection and clipping prevention
var verticalSensorMiddleEdge = RayCast3D.new() # used for far edge detection
var verticalSensorRight = RayCast3D.new()
var horizontalSensor = RayCast3D.new()
var slopeCheck = RayCast3D.new()
var objectCheck = RayCast3D.new()

@onready var sensorList = [verticalSensorLeft,verticalSensorMiddle,verticalSensorMiddleEdge,verticalSensorRight,horizontalSensor,slopeCheck]

var maxCharGroundHeight = 16 # this is to stop players getting stuck at the bottom of 16x16 tiles, 
# you may want to adjust this to match the height of your tile collisions
# this only works when on the floor
var yGroundDiff = 0 # used for y differences on ground sensors


var groundLookDistance = 14 # how far down to look
@onready var pushRadius = max(($HitBox.shape.size.x/2)+1,10) # original push radius is 10


# physics variables
var movement = velocity+TranslateVec2(Vector2(0.00001,0)) # this is a band aid fix, physics objects have something triggered to make them work but it only happens when moving horizontally, so the solution for now is to have it add a unnoticeable amount of x movement
var ground = true
var roof = false
var moveStepLength = 8*60
# angle is the rotation based on the floor normal
var angle = 0
var gravityAngle = 0
# the collission layer, 0 for low, 1 for high
var collissionLayer = 0

# translate, (ignores physics)
var translate = false

# Vertical sensor reference
var getVert = null

signal disconectFloor
signal connectFloor
signal disconectCeiling
signal connectCeiling
signal positionChanged

# how many pixels can you step on top of objects
@export var pixelObjectStep = 4

func _ready():
	slopeCheck.modulate = Color.BLUE_VIOLET
	$HitBox.add_child(verticalSensorLeft)
	$HitBox.add_child(verticalSensorMiddle)
	$HitBox.add_child(verticalSensorMiddleEdge)
	$HitBox.add_child(verticalSensorRight)
	$HitBox.add_child(verticalObjectCheck)
	$HitBox.add_child(horizontalSensor)
	$HitBox.add_child(slopeCheck)
	$HitBox.add_child(objectCheck)
	#for i in sensorList:
	#	i.enabled = true
	update_sensors()
	# Object check only needs to be set once
	objectCheck.set_collision_mask_value(1,false)
	objectCheck.set_collision_mask_value(14,true)
	objectCheck.set_collision_mask_value(16,true)
	objectCheck.set_collision_mask_value(17,true)
	objectCheck.hit_from_inside = true
	verticalObjectCheck.set_collision_mask_value(1,false)
	verticalObjectCheck.set_collision_mask_value(14,true)
	#objectCheck.enabled = true
	#verticalObjectCheck.enabled = true
	# middle should also check for objects
	verticalSensorMiddle.set_collision_mask_value(14,true)
	verticalSensorMiddleEdge.set_collision_mask_value(14,true)
	verticalSensorMiddle.set_collision_mask_value(17,true)
	verticalSensorMiddleEdge.set_collision_mask_value(17,true)

func update_sensors():
	var rotationSnap = snapped(rotation2d,deg_to_rad(90))
	var shape = $HitBox.shape.size/2 # todo this will be area3d
	
	# floor sensors
	yGroundDiff = 0
	# calculate ground difference for smaller height masks
	if ground and shape.y <= maxCharGroundHeight:
		yGroundDiff = abs((shape.y)-(maxCharGroundHeight))
	
	# note: the 0.01 is to help just a little bit on priority for wall sensors
	var verticalSensorLeftPosition2d = Vector2(-(shape.x-0.01),-yGroundDiff)
	verticalSensorLeft.position = TranslateVec2(verticalSensorLeftPosition2d)
	
	var movement2d = Translate3DTo2D(movement)
	# calculate how far down to look if on the floor, the sensor extends more if the objects is moving, if the objects moving up then it's ignored,
	# if you want behaviour similar to sonic 1, replace "min(abs(movement.x/60)+4,groundLookDistance)" with "groundLookDistance"
	var extendFloorLook = min(abs(movement2d.x/60)+4,groundLookDistance)*(int(movement2d.y >= 0)*int(ground))
	var sensorLeftTarget2d = Vector2(-(shape.x-0.01),-yGroundDiff) # viv todo: don't use x here?
	
	var verticalSensorLeftTarget2d = Vector2(0,((shape.y+extendFloorLook)*(int(movement2d.y >= 0)-int(movement2d.y < 0)))+yGroundDiff)
	verticalSensorLeft.target_position = TranslateVec2(verticalSensorLeftTarget2d)
	
	verticalSensorRight.position = TranslateVec2(Vector2(-verticalSensorLeftPosition2d.x,verticalSensorLeftPosition2d.y))
	verticalSensorRight.target_position.y = verticalSensorLeft.target_position.y
	verticalSensorMiddle.target_position.y = verticalSensorLeft.target_position.y*1.1
	if movement.x != 0:
		verticalSensorMiddleEdge.position = (verticalSensorLeft.position*0.5*sign(movement.x))
	verticalSensorMiddleEdge.target_position.y = verticalSensorLeft.target_position.y*1.1
	
	
	# Object offsets, prevent clipping
	if !ground:
		# check left
		var offset = 0
		verticalObjectCheck.position.y = verticalSensorLeft.position.y
		# give a bit of distance for collissions
		verticalObjectCheck.target_position = TranslateVec2(Vector2(0,-(shape.y*0.25)+shape.y*-sign(verticalSensorLeft.target_position.y)))
		
		# check left sensor
		verticalObjectCheck.position.x = verticalSensorLeft.position.x
		verticalObjectCheck.position.z = verticalSensorLeft.position.z
		verticalObjectCheck.force_raycast_update()
		if verticalObjectCheck.is_colliding():
			# calculate the offset using the collission point and the cast positions
			offset = (verticalObjectCheck.get_collision_point()-(verticalObjectCheck.global_position+verticalObjectCheck.target_position)).y
		
		# check right sensor
		verticalObjectCheck.position.x = verticalSensorRight.position.x
		verticalObjectCheck.position.z = verticalSensorRight.position.z
		verticalObjectCheck.force_raycast_update()
		if verticalObjectCheck.is_colliding():
			# calculate the offset using the collission point and the cast positions,
			# compare it to the old offset, if it's larger then use new offset
			var newOffset = (verticalObjectCheck.get_collision_point()-(verticalObjectCheck.global_position+verticalObjectCheck.target_position)).y
			if abs(newOffset) > abs(offset):
				offset = newOffset
		
		# set the offsets for sensors
		if offset != 0:
			verticalSensorLeft.position.y = max(verticalSensorLeft.position.y,offset)
			verticalSensorRight.position.y = max(verticalSensorRight.position.y,offset)
		
	
	# wall sensor
	var velocity2d = Translate3DTo2D(velocity)
	if sign(velocity2d.rotated(-rotationSnap).x) != 0:
		horizontalSensor.target_position = TranslateVec2(Vector2(pushRadius*sign(velocity2d.rotated(-rotationSnap).x),0))
	# if the player is on a completely flat surface then move the sensor down 8 pixels
	# viv todo: 8 pixels is probably not right in 3d.
	var horizontalSensorPosition2d = Translate3DTo2D(horizontalSensor.position)
	horizontalSensorPosition2d.y = 8*pixelSize*int(round(rad_to_deg(angle)) == round(rad_to_deg(gravityAngle)) and ground)
	horizontalSensor.position = TranslateVec2(horizontalSensorPosition2d)
	
	# slop sensor
	var slopeCheckPosition2d = Translate3DTo2D(slopeCheck.position)
	slopeCheckPosition2d.y = shape.x
	slopeCheck.position = TranslateVec2(slopeCheckPosition2d)
	slopeCheck.target_position = TranslateVec2(Vector2((shape.y+extendFloorLook)*sign(rotation2d-angle),0))
	
	# viv todo: i thiiiink the rotation of these sensors is used to make them all align but their y value is pointed in the direction that matters
	var rotationSnap3d = Quaternion(slopeRotAxis, rotationSnap) * Vector3(0, 1, 0) # gonna go with an upwards facing vector
	verticalSensorLeft.global_rotation = rotationSnap
	verticalSensorRight.global_rotation = rotationSnap
	horizontalSensor.global_rotation = rotationSnap
	slopeCheck.global_rotation = rotationSnap
	
	# set collission mask values
	for i in sensorList:
		var rotatedTarget2d = Translate3DTo2D(i.target_position).rotated(rotationSnap)
		i.set_collision_mask_value(1,rotatedTarget2d.y > 0)
		i.set_collision_mask_value(2,rotatedTarget2d.x > 0)
		i.set_collision_mask_value(3,rotatedTarget2d.x < 0)
		i.set_collision_mask_value(4,rotatedTarget2d.y < 0)
		# reset layer masks
		i.set_collision_mask_value(5,false)
		i.set_collision_mask_value(6,false)
		i.set_collision_mask_value(7,false)
		i.set_collision_mask_value(8,false)
		i.set_collision_mask_value(9,false)
		i.set_collision_mask_value(10,false)
		i.set_collision_mask_value(11,false)
		i.set_collision_mask_value(12,false)
		
		# set layer masks
		i.set_collision_mask_value(1+((collissionLayer+1)*4),i.get_collision_mask_value(1))
		i.set_collision_mask_value(2+((collissionLayer+1)*4),i.get_collision_mask_value(2))
		i.set_collision_mask_value(3+((collissionLayer+1)*4),i.get_collision_mask_value(3))
		i.set_collision_mask_value(4+((collissionLayer+1)*4),i.get_collision_mask_value(4))
	
	
	horizontalSensor.force_raycast_update()
	verticalSensorLeft.force_raycast_update()
	verticalSensorRight.force_raycast_update()
	slopeCheck.force_raycast_update()
	


func _physics_process(delta):
	#movement += Vector2(-int(Input.is_action_pressed("gm_left"))+int(Input.is_action_pressed("gm_right")),-int(Input.is_action_pressed("gm_up"))+int(Input.is_action_pressed("gm_down")))*_delta*100
	var moveRemaining = movement # copy of the movement variable to cut down on until it hits 0
	var checkOverride = true
	while (!moveRemaining.is_equal_approx(Vector2.ZERO) or checkOverride) and !translate:
		checkOverride = false
		var moveCalc = moveRemaining.normalized()*min(moveStepLength,moveRemaining.length())
		
		var velocity2d = moveCalc.rotated(angle)
		velocity = TranslateVec2(velocity2d)
		set_up_direction(TranslateVec2(Vector2.UP.rotated(gravityAngle)))
		# wasMovedUp is set to true if an object collision occurs
		var wasMovedUp = false
		# check for any object collisions, if a collision doesn't occur internally, shift up by pixel steps then shift back down
		if test_move(global_transform,velocity*delta) and test_move(global_transform,velocity*(TranslateVec2(Vector2.RIGHT.rotated(gravityAngle)))*delta) and !test_move(global_transform,TranslateVec2(Vector2.ZERO)) and ground:
			var testTransform = global_transform
			testTransform.origin += up_direction*pixelObjectStep*pixelSize
			# if there's no collision occuring in the upper section then set was moved to true (if there's isn't another collision up if shifted up)
			if !test_move(testTransform,velocity*delta):
				var col = move_and_collide(up_direction*pixelObjectStep*pixelSize)
				wasMovedUp = (col==null)
		# do the shift
		move_and_slide()
		# move back down if we shifted up earlier
		if wasMovedUp:
			move_and_collide(-up_direction*pixelObjectStep*pixelSize)
		
		var _move = velocity
		update_sensors()
		var groundMemory = ground
		var roofMemory = roof
		ground = is_on_floor()
		roof = is_on_ceiling()
		
		
		# Wall sensors
		# Check if colliding
		if horizontalSensor.is_colliding():
			#  Calculate the move distance vectorm, then move
			var rayHitVec = (horizontalSensor.get_collision_point()-horizontalSensor.global_position)
			var normHitVec = TranslateVec2(-Vector2.LEFT.rotated(snap_angle(rayHitVec.normalized().angle())))
			position += (rayHitVec-(normHitVec*(pushRadius)))
		
		# Floor sensors
		getVert = get_nearest_vertical_sensor()
		# check if colliding (get_nearest_vertical_sensor returns false if no floor was detected)
		if getVert:
			# check if movement is going downward, if it is then run some ground routines
			if (movement.y >= 0):
				# ground routine
				# Set ground to true but only if movement.y is 0 or more
				ground = true
				# get ground angle
				angle = deg_to_rad(snapped(rad_to_deg(getVert.get_collision_normal().rotated(deg_to_rad(90)).angle()),0.001))
			else:
				# ceiling routine
				roof = true
			
			#  Calculate the move distance vectorm, then move
			var rayHitVec = (getVert.get_collision_point()-getVert.global_position)
			# Snap the Vector and normalize it
			var normHitVec = TranslateVec2(-Vector2.LEFT.rotated(snap_angle(rayHitVec.normalized().angle())))
			if move_and_collide(rayHitVec-(normHitVec*($HitBox.shape.size.y/2))-Vector3(0,yGroundDiff,0) * Quaternion(slopeRotAxis, rotation2d),true,true,true):
				var _col = move_and_collide(rayHitVec-(normHitVec*($HitBox.shape.size.y/2))-Vector3(0,yGroundDiff,0) * Quaternion(slopeRotAxis, rotation2d))
			else:
				# Do a check that we're not in the middle of a rotation, otherwise the player can get caught on outter curves (more noticable on higher physics frame rates)
				if snap_angle(angle) == snap_angle(rotation2d):
					position += (rayHitVec-(normHitVec*(($HitBox.shape.size.y/2)+0.25))-Vector2(0,yGroundDiff).rotated(rotation2d))
				else:
					# if the angle doesn't match the current rotation, move toward the slope angle unsnapped instead of following the raycast
					normHitVec = -Vector2.LEFT.rotated(rayHitVec.normalized().angle())
					position += (normHitVec-Vector2(0,yGroundDiff).rotated(rotation2d))
		
		# set rotation
		
		# slope check
		slopeCheck.force_raycast_update()
		
		if slopeCheck.is_colliding():
			var getSlope = snap_angle(slopeCheck.get_collision_normal() * Quaternion(slopeRotAxis, deg_to_rad(90))) # todo: confirm radians is right for 3d, and that this is ok
			# compare slope to current angle, check that it's not going to result in our current angle if we rotated
			var getSlope2d = Translate3DTo2D(getSlope)
			if getSlope2d != rotation2d:
				rotation2d = snap_angle(angle)
		else: #if no slope check then just rotate
			var preRotate = rotation2d
			rotation2d = snap_angle(angle)
			# verify if new angle would find ground
			if get_nearest_vertical_sensor() == null:
				rotation2d = preRotate
				
		Update3DRotation()
		
		# re check ground angle post shifting if on floor still
		if ground:
			getVert = get_nearest_vertical_sensor()
			if getVert:
				angle = deg_to_rad(snapped(rad_to_deg(getVert.get_collision_normal().rotated(deg_to_rad(90)).angle()),0.001))
		
		# Emit Signals
		if groundMemory != ground:
			# if on ground emit "connectFloor"
			if ground:
				emit_signal("connectFloor")
			# if no on ground emit "disconectFloor"
			else:
				emit_signal("disconectFloor")
				disconect_from_floor(true)
		if roofMemory != roof:
			# if on roof emit "connectCeiling"
			if roof:
				emit_signal("connectCeiling")
			# if no on roof emit "disconectCeiling"
			else:
				emit_signal("disconectCeiling")
		
		
		update_sensors()
		
		moveRemaining -= moveRemaining.normalized()*min(moveStepLength,moveRemaining.length())
		force_update_transform()
		
	if translate:
		position += (movement*delta)
	
	#Object checks
	
	if !translate:
		# temporarily reset mask and layer
		var layerMemory = collision_layer
		var maskMemory = collision_mask
		
		# move in place to make sure the player doesn't clip into objects
		set_collision_mask_value(17,true)
		var _col = move_and_collide(Vector3.ZERO)
		
		var dirList = [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]
		
		# loop through directions for collisions
		var objectCheckPos2d = Vector2.ZERO
		var objectCheckTargetPos2d = Vector2.ZERO
		for i in dirList:
			objectCheck.clear_exceptions()
			match i:
				Vector2.DOWN:
					objectCheckPos2d = Vector2(-$HitBox.shape.size.x,$HitBox.shape.size.y)/2 +i
					objectCheckTargetPos2d = Vector2($HitBox.shape.size.x,0)
				Vector2.UP:
					objectCheckPos2d = Vector2(-$HitBox.shape.size.x,-$HitBox.shape.size.y)/2 +i
					objectCheckTargetPos2d = Vector2($HitBox.shape.size.x,0)
				Vector2.RIGHT:
					objectCheckPos2d = Vector2($HitBox.shape.size.x,-$HitBox.shape.size.y)/2 +i
					objectCheckTargetPos2d = Vector2(0,$HitBox.shape.size.y)
				Vector2.LEFT:
					objectCheckPos2d = Vector2(-$HitBox.shape.size.x,-$HitBox.shape.size.y)/2 +i
					objectCheckTargetPos2d = Vector2(0,$HitBox.shape.size.y)
			objectCheck.position = TranslateVec2(objectCheckPos2d)
			objectCheckTargetPos2d = TranslateVec2(objectCheckTargetPos2d)

			objectCheck.force_raycast_update()

			while objectCheck.is_colliding():
				if objectCheck.get_collider().has_method("physics_collision") and test_move(global_transform,i.rotated(angle).round()):
					objectCheck.get_collider().physics_collision(self,i.rotated(angle).round())
				# add exclusion, this loop will continue until there isn't any objects
				objectCheck.add_exception(objectCheck.get_collider())
				# update raycast
				objectCheck.force_raycast_update()
			
			
		# reload memory for layers
		collision_mask = maskMemory
		collision_layer = layerMemory

	emit_signal("positionChanged")
	

func snap_angle(angleSnap = 0.0):
	var wrapAngle = wrapf(angleSnap,deg_to_rad(0.0),deg_to_rad(360.0))

	if wrapAngle >= deg_to_rad(315.0) or wrapAngle <= deg_to_rad(45.0): # Floor
		return deg_to_rad(0.0)
	elif wrapAngle > deg_to_rad(45.0) and wrapAngle <= deg_to_rad(134.0): # Right Wall
		return deg_to_rad(90.0)
	elif wrapAngle > deg_to_rad(134.0) and wrapAngle <= deg_to_rad(225.0): # Ceiling
		return deg_to_rad(180.0)
	
	# Left Wall
	return deg_to_rad(270.0)
	

func get_nearest_vertical_sensor():
	verticalSensorLeft.force_raycast_update()
	verticalSensorRight.force_raycast_update()
	
	# check if one sensor is colliding and if the other isn't touching anything
	if verticalSensorLeft.is_colliding() and not verticalSensorRight.is_colliding():
		return verticalSensorLeft
	elif not verticalSensorLeft.is_colliding() and verticalSensorRight.is_colliding():
		return verticalSensorRight
	# if neither are colliding then return null (nothing), this way we can skip over collission checks
	elif not verticalSensorLeft.is_colliding() and not verticalSensorRight.is_colliding():
		return null
	
	# check if the left sensort is closer, else return the sensor on the right
	if verticalSensorLeft.get_collision_point().distance_to(global_position) <= verticalSensorRight.get_collision_point().distance_to(global_position):
		return verticalSensorLeft
	else:
		return verticalSensorRight

func disconect_from_floor(force = false):
	if ground or force:
		# convert velocity
		movement = movement.rotated(angle-gravityAngle)
		angle = gravityAngle
		ground = false
		if (snap_angle(rotation2d) != snap_angle(gravityAngle)):
			rotation2d = snap_angle(gravityAngle)
			Update3DRotation()

# checks and pushes the player out if a collision is detected vertically in either direction
func push_vertical():
	# set movement memory
	var movementMemory = movement
	var directions = [-1,1]
	# check directions
	for i in directions:
		movement.y = i
		update_sensors()
		getVert = get_nearest_vertical_sensor()
		if getVert:
			#  Calculate the move distance vectorm, then move
			var rayHitVec = (getVert.get_collision_point()-getVert.global_position)
			# Snap the Vector and normalize it
			var normHitVec = -Vector2.LEFT.rotated(snap_angle(rayHitVec.normalized().angle()))
			# shift
			position += TranslateVec2(rayHitVec-(normHitVec*(($HitBox.shape.size.y/2)+0.25))-Vector2(0,yGroundDiff).rotated(rotation2d))
	# reset movement
	movement = movementMemory
