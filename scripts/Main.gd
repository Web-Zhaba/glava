extends Control

# Верхняя панель
@onready var lbl_date = %LblDate
@onready var lbl_season = %LblSeason
@onready var lbl_budget = %LblBudget
@onready var lbl_people = %LblPeople
@onready var lbl_loyality = %LblLoyality
@onready var lbl_population = %LblPopulation

# Карта
@onready var district_map: DistrictMap = %DistrictMap
@onready var btn_zoom_in = %BtnZoomIn
@onready var btn_zoom_out = %BtnZoomOut
@onready var btn_center_map = %BtnCenterMap

# Правая панель (Кабинет главы)
@onready var tab_btn_events = %BtnTabEvents
@onready var tab_btn_inspector = %BtnTabInspector
@onready var tab_btn_drsu = %BtnTabDrsu

@onready var view_events = %ViewEvents
@onready var view_inspector = %ViewInspector
@onready var view_drsu = %ViewDrsu

# Элементы вкладки событий
@onready var content_area: RichTextLabel = %ContentArea
@onready var choice_container: VBoxContainer = %ChoiceButtons

# Элементы вкладки инспектора
@onready var lbl_inspector_title: Label = %LblInspectorTitle
@onready var lbl_inspector_subtitle: Label = %LblInspectorSubtitle
@onready var inspector_content: RichTextLabel = %InspectorContent
@onready var inspector_actions: VBoxContainer = %InspectorActions

# Элементы вкладки ДРСУ
@onready var drsu_content: RichTextLabel = %DrsuContent
@onready var drsu_actions: VBoxContainer = %DrsuActions

# Нижняя панель
@onready var btn_next_turn: Button = %BtnNextTurn
@onready var lbl_district_status: Label = %LblDistrictStatus

var current_event = null
var current_inspected_object: Dictionary = {}

func _ready() -> void:
	# Очистка контейнеров
	_clear_container(choice_container)
	_clear_container(inspector_actions)
	_clear_container(drsu_actions)
	
	# Подключение кнопок навигации
	btn_next_turn.pressed.connect(_on_btn_next_turn_pressed)
	btn_zoom_in.pressed.connect(func(): district_map._zoom_at(district_map.size * 0.5, 1.25))
	btn_zoom_out.pressed.connect(func(): district_map._zoom_at(district_map.size * 0.5, 0.8))
	btn_center_map.pressed.connect(_center_on_main_town)
	
	# Подключение вкладок кабинета
	tab_btn_events.pressed.connect(func(): _switch_tab("events"))
	tab_btn_inspector.pressed.connect(func(): _switch_tab("inspector"))
	tab_btn_drsu.pressed.connect(func(): _switch_tab("drsu"))
	
	# Сигналы от карты
	district_map.settlement_selected.connect(_on_settlement_selected)
	district_map.poi_selected.connect(_on_poi_selected)
	district_map.incident_selected.connect(_on_incident_selected)
	
	# Сигнал обновления района
	GameState.district_updated.connect(_on_district_updated)
	
	# Начальная инициализация UI
	update_ui()
	_switch_tab("events")
	
	content_area.text = "[b]МУНИЦИПАЛЬНЫЙ ВЕСТНИК И СВОДКА[/b]\n"
	content_area.append_text("Вы официально вступили в должность главы сельского округа в Вологодской области.\n")
	content_area.append_text("На календаре октябрь 2019 года. Впереди осенняя распутица и суровая северная зима. Изучайте просторы района на карте слева, следите за дорогами и котельными.\n\n")
	
	# Выбираем райцентр по умолчанию для инспектора
	if GameState.settlements.has("center"):
		_on_settlement_selected(GameState.settlements["center"])

func _on_district_updated() -> void:
	update_ui()
	if view_inspector.visible and not current_inspected_object.is_empty():
		_refresh_inspector_view()
	if view_drsu.visible:
		_refresh_drsu_view()

