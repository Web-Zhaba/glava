extends Control
class_name DistrictMap

signal settlement_selected(settlement_data: Dictionary)
signal poi_selected(poi_data: Dictionary)
signal incident_selected(incident_data: Dictionary)

# Параметры камеры / навигации
var camera_offset: Vector2 = Vector2(-80, -40)
var target_offset: Vector2 = Vector2(-80, -40)
var zoom_level: float = 1.0
var target_zoom: float = 1.0
const MIN_ZOOM: float = 0.55
const MAX_ZOOM: float = 2.4

var is_dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_offset: Vector2 = Vector2.ZERO

# Состояние наведения и выбора
var hovered_item: Dictionary = {}
var selected_item: Dictionary = {}

# Тултип
var tooltip_panel: PanelContainer
var tooltip_label: RichTextLabel

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	
	_setup_tooltip()
	
	GameState.district_updated.connect(queue_redraw)
	GameState.focus_map_requested.connect(_on_focus_requested)
	
	# Начальное центрирование на райцентре с задержкой в 1 кадр
	call_deferred("_center_on_start")

func _center_on_start() -> void:
	if GameState.settlements.has("center"):
		var center_pos = GameState.settlements["center"]["pos"]
		target_zoom = 1.05
		zoom_level = 1.05
		target_offset = (size * 0.5) - (center_pos * target_zoom)
		camera_offset = target_offset
		queue_redraw()

