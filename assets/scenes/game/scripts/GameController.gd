extends Node2D

var tile_map: GameTileMap = null
var last_cell: Vector2i
var has_last_cell: bool = false
var last_reachables: Array = []
var last_attackables: Array = []
var class_select_ui
var tile_info_ui
var player_sprites: Dictionary = {}

var is_loading_map_scene: bool = false
var map_scene_path: String

func _ready():
	EventBus.game_started.connect(_game_started_handler)

func _exit_tree():
	EventBus.class_select_ui_freed.emit()
	tile_info_ui.queue_free()

func load_map(scene_path):
	ResourceLoader.load_threaded_request(scene_path)
	map_scene_path = scene_path
	is_loading_map_scene = true

func resolve_load_map():
	if is_loading_map_scene == false:
		return
	if ResourceLoader.load_threaded_get_status(map_scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if ResourceLoader.load_threaded_get_status(map_scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
		print("ERROR loading resources")
		is_loading_map_scene = false
		return
	var map_scene = ResourceLoader.load_threaded_get(map_scene_path) as PackedScene
	tile_map = map_scene.instantiate()
	add_child(tile_map)
	move_child(tile_map, 0)
	is_loading_map_scene = false
	class_select_ui = Main.add_ui(Global.Constant.Scene.CLASS_SELECT_UI, 0)
	tile_info_ui = Main.add_ui(Global.Constant.Scene.TILE_INFO_UI, 0)
	print(a_star(Vector2(-3, 2), Vector2(-2, -4)))


func _process(_delta):
	resolve_load_map()


func _input(event):
	if tile_map == null:
		return
	if event is InputEventMouseMotion:
		# get tm coord/"index" of tile
		var clicked_cell: Vector2i = tile_map.local_to_map(get_global_mouse_position())
		# get source id in tileset of said tile
		var tss_id: int = tile_map.get_cell_source_id(0, clicked_cell)
		# if not empty
		if tss_id != -1:
			# add select tile to tm layer 2
			tile_map.set_cell(2, clicked_cell, 2, Vector2i(0, 0))
			# when mouse leave tile basically
			# remove select tile on tm layer 2
			if has_last_cell == true && clicked_cell != last_cell:
				tile_map.set_cell(2, last_cell, -1, tile_map.get_cell_atlas_coords(0, last_cell))
				self.highlight_tiles(self.last_reachables, false)
				# self.highlight_tiles(self.last_attackables, false)
			if has_last_cell == false || clicked_cell != last_cell:
				# grab td
				var tile_data: TileData = tile_map.get_cell_tile_data(0, clicked_cell)
				# send info of td to ui
				var texture = tile_map.tile_set.get_source(0).texture
				var atlas_coord = tile_map.get_cell_atlas_coords(0, clicked_cell) as Vector2
				var tile_name = tile_data.get_custom_data("name")
				var tile_desc = tile_data.get_custom_data("description")
				EventBus.game_tile_hovered.emit(texture, atlas_coord, tile_name, tile_desc)
				self.last_reachables = self.get_reachable_tiles(clicked_cell, 2)
				self.highlight_tiles(self.last_reachables, true)
				# self.last_attackables = self.get_attackable_tiles(clicked_cell, 7)
				# self.highlight_tiles(self.last_attackables, true)
			# save current cell info to check against when "leaving"
			last_cell = clicked_cell
			has_last_cell = true

func get_ap_cost(coord):
	if self.tile_map == null:
		return -1
	var tss_id: int = tile_map.get_cell_source_id(0, coord)
	if tss_id == -1:
		return -1
	var tile_data: TileData = tile_map.get_cell_tile_data(0, coord)
	return tile_data.get_custom_data("ap_cost")

func get_reachable_tiles(source: Vector2i, ap: int):
	var reachables = Global.Set.new()
	var cache = {}
	var next_tiles = [[Vector2i(source.x - 1, source.y), 2], [Vector2i(source.x, source.y - 1), 3], [Vector2i(source.x + 1, source.y), 0], [Vector2i(source.x, source.y + 1), 1]]
	for next_tile in next_tiles:
		var next_coord = next_tile[0]
		var coming_from = next_tile[1]
		self.traverse(ap, next_coord, reachables, coming_from, cache)
	return reachables.items()

func traverse(ap, coord, reachables, coming_from, cache):
	var ap_cost = get_ap_cost(coord)
	if ap_cost == -1:
		return
	if cache.has(coord):
		if cache[coord] >= ap:
			return
	else:
		cache[coord] = ap
	if ap_cost <= ap:
		ap = ap - ap_cost
		reachables.add(coord)
	else:
		return
	var next_tiles = [[Vector2i(coord.x - 1, coord.y), 2], [Vector2i(coord.x, coord.y - 1), 3], [Vector2i(coord.x + 1, coord.y), 0], [Vector2i(coord.x, coord.y + 1), 1]]
	next_tiles.pop_at(coming_from)
	for next_tile in next_tiles:
		var next_coord = next_tile[0]
		var next_coming_from = next_tile[1]
		self.traverse(ap, next_coord, reachables, next_coming_from, cache)

func highlight_tiles(list_of_coords, do_highlight, highlight_atlas_coord = Vector2i(0, 0)):
	for coord in list_of_coords:
		self.tile_map.set_cell(1, coord, 1 if do_highlight else -1, highlight_atlas_coord)

func get_attackable_tiles(source: Vector2i, attack_range: int): # say range of 3
	var attackables = Global.Set.new()
	for x in range(-attack_range, attack_range + 1): # x is [-3; 3]
		var y_leftover = attack_range - abs(x) # we want y to be 0, 1, 2, 3, 2, 1, 0 given that range of x
		for y in range(-y_leftover, y_leftover + 1):
			var tile_coord = Vector2i(source.x + x, source.y + y)
			attackables.add(tile_coord)
	return attackables.items()


func a_star_h(node_mapgrid: Vector2, goal_mapgrid: Vector2):
	return abs(node_mapgrid.x - goal_mapgrid.x) + abs(node_mapgrid.y - goal_mapgrid.y)


func a_star(start_mapgrid: Vector2, goal_mapgrid: Vector2):
	var pq: Global.PriorityQueue = Global.PriorityQueue.new()
	var came_from: Dictionary = {}
	var g_score: Dictionary = {} # cheapest cost from start to n

	pq.insert(start_mapgrid, a_star_h(start_mapgrid, goal_mapgrid))
	g_score[start_mapgrid] = 0

	while not pq.is_empty():
		var current_node: Vector2 = pq.pop()
		print("New loop")
		print(current_node)
		if current_node == goal_mapgrid:
			var path = [current_node]
			while current_node in came_from.keys():
				current_node = came_from[current_node]
				path.insert(0, current_node)
				print(path)
			return true

		for neighbor_offset in [Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0), Vector2(0, 1)]:
			var neighbor_node = current_node + neighbor_offset
			print(neighbor_node)
			var temp_g_score = g_score[current_node] + tile_map.get_ap_cost_at(neighbor_node)
			if not neighbor_node in g_score.keys() or temp_g_score < g_score[neighbor_node]:
				g_score[neighbor_node] = temp_g_score
				came_from[neighbor_node] = current_node
				if not pq.has(neighbor_node):
					pq.insert(neighbor_node, temp_g_score + a_star_h(neighbor_node, goal_mapgrid))
	return false


func _game_started_handler(game_state: GameState):
	EventBus.class_select_ui_freed.emit()
	for pid in game_state.player_dict:
		var player_sprite_ps = load("res://assets/scenes/game/resources/player_sprite_prefab_m14.tscn") as PackedScene
		var player_sprite: GamePlayerSprite = player_sprite_ps.instantiate()
		player_sprite.set_mapgrid_pos(game_state.player_dict[pid].player_game_data.mapgrid_position)
		add_child(player_sprite)
		player_sprites[pid] = player_sprite
	EventBus.camera_panned.emit(game_state.player_dict[Main.root_mp.get_unique_id()].player_game_data.mapgrid_position * 32 + Vector2(16, 16))