func update_ui() -> void:
	lbl_date.text = "🗓 %s %d" % [GameState.month_names[GameState.month - 1], GameState.year]
	lbl_season.text = "Сезон: %s" % GameState.get_season_name()
	
	var budget_col = "white" if GameState.budget >= 500000 else ("yellow" if GameState.budget >= 0 else "crimson")
	lbl_budget.text = "Казна: %s ₽" % _format_number(GameState.budget)
	
	var trust_col = "lightgreen" if GameState.people_trust >= 50 else "salmon"
	lbl_people.text = "Народ: %d%%" % GameState.people_trust
	
	var loy_col = "lightgreen" if GameState.loyality >= 50 else "salmon"
	lbl_loyality.text = "Область: %d%%" % GameState.loyality
	lbl_population.text = "Население: %s чел." % _format_number(GameState.population)
	
	# Нижний статус района
	var blocked_roads_count = GameState.roads.filter(func(r): return r.get("is_blocked", false)).size()
	var critical_heat_count = 0
	for s_id in GameState.settlements:
		if GameState.settlements[s_id].get("heat_fuel", 50) < 25 and GameState.settlements[s_id].get("population", 0) > 0:
			critical_heat_count += 1
			
	var status_text = "Оперативная обстановка: "
	if blocked_roads_count > 0:
		status_text += "⚠ Заблокировано дорог: %d. " % blocked_roads_count
	if critical_heat_count > 0:
		status_text += "🔥 Критический запас топлива в %d поселках. " % critical_heat_count
	if blocked_roads_count == 0 and critical_heat_count == 0:
		status_text += "Штатная. Чрезвычайных происшествий не зафиксировано."
	lbl_district_status.text = status_text

func _switch_tab(tab_name: String) -> void:
	view_events.visible = (tab_name == "events")
	view_inspector.visible = (tab_name == "inspector")
	view_drsu.visible = (tab_name == "drsu")
	
	tab_btn_events.modulate = Color(1.2, 1.2, 1.2) if tab_name == "events" else Color(0.7, 0.7, 0.7)
	tab_btn_inspector.modulate = Color(1.2, 1.2, 1.2) if tab_name == "inspector" else Color(0.7, 0.7, 0.7)
	tab_btn_drsu.modulate = Color(1.2, 1.2, 1.2) if tab_name == "drsu" else Color(0.7, 0.7, 0.7)
	
	if tab_name == "drsu":
		_refresh_drsu_view()

func _center_on_main_town() -> void:
	if GameState.settlements.has("center"):
		var pos = GameState.settlements["center"]["pos"]
		GameState.focus_map_requested.emit(pos)

# ==============================================================================
# ХОД (СЛЕДУЮЩИЙ МЕСЯЦ)
# ==============================================================================

func _on_btn_next_turn_pressed() -> void:
	var logs = GameState.advance_month()
	
	_switch_tab("events")
	content_area.append_text("\n----------------------------------------\n")
	for l in logs:
		content_area.append_text(l + "\n")
		
	check_game_over()
	
	var ev = EventManager.get_random_event(GameState.get_season())
	if ev and not ev.is_empty():
		display_event(ev)
	else:
		btn_next_turn.disabled = false
		
	update_ui()

