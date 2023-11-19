extends CollisionShape3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

@export var shape2d = RectangleShape2D.new()

@export var position2d = Vector2.ZERO

var shape2d_last = shape2d;
var position2d_last = position2d;

func set_3d_size_from_2d(size3d):
	self.shape.size.x = size3d.x
	self.shape.size.y = size3d.y
	self.shape.size.z = size3d.z

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if shape2d.size != shape2d_last.size:
		self.shape.size.x = shape2d.size.x
		self.shape.size.y = shape2d.size.y
		self.shape.size.z = shape2d.size.z
		shape2d_last.size = shape2d.size
	
	pass


