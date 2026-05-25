extends "res://tests/run_tests.gd".BaseTest
class_name TestHex

func test_distance_zero() -> void:
	assert_eq(HexGrid.hex_distance(Vector2i(0,0), Vector2i(0,0)), 0, "Distance to self is 0")

func test_distance_adjacent() -> void:
	assert_eq(HexGrid.hex_distance(Vector2i(0,0), Vector2i(1,0)), 1, "Adjacent hex distance = 1")

func test_distance_far() -> void:
	assert_eq(HexGrid.hex_distance(Vector2i(0,0), Vector2i(3,0)), 3, "Distance of 3")

func test_neighbors_count() -> void:
	var n: Array[Vector2i] = HexGrid.neighbors(Vector2i(0,0))
	assert_eq(n.size(), 6, "Hex has 6 neighbors")

func test_disk_center() -> void:
	var d: Array[Vector2i] = HexGrid.disk(Vector2i(0,0), 0)
	assert_eq(d.size(), 1, "Disk radius 0 = 1 tile")

func test_disk_radius1() -> void:
	var d: Array[Vector2i] = HexGrid.disk(Vector2i(0,0), 1)
	assert_eq(d.size(), 7, "Disk radius 1 = 7 tiles")

func test_ring_radius1() -> void:
	var r: Array[Vector2i] = HexGrid.ring(Vector2i(0,0), 1)
	assert_eq(r.size(), 6, "Ring radius 1 = 6 tiles")

func test_pixel_round_trip() -> void:
	var hex: Vector2i = Vector2i(2, -1)
	var px: Vector2 = HexGrid.hex_to_pixel(hex, 40.0)
	var back: Vector2i = HexGrid.pixel_to_hex(px, 40.0)
	assert_eq(back, hex, "Pixel round-trip (2,-1)")

func test_pixel_round_trip_origin() -> void:
	var px: Vector2 = HexGrid.hex_to_pixel(Vector2i(0, 0), 40.0)
	var back: Vector2i = HexGrid.pixel_to_hex(px, 40.0)
	assert_eq(back, Vector2i(0, 0), "Pixel round-trip origin")

func test_disk_radius2() -> void:
	var d: Array[Vector2i] = HexGrid.disk(Vector2i(0, 0), 2)
	assert_eq(d.size(), 19, "Disk radius 2 = 19 tiles")

func test_ring_radius2() -> void:
	var r: Array[Vector2i] = HexGrid.ring(Vector2i(0, 0), 2)
	assert_eq(r.size(), 12, "Ring radius 2 = 12 tiles")

func test_is_in_range() -> void:
	assert_true(HexGrid.is_in_range(Vector2i(0,0), Vector2i(1,0), 1), "Adjacent in range 1")
	assert_true(not HexGrid.is_in_range(Vector2i(0,0), Vector2i(2,0), 1), "Distance 2 not in range 1")