func _setup_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.15, 0.94)
	style.border_color = Color(0.65, 0.72, 0.8, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	tooltip_panel.add_theme_stylebox_override("panel", style)
	
	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tooltip_label.custom_minimum_size = Vector2(250, 40)
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	tooltip_panel.add_child(tooltip_label)
	add_child(tooltip_panel)

func _get_map_font() -> Font:
	var f = get_theme_default_font()
	if f:
		return f
	return ThemeDB.fallback_font

func _process(delta: float) -> void:
	camera_offset = camera_offset.lerp(target_offset, delta * 14.0)
	zoom_level = lerp(zoom_level, target_zoom, delta * 14.0)
	
	queue_redraw()
	
	if tooltip_panel.visible:
		var mouse_pos = get_local_mouse_position()
		var tip_pos = mouse_pos + Vector2(18, 18)
		if tip_pos.x + tooltip_panel.size.x > size.x:
			tip_pos.x = mouse_pos.x - tooltip_panel.size.x - 12
		if tip_pos.y + tooltip_panel.size.y > size.y:
			tip_pos.y = mouse_pos.y - tooltip_panel.size.y - 12
		tooltip_panel.position = tip_pos

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				var clicked = _find_item_at_position(world_to_screen_inv(mb.position))
				if clicked.is_empty():
					is_dragging = true
					drag_start_mouse = mb.position
					drag_start_offset = target_offset
				else:
					_handle_click_item(clicked)
			else:
				if is_dragging:
					is_dragging = false
		
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
			
	elif event is InputEventMouseMotion:
		var mm = event as InputEventMouseMotion
		if is_dragging:
			var diff = mm.position - drag_start_mouse
			target_offset = drag_start_offset + diff
		else:
			_update_hover(world_to_screen_inv(mm.position))

func _zoom_at(screen_point: Vector2, factor: float) -> void:
	var prev_zoom = target_zoom
	var new_zoom = clamp(target_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(new_zoom, prev_zoom):
		return
	
	var world_point = (screen_point - target_offset) / prev_zoom
	target_zoom = new_zoom
	target_offset = screen_point - (world_point * target_zoom)

func world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos * zoom_level) + camera_offset

func world_to_screen_inv(screen_pos: Vector2) -> Vector2:
	return (screen_pos - camera_offset) / zoom_level

func _find_item_at_position(world_pos: Vector2) -> Dictionary:
	var hit_radius = 28.0 / zoom_level
	
	# 1. Инциденты
	for inc in GameState.active_incidents:
		var pos: Vector2 = inc.get("pos", Vector2.ZERO)
		if pos.distance_to(world_pos) <= hit_radius:
			return {"type": "incident", "data": inc}
			
	# 2. Населенные пункты
	for s_id in GameState.settlements:
		var s = GameState.settlements[s_id]
		var pos: Vector2 = s.get("pos", Vector2.ZERO)
		if pos.distance_to(world_pos) <= hit_radius + 4.0:
			return {"type": "settlement", "data": s}
			
	# 3. POI
	for poi in GameState.pois:
		var pos: Vector2 = poi.get("pos", Vector2.ZERO)
		if pos.distance_to(world_pos) <= hit_radius:
			return {"type": "poi", "data": poi}
			
	# 4. Дороги
	for road in GameState.roads:
		var from_pos: Vector2 = road.get("from", Vector2.ZERO)
		var to_pos: Vector2 = road.get("to", Vector2.ZERO)
		var closest = Geometry2D.get_closest_point_to_segment(world_pos, from_pos, to_pos)
		if closest.distance_to(world_pos) <= (14.0 / zoom_level):
			return {"type": "road", "data": road}
			
	return {}

func _update_hover(world_pos: Vector2) -> void:
	var found = _find_item_at_position(world_pos)
	if found != hovered_item:
		hovered_item = found
		if hovered_item.is_empty():
			tooltip_panel.visible = false
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_show_tooltip_for(hovered_item)

func _show_tooltip_for(item: Dictionary) -> void:
	var type = item.get("type", "")
	var data = item.get("data", {})
	var bb = ""
	
	match type:
		"settlement":
			var pop = data.get("population", 0)
			var trust = data.get("trust", 50)
			var heat_fuel = data.get("heat_fuel", 50)
			var status = data.get("status_tag", "Штатно")
			var color_trust = "lightgreen" if trust >= 55 else ("yellow" if trust >= 35 else "salmon")
			
			bb = "[b][font_size=15]%s[/font_size][/b] (%s)\n" % [data.get("name", ""), data.get("type", "")]
			bb += "Статус: [color=cyan]%s[/color]\n" % status
			if pop > 0:
				bb += "Население: [b]%d чел.[/b]\n" % pop
				bb += "Доверие жителей: [color=%s][b]%d%%[/b][/color]\n" % [color_trust, trust]
				bb += "Запас тепла / дров: [b]%d%%[/b]\n" % heat_fuel
			else:
				bb += "[color=gray]Заброшенное урочище[/color]\n"
			bb += "[color=silver][font_size=11]Нажмите для паспорта поселения[/font_size][/color]"
			
		"poi":
			bb = "[b][font_size=14]%s[/font_size][/b]\n" % data.get("name", "")
			bb += "[color=gray]%s[/color]\n" % data.get("description", "")
			if data.has("condition"):
				var cond = int(data["condition"] * 100)
				var c_col = "lightgreen" if cond >= 60 else ("yellow" if cond >= 40 else "salmon")
				bb += "Состояние объекта: [color=%s][b]%d%%[/b][/color]\n" % [c_col, cond]
			bb += "[color=silver][font_size=11]Нажмите для взаимодействия[/font_size][/color]"
			
		"incident":
			bb = "[color=crimson][b]⚠ ЧРЕЗВЫЧАЙНАЯ СИТУАЦИЯ[/b][/color]\n"
			bb += "[b]%s[/b]\n" % data.get("title", "")
			bb += "%s\n" % data.get("text", "")
			bb += "[color=yellow][font_size=11]Нажмите, чтобы среагировать[/font_size][/color]"
			
		"road":
			var cond = int(data.get("condition", 0.5) * 100)
			var blocked = data.get("is_blocked", false)
			var c_col = "red" if blocked else ("lightgreen" if cond >= 65 else ("yellow" if cond >= 40 else "orange"))
			bb = "[b]%s[/b]\n" % data.get("name", "")
			if blocked:
				bb += "[color=red][b]ДОРОГА ЗАБЛОКИРОВАНА![/b][/color]\n"
			else:
				bb += "Проходимость: [color=%s][b]%d%%[/b][/color]\n" % [c_col, cond]
			bb += "[color=silver][font_size=11]Кликните, чтобы направить грейдер[/font_size][/color]"
			
	tooltip_label.text = bb
	tooltip_panel.visible = true

func _handle_click_item(item: Dictionary) -> void:
	selected_item = item
	var type = item.get("type", "")
	var data = item.get("data", {})
	
	match type:
		"settlement":
			settlement_selected.emit(data)
		"poi":
			poi_selected.emit(data)
		"incident":
			incident_selected.emit(data)
		"road":
			poi_selected.emit({"type": "road", "road_data": data, "name": data.get("name", "")})

func _on_focus_requested(world_pos: Vector2) -> void:
	target_zoom = 1.35
	target_offset = (size * 0.5) - (world_pos * target_zoom)

# ==============================================================================
# ОТРИСОВКА КАРТЫ
# ==============================================================================

func _draw() -> void:
	var season = GameState.get_season()
	var time_ms = Time.get_ticks_msec() * 0.001
	
	# Фоновая подложка
	var bg_color = Color(0.18, 0.22, 0.20)
	match season:
		"winter": bg_color = Color(0.24, 0.27, 0.32)
		"spring": bg_color = Color(0.19, 0.23, 0.19)
		"summer": bg_color = Color(0.17, 0.24, 0.18)
		"autumn": bg_color = Color(0.21, 0.22, 0.19)
			
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)
	
	_draw_coordinate_grid()
	_draw_swamps()
	_draw_forests(season)
	_draw_rivers(season)
	_draw_roads(season)
	_draw_bridges()
	_draw_pois()
	_draw_settlements()
	_draw_incidents(time_ms)
	_draw_map_hud_decorations()

