extends Node
class_name TurnManager

static func advance_month() -> Array[String]:
	var logs: Array[String] = []
	
	GameState.month += 1
	if GameState.month > 12:
		GameState.year += 1
		GameState.month = 1
		
	var season_name = GameState.get_season_name()
	logs.append("[b]== Новый отчетный период: %s %d (%s) ==[/b]" % [
		GameState.month_names[GameState.month - 1],
		GameState.year,
		season_name
	])
	
	# Финансовый расчет
	var income = 420_000 + int(GameState.population * 45)
	var expense = 450_000
	
	# Зимние расходы на отопление и противогололедные реагенты
	var is_winter = GameState.month in [11, 12, 1, 2, 3]
	if is_winter:
		expense += 220_000
		logs.append("[color=lightblue]❄ Зимний период: повышенные расходы на топливо для котельных и уборку снега (+220 000 ₽)[/color]")
	
	GameState.budget += (income - expense)
	var sign_bal = "+" if (income - expense) >= 0 else ""
	logs.append("Баланс месяца: [b]%s%d ₽[/b] (Доходы: %d ₽ | Расходы: %d ₽)" % [
		sign_bal,
		income - expense,
		income,
		expense
	])
	
	# Освобождаем технику на новый месяц
	for eq_id in GameState.equipment:
		GameState.equipment[eq_id]["assigned_to"] = ""
	
	# Очищаем временные мелкие инциденты прошлого месяца
	GameState.active_incidents = GameState.active_incidents.filter(func(inc): return inc.get("persistent", false))
	
	# Моделирование дорог и поселений под влиянием сезона
	match GameState.get_season():
		"autumn":
			# Дожди размывают грунтовки
			for r in GameState.roads:
				if r["type"] in ["gravel", "dirt"]:
					r["condition"] = max(0.1, r["condition"] - 0.15)
			logs.append("[color=khaki]🌧 Осенняя распутица: проселочные и гравийные дороги размыты дождями.[/color]")
		"winter":
			# Снежные заносы
			for r in GameState.roads:
				if r["type"] == "winter":
					# Зимник замерз и стал проезжим, но требует расчистки
					r["condition"] = max(0.5, r["condition"])
				elif r["type"] == "dirt" and randf() < 0.4:
					r["is_blocked"] = true
					logs.append("[color=crimson]⚠ Снегопад перемёл просёлок к отдаленным деревням![/color]")
					GameState.active_incidents.append({
						"id": "snow_block_" + r["id"],
						"title": "Снежный занос: " + r["name"],
						"pos": (r["from"] + r["to"]) * 0.5,
						"type": "snow",
						"text": "Дорога занесена снегом. Требуется грейдер ДРСУ, иначе школьный автобус и автолавка не пройдут."
					})
		"spring":
			# Паводок на реках
			for r in GameState.roads:
				if r["id"] == "vologda_highway":
					continue
				if randf() < 0.3:
					r["condition"] = max(0.2, r["condition"] - 0.2)
			logs.append("[color=lightblue]🌊 Весенний паводок на р. Леденьга. Заречье временно отрезано от суши.[/color]")
			GameState.active_incidents.append({
				"id": "flood_zarechye",
				"title": "Весеннее половодье на реке",
				"pos": Vector2(250, 350),
				"type": "flood",
				"text": "Уровень воды поднялся на 2.5 метра. Паромная переправа остановлена до спада воды."
			})
	
	# Расход топлива в котельных
	for s_id in GameState.settlements:
		var s = GameState.settlements[s_id]
		if s.get("population", 0) == 0:
			continue
		var fuel_drain = 20 if is_winter else 5
		s["heat_fuel"] = max(0, s.get("heat_fuel", 50) - fuel_drain)
		if s["heat_fuel"] < 25:
			s["trust"] = max(10, s.get("trust", 50) - 5)
			logs.append("[color=crimson]🔥 ВНИМАНИЕ: В %s заканчивается топливо для отопления (%d%%)![/color]" % [s["name"], s["heat_fuel"]])
			GameState.active_incidents.append({
				"id": "fuel_low_" + s_id,
				"title": "Опасность разморозки котельной: " + s["name"],
				"pos": s["pos"],
				"type": "heat",
				"text": "Запас дров/мазута на исходе. Срочно выделите средства из резервного фонда главы."
			})
	
	GameState.recalculate_totals()
	GameState.district_updated.emit()
	
	return logs