func display_event(ev: Dictionary) -> void:
	current_event = ev
	btn_next_turn.disabled = true
	
	content_area.append_text("\n[color=crimson][b]ЧРЕЗВЫЧАЙНАЯ СИТУАЦИЯ:[/b][/color] [b]" + ev["title"] + "[/b]\n")
	content_area.append_text(ev["text"] + "\n\n")
	
	# Если событие связано с точкой на карте, фокусируем карту на ней
	if ev.has("map_pos"):
		GameState.focus_map_requested.emit(ev["map_pos"])
		# Добавляем временный инцидент на карту
		GameState.active_incidents.append({
			"id": "event_" + ev["id"],
			"title": ev["title"],
			"pos": ev["map_pos"],
			"type": "event",
			"text": ev["text"]
		})
		district_map.queue_redraw()
	
	_clear_container(choice_container)
	
	# Кнопка быстрой фокусировки на карте
	if ev.has("map_pos"):
		var btn_loc = Button.new()
		btn_loc.text = "🔍 Взглянуть на место происшествия на карте"
		btn_loc.pressed.connect(func(): GameState.focus_map_requested.emit(ev["map_pos"]))
		choice_container.add_child(btn_loc)
	
	for i in range(ev["options"].size()):
		var opt = ev["options"][i]
		var btn = Button.new()
		btn.text = "▶ " + opt["text"]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.pressed.connect(func(): _on_option_chosen(opt))
		choice_container.add_child(btn)

func _on_option_chosen(option: Dictionary) -> void:
	if option.has("effects"):
		var effects: Dictionary = option["effects"]
		GameState.apply_effects(effects)
		var effect_logs: Array[String] = []
		for k in effects:
			var val = effects[k]
			var sign_str = "+" if val > 0 else ""
			match k:
				"loyality": effect_logs.append("Лояльность области: %s%d%%" % [sign_str, val])
				"people_trust": effect_logs.append("Доверие жителей: %s%d%%" % [sign_str, val])
				"budget": effect_logs.append("Казна: %s%s ₽" % [sign_str, _format_number(val)])
				"population": effect_logs.append("Население: %s%d чел." % [sign_str, val])
		if not effect_logs.is_empty():
			content_area.append_text("[color=khaki]Решение исполнено: " + ", ".join(effect_logs) + "[/color]\n\n")
	elif option.has("action"):
		option["action"].call()

	# Удаляем временный маркер текущего события с карты
	if current_event:
		GameState.active_incidents = GameState.active_incidents.filter(func(inc): return inc["id"] != "event_" + current_event["id"])
		current_event = null

	_clear_container(choice_container)
	btn_next_turn.disabled = false
	update_ui()
	district_map.queue_redraw()

# ==============================================================================
# ПАСПОРТ ПОСЕЛЕНИЯ И ОБЪЕКТОВ (ИНСПЕКТОР КАРТЫ)
# ==============================================================================

func _on_settlement_selected(settlement_data: Dictionary) -> void:
	current_inspected_object = {"type": "settlement", "data": settlement_data}
	_switch_tab("inspector")
	_refresh_inspector_view()

func _on_poi_selected(poi_data: Dictionary) -> void:
	current_inspected_object = {"type": "poi", "data": poi_data}
	_switch_tab("inspector")
	_refresh_inspector_view()

func _on_incident_selected(incident_data: Dictionary) -> void:
	_switch_tab("events")
	content_area.append_text("\n[color=yellow][b]ИНСПЕКЦИЯ МЕСТА ЧП:[/b] %s[/color]\n%s\n" % [
		incident_data.get("title", ""),
		incident_data.get("text", "")
	])