func _draw_coordinate_grid() -> void:
	var grid_step = 150.0 * zoom_level
	if grid_step < 20.0:
		return
	var grid_color = Color(1, 1, 1, 0.04)
	
	var start_x = fmod(camera_offset.x, grid_step)
	if start_x < 0:
		start_x += grid_step
	var start_y = fmod(camera_offset.y, grid_step)
	if start_y < 0:
		start_y += grid_step
	
	var x = start_x
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += grid_step
		
	var y = start_y
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += grid_step

func _draw_swamps() -> void:
	var swamp_color = Color(0.16, 0.20, 0.24, 0.6)
	var hatch_color = Color(0.35, 0.45, 0.50, 0.4)
	for poly in DistrictData.get_swamp_polygons():
		var screen_poly = PackedVector2Array()
		for pt in poly:
			screen_poly.append(world_to_screen(pt))
		if screen_poly.size() >= 3:
			draw_colored_polygon(screen_poly, swamp_color)
			var center = screen_poly[0]
			for k in range(1, screen_poly.size()):
				center += screen_poly[k]
			center /= screen_poly.size()
			for i in range(-2, 3):
				var h_start = center + Vector2(-30 * zoom_level, i * 10 * zoom_level)
				var h_end = center + Vector2(30 * zoom_level, i * 10 * zoom_level)
				draw_line(h_start, h_end, hatch_color, 1.5 * zoom_level)

func _draw_forests(season: String) -> void:
	var forest_col = Color(0.12, 0.17, 0.13, 0.85)
	if season == "winter":
		forest_col = Color(0.14, 0.19, 0.18, 0.85)
	elif season == "autumn":
		forest_col = Color(0.17, 0.18, 0.12, 0.85)
		
	for poly in DistrictData.get_forest_polygons():
		var screen_poly = PackedVector2Array()
		for pt in poly:
			screen_poly.append(world_to_screen(pt))
		if screen_poly.size() >= 3:
			draw_colored_polygon(screen_poly, forest_col)
			draw_polyline(screen_poly, Color(0.25, 0.35, 0.26, 0.5), 1.5 * zoom_level, true)
			
			# Символические силуэты северных елей внутри массива
			if zoom_level >= 0.75:
				var center = screen_poly[0]
				for k in range(1, screen_poly.size()):
					center += screen_poly[k]
				center /= screen_poly.size()
				_draw_fir_tree(center + Vector2(-20, -10) * zoom_level, 6.0 * zoom_level)
				_draw_fir_tree(center + Vector2(25, 15) * zoom_level, 7.0 * zoom_level)
				_draw_fir_tree(center + Vector2(5, -25) * zoom_level, 5.0 * zoom_level)

func _draw_fir_tree(pos: Vector2, sz: float) -> void:
	var col = Color(0.18, 0.28, 0.19, 0.7)
	var pts = PackedVector2Array([
		pos + Vector2(0, -sz),
		pos + Vector2(sz * 0.7, sz),
		pos + Vector2(-sz * 0.7, sz)
	])
	draw_colored_polygon(pts, col)

func _draw_rivers(season: String) -> void:
	var is_winter = (season == "winter")
	var river_water_col = Color(0.20, 0.45, 0.65, 0.95)
	var river_ice_col = Color(0.70, 0.82, 0.92, 0.95)
	var river_col = river_ice_col if is_winter else river_water_col
	
	# р. Леденьга
	var ledenga_pts = DistrictData.get_river_ledenga_points()
	var screen_pts = PackedVector2Array()
	for p in ledenga_pts:
		screen_pts.append(world_to_screen(p))
		
	draw_polyline(screen_pts, Color(0.12, 0.22, 0.30, 0.8), (14.0 * zoom_level), false)
	draw_polyline(screen_pts, river_col, (9.0 * zoom_level), false)
	if is_winter:
		draw_polyline(screen_pts, Color(0.9, 0.95, 1.0, 0.6), (2.0 * zoom_level), false)
	
	# р. Юрманга
	var yurmanga_pts = DistrictData.get_river_yurmanga_points()
	var screen_y_pts = PackedVector2Array()
	for p in yurmanga_pts:
		screen_y_pts.append(world_to_screen(p))
	draw_polyline(screen_y_pts, Color(0.12, 0.22, 0.30, 0.8), (8.0 * zoom_level), false)
	draw_polyline(screen_y_pts, river_col, (5.0 * zoom_level), false)
	
	var font = _get_map_font()
	var led_label_pos = world_to_screen(Vector2(290, 780))
	draw_string(font, led_label_pos, "р. Леденьга", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * zoom_level), Color(0.6, 0.8, 1.0, 0.75))
	
	var yur_label_pos = world_to_screen(Vector2(780, 270))
	draw_string(font, yur_label_pos, "р. Юрманга", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * zoom_level), Color(0.6, 0.8, 1.0, 0.75))

func _draw_roads(season: String) -> void:
	for r in GameState.roads:
		var p1 = world_to_screen(r["from"])
		var p2 = world_to_screen(r["to"])
		var type = r.get("type", "dirt")
		var cond = r.get("condition", 0.5)
		var blocked = r.get("is_blocked", false)
		
		match type:
			"highway":
				draw_line(p1, p2, Color(0.15, 0.15, 0.15), 7.0 * zoom_level)
				draw_line(p1, p2, Color(0.35, 0.35, 0.38), 5.0 * zoom_level)
				draw_dashed_line(p1, p2, Color(1, 1, 1, 0.7), 1.0 * zoom_level, 6.0 * zoom_level)
			"gravel":
				var base_col = Color(0.48, 0.40, 0.30)
				if cond < 0.4:
					base_col = Color(0.40, 0.30, 0.22)
				draw_line(p1, p2, Color(0.2, 0.18, 0.15), 5.5 * zoom_level)
				draw_line(p1, p2, base_col, 4.0 * zoom_level)
				if blocked:
					draw_dashed_line(p1, p2, Color.RED, 2.0 * zoom_level, 5.0 * zoom_level)
			"dirt":
				var dirt_col = Color(0.42, 0.35, 0.25)
				if season == "autumn":
					dirt_col = Color(0.32, 0.25, 0.18)
				draw_line(p1, p2, Color(0.18, 0.14, 0.1), 3.5 * zoom_level)
				draw_line(p1, p2, dirt_col, 2.5 * zoom_level)
				if blocked:
					draw_dashed_line(p1, p2, Color.CRIMSON, 2.0 * zoom_level, 4.0 * zoom_level)
			"winter":
				if season == "winter":
					draw_dashed_line(p1, p2, Color(0.85, 0.92, 1.0, 0.9), 3.0 * zoom_level, 6.0 * zoom_level)
				else:
					draw_dashed_line(p1, p2, Color(0.3, 0.3, 0.3, 0.4), 1.5 * zoom_level, 8.0 * zoom_level)