func _refresh_inspector_view() -> void:
	_clear_container(inspector_actions)
	
	var type = current_inspected_object.get("type", "")
	var data = current_inspected_object.get("data", {})
	
	if type == "settlement":
		lbl_inspector_title.text = data.get("name", "Поселение")
		lbl_inspector_subtitle.text = "%s • Округ Вологодской области" % data.get("type", "Населенный пункт")
		
		var pop = data.get("population", 0)
		var trust = data.get("trust", 50)
		var heat_status = data.get("heat_status", "Неизвестно")
		var heat_fuel = data.get("heat_fuel", 50)
		var road_status = data.get("road_status", "Грунтовка")
		var desc = data.get("description", "")
		var facilities: Array = data.get("facilities", [])
		
		var bb = "[b]ОПИСАНИЕ:[/b]\n%s\n\n" % desc
		bb += "[b]ПОКАЗАТЕЛИ ПОСЕЛЕНИЯ:[/b]\n"
		bb += "• Население: [b]%s чел.[/b]\n" % (str(pop) if pop > 0 else "Нет постоянных жителей")
		if pop > 0:
			bb += "• Доверие жителей к главе: [color=%s][b]%d%%[/b][/color]\n" % ["lightgreen" if trust >= 50 else "salmon", trust]
			bb += "• Отопление: [b]%s[/b] (Запас топлива: [color=%s]%d%%[/color])\n" % [
				heat_status,
				"lightgreen" if heat_fuel >= 40 else "red",
				heat_fuel
			]
			bb += "• Дорожное сообщение: [b]%s[/b]\n" % road_status
			bb += "• Ключевые объекты: %s\n" % (", ".join(facilities) if not facilities.is_empty() else "Отсутствуют")
		
		inspector_content.text = bb
		
		# Действия главы
		if pop > 0:
			var btn_fuel = Button.new()
			btn_fuel.text = "📦 Завезти партию дров/топлива (50 000 ₽)"
			btn_fuel.pressed.connect(func():
				if GameState.supply_settlement_fuel(data["id"]):
					content_area.append_text("[color=lightgreen]В %s успешно доставлен запас топлива для котельной/печей.[/color]\n" % data["name"])
				else:
					content_area.append_text("[color=red]В казне недостаточно средств для закупки топлива![/color]\n")
			)
			inspector_actions.add_child(btn_fuel)
			
			var btn_inspect = Button.new()
			btn_inspect.text = "🚗 Личный выезд главы с инспекцией"
			btn_inspect.pressed.connect(func():
				data["trust"] = min(100, data["trust"] + 2)
				GameState.apply_effects({"people_trust": 1})
				content_area.append_text("[color=lightblue]Глава лично пообщался с жителями %s на сходе граждан. Доверие выросло.[/color]\n" % data["name"])
				_refresh_inspector_view()
			)
			inspector_actions.add_child(btn_inspect)
			
	elif type == "poi":
		var p_name = data.get("name", "Объект")
		var p_type = data.get("type", "")
		lbl_inspector_title.text = p_name
		lbl_inspector_subtitle.text = "Инфраструктурный объект округа"
		
		var desc = data.get("description", "")
		var bb = "[b]ХАРАКТЕРИСТИКА ОБЪЕКТА:[/b]\n%s\n\n" % desc
		
		if data.has("condition"):
			var cond = int(data["condition"] * 100)
			bb += "• Техническое состояние: [color=%s][b]%d%%[/b][/color]\n" % ["lightgreen" if cond >= 60 else "salmon", cond]
			
		inspector_content.text = bb
		
		if p_type == "bridge":
			var btn_repair = Button.new()
			btn_repair.text = "🔨 Укрепить деревянные сваи моста (80 000 ₽)"
			btn_repair.pressed.connect(func():
				if GameState.budget >= 80000:
					GameState.budget -= 80000
					data["condition"] = min(1.0, data.get("condition", 0.4) + 0.35)
					content_area.append_text("[color=lightgreen]Бригада ДРСУ укрепила сваи деревянного моста через р. Леденьга.[/color]\n")
					GameState.district_updated.emit()
				else:
					content_area.append_text("[color=red]Недостаточно средств в казне района![/color]\n")
			)
			inspector_actions.add_child(btn_repair)
			
		elif p_type == "drsu":
			var btn_goto_drsu = Button.new()
			btn_goto_drsu.text = "🚜 Открыть диспетчерскую техники ДРСУ"
			btn_goto_drsu.pressed.connect(func(): _switch_tab("drsu"))
			inspector_actions.add_child(btn_goto_drsu)
			
		elif p_type == "road":
			var r_data = data.get("road_data", {})
			var btn_road_repair = Button.new()
			btn_road_repair.text = "🚜 Направить грейдер разровнять дорогу (45 000 ₽)"
			btn_road_repair.pressed.connect(func():
				if GameState.send_grader_to_road(r_data.get("id", "")):
					content_area.append_text("[color=lightgreen]Грейдер направлен на участок %s. Дорожное полотно приведено в норму.[/color]\n" % r_data.get("name", ""))
				else:
					content_area.append_text("[color=red]Грейдер сейчас занят на другом участке либо не хватает бюджета![/color]\n")
			)
			inspector_actions.add_child(btn_road_repair)