func _draw_bridges() -> void:
	for poi in GameState.pois:
		if poi.get("type") == "bridge":
			var p = world_to_screen(poi["pos"])
			draw_circle(p, 8.0 * zoom_level, Color(0.35, 0.25, 0.18))
			draw_line(p + Vector2(-9, -9) * zoom_level, p + Vector2(9, 9) * zoom_level, Color(0.65, 0.50, 0.35), 3.0 * zoom_level)
			draw_line(p + Vector2(-9, 9) * zoom_level, p + Vector2(9, -9) * zoom_level, Color(0.65, 0.50, 0.35), 3.0 * zoom_level)

func _draw_pois() -> void:
	var font = _get_map_font()
	for poi in GameState.pois:
		if poi.get("type") == "bridge":
			continue
		var p = world_to_screen(poi["pos"])
		var type = poi.get("type", "")
		var col = Color(0.85, 0.75, 0.35)
		
		match type:
			"industry": col = Color(0.85, 0.45, 0.25)
			"landfill": col = Color(0.65, 0.40, 0.40)
			"drsu": col = Color(0.35, 0.75, 0.85)
			"ferry": col = Color(0.40, 0.65, 0.85)
			
		var sz = 6.0 * zoom_level
		var diamond = PackedVector2Array([
			p + Vector2(0, -sz),
			p + Vector2(sz, 0),
			p + Vector2(0, sz),
			p + Vector2(-sz, 0)
		])
		draw_colored_polygon(diamond, col)
		draw_polyline(diamond, Color.BLACK, 1.0 * zoom_level, true)
		
		if zoom_level >= 0.8:
			var txt_pos = p + Vector2(sz + 3, sz * 0.5)
			draw_string(font, txt_pos, poi["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * zoom_level), Color(0.85, 0.85, 0.85, 0.8))

func _draw_settlements() -> void:
	var font = _get_map_font()
	for s_id in GameState.settlements:
		var s = GameState.settlements[s_id]
		var p = world_to_screen(s["pos"])
		var pop = s.get("population", 0)
		var is_center = (s_id == "center")
		var is_abandoned = (pop == 0)
		
		var r = (12.0 if is_center else (8.0 if pop > 300 else 6.0)) * zoom_level
		
		var fill_col = Color(0.9, 0.85, 0.7)
		if is_center:
			fill_col = Color(0.95, 0.35, 0.25)
		elif is_abandoned:
			fill_col = Color(0.4, 0.4, 0.4, 0.6)
		elif s.get("type") == "Лесной посёлок":
			fill_col = Color(0.3, 0.7, 0.85)
			
		if hovered_item.get("data") == s:
			draw_circle(p, r + (5.0 * zoom_level), Color(1.0, 1.0, 0.4, 0.5))
		if selected_item.get("data") == s:
			draw_arc(p, r + (7.0 * zoom_level), 0, TAU, 32, Color(0.3, 1.0, 0.4), 2.5 * zoom_level)
			
		if s.get("heat_fuel", 50) < 25 and not is_abandoned:
			var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
			draw_circle(p, r + (8.0 * zoom_level), Color(1.0, 0.1, 0.1, 0.35 * pulse))
			
		draw_circle(p, r, fill_col)
		draw_arc(p, r, 0, TAU, 24, Color(0.1, 0.1, 0.1, 0.9), 1.5 * zoom_level)
		
		if is_center:
			draw_circle(p, r * 0.4, Color.WHITE)
		elif is_abandoned:
			draw_line(p + Vector2(-3, 0) * zoom_level, p + Vector2(3, 0) * zoom_level, Color.WHITE, 1.5 * zoom_level)
			draw_line(p + Vector2(0, -4) * zoom_level, p + Vector2(0, 3) * zoom_level, Color.WHITE, 1.5 * zoom_level)
			
		var font_size = int((14.0 if is_center else 12.0) * clamp(zoom_level, 0.7, 1.3))
		var name_str = s["name"]
		var text_sz = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var label_pos = p + Vector2(-text_sz.x * 0.5, -r - 5.0 * zoom_level)
		
		draw_string(font, label_pos + Vector2(1, 1), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
		var text_col = Color(1.0, 0.95, 0.8) if not is_abandoned else Color(0.65, 0.65, 0.65)
		draw_string(font, label_pos, name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
		
		if pop > 0 and zoom_level >= 0.75:
			var sub_str = "%d чел." % pop
			var sub_size = int(10 * clamp(zoom_level, 0.7, 1.1))
			var sub_sz = font.get_string_size(sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size)
			var sub_pos = p + Vector2(-sub_sz.x * 0.5, r + sub_size + 4.0 * zoom_level)
			draw_string(font, sub_pos + Vector2(1, 1), sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(0, 0, 0, 0.8))
			draw_string(font, sub_pos, sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(0.75, 0.85, 0.95))

func _draw_incidents(time_ms: float) -> void:
	for inc in GameState.active_incidents:
		var pos = inc.get("pos", Vector2.ZERO)
		var p = world_to_screen(pos)
		var pulse = (sin(time_ms * 6.0) + 1.0) * 0.5
		
		var sz = (10.0 + (pulse * 4.0)) * zoom_level
		draw_circle(p, sz + 4.0, Color(1.0, 0.2, 0.2, 0.4 * (1.0 - pulse)))
		
		var tri = PackedVector2Array([
			p + Vector2(0, -sz),
			p + Vector2(sz * 0.9, sz * 0.7),
			p + Vector2(-sz * 0.9, sz * 0.7)
		])
		draw_colored_polygon(tri, Color(1.0, 0.8, 0.1))
		draw_polyline(tri, Color.BLACK, 1.5 * zoom_level, true)
		
		var font = _get_map_font()
		draw_string(font, p + Vector2(-2, 3), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * zoom_level), Color.BLACK)

func _draw_map_hud_decorations() -> void:
	var font = _get_map_font()
	
	# Верхняя плашка названия карты
	var title_box = Rect2(Vector2(20, 20), Vector2(340, 46))
	draw_rect(title_box, Color(0.08, 0.12, 0.15, 0.85))
	draw_rect(title_box, Color(0.4, 0.5, 0.6, 0.6), false, 1.5)
	draw_string(font, Vector2(34, 48), "КАРТА СЕЛЬСКОГО ОКРУГА", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.95, 0.95))
	
	# Масштабная линейка
	var km_len = 100.0 * zoom_level
	var scale_start = Vector2(30, size.y - 30)
	draw_line(scale_start, scale_start + Vector2(km_len, 0), Color.WHITE, 2.0)
	draw_line(scale_start + Vector2(0, -5), scale_start + Vector2(0, 5), Color.WHITE, 2.0)
	draw_line(scale_start + Vector2(km_len, -5), scale_start + Vector2(km_len, 5), Color.WHITE, 2.0)
	draw_string(font, scale_start + Vector2(10, -8), "Масштаб: 10 км", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.85))
	
	# Роза ветров (Север)
	var compass_center = Vector2(size.x - 50, 60)
	draw_circle(compass_center, 22, Color(0.08, 0.12, 0.15, 0.8))
	draw_arc(compass_center, 22, 0, TAU, 32, Color(0.5, 0.6, 0.7, 0.7), 1.5)
	var north_arrow = PackedVector2Array([
		compass_center + Vector2(0, -18),
		compass_center + Vector2(5, 0),
		compass_center,
		compass_center + Vector2(-5, 0)
	])
	draw_colored_polygon(north_arrow, Color(0.9, 0.25, 0.25))
	var south_arrow = PackedVector2Array([
		compass_center + Vector2(0, 18),
		compass_center + Vector2(5, 0),
		compass_center,
		compass_center + Vector2(-5, 0)
	])
	draw_colored_polygon(south_arrow, Color(0.7, 0.7, 0.7))
	draw_string(font, compass_center + Vector2(-4, -22), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