# ==============================================================================
# ВКЛАДКА ТЕХНИКИ И ДРСУ
# ==============================================================================

func _refresh_drsu_view() -> void:
	_clear_container(drsu_actions)
	
	var bb = "[b]МУНИЦИПАЛЬНОЕ ДРСУ И БАЗА ЖКХ[/b]\n"
	bb += "Гараж дорожного хозяйства обеспечивает проходимость дорог округа и устранение коммунальных аварий.\n\n"
	bb += "[b]ПАРК ТЕХНИКИ:[/b]\n"
	
	for eq_id in GameState.equipment:
		var eq = GameState.equipment[eq_id]
		var status = "Свободен в гараже" if eq["assigned_to"] == "" else ("Занят на участке: " + eq["assigned_to"])
		var st_col = "lightgreen" if eq["assigned_to"] == "" else "yellow"
		bb += "• [b]%s[/b]: [color=%s]%s[/color] (Износ: %d%%)\n" % [eq["name"], st_col, status, 100 - eq["condition"]]
		
	drsu_content.text = bb
	
	# Доступные дорожные участки для направления грейдера
	var btn_grade_yurmanga = Button.new()
	btn_grade_yurmanga.text = "🚜 Пустить грейдер по Юрмангскому тракту (45 000 ₽)"
	btn_grade_yurmanga.pressed.connect(func():
		if GameState.send_grader_to_road("yurmanga_tract"):
			content_area.append_text("[color=lightgreen]Грейдер ДРСУ разровнял глубокую колею на Юрмангском тракте.[/color]\n")
			_refresh_drsu_view()
		else:
			content_area.append_text("[color=salmon]Грейдер уже задействован в этом месяце или не хватает бюджета.[/color]\n")
	)
	drsu_actions.add_child(btn_grade_yurmanga)
	
	var btn_grade_kokshenga = Button.new()
	btn_grade_kokshenga.text = "🚜 Пустить грейдер на Кокшеньгский просёлок (45 000 ₽)"
	btn_grade_kokshenga.pressed.connect(func():
		if GameState.send_grader_to_road("kokshenga_road"):
			content_area.append_text("[color=lightgreen]Грейдер ДРСУ прошел просёлок до Кокшеньги.[/color]\n")
			_refresh_drsu_view()
		else:
			content_area.append_text("[color=salmon]Грейдер уже задействован в этом месяце или не хватает бюджета.[/color]\n")
	)
	drsu_actions.add_child(btn_grade_kokshenga)

# ==============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ==============================================================================

func check_game_over() -> void:
	if GameState.loyality <= 0:
		content_area.append_text("\n[color=red][b]ОТСТАВКА:[/b] Указом Губернатора Вологодской области вы отрешены от должности в связи с утратой доверия.[/color]\n")
		btn_next_turn.disabled = true
	elif GameState.budget < -2_500_000:
		content_area.append_text("\n[color=red][b]БАНКРОТСТВО:[/b] Муниципальные счета арестованы казначейством, прокуратура возбудила уголовное дело за долги.[/color]\n")
		btn_next_turn.disabled = true

func _format_number(n: int) -> String:
	var s = str(abs(n))
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = " " + res
	return ("-" if n < 0 else "") + res

func _clear_container(c: Node) -> void:
	for child in c.get_children():
		child.queue_free()
