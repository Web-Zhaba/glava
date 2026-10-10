extends Node

# Глобальное состояние игры и района
signal district_updated()
signal incident_triggered(incident_data: Dictionary)
signal focus_map_requested(pos: Vector2)

var month: int = 10 # месяц
var year: int = 2019 # год
var month_names = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь']
var months_names = month_names # для совместимости

var budget: int = 2_500_000 # казна
var people_trust: int = 54 # народное доверие (среднее по району)
var loyality: int = 50 # лояльность областной власти (Губернатор)
var population: int = 3345 # население всего района

var triggered_events: Array[String] = [] # Случившиеся происшествия
var active_incidents: Array[Dictionary] = [] # Текущие инциденты на карте

# Данные географии и инфраструктуры округа
var settlements: Dictionary = {}
var roads: Array[Dictionary] = []
var pois: Array[Dictionary] = []

# Парк коммунальной и дорожной техники (ДРСУ / ЖКХ)
var equipment = {
	"grader": {"name": "Автогрейдер ДС-14", "assigned_to": "", "condition": 75, "fuel_cost": 45000},
	"tractor": {"name": "Трактор МТЗ-82 с отвалом", "assigned_to": "", "condition": 80, "fuel_cost": 25000},
	"emergency_crew": {"name": "Аварийная бригада ЖКХ", "assigned_to": "", "condition": 85, "cost": 35000}
}

func _ready() -> void:
	init_district()

func init_district() -> void:
	settlements = DistrictData.get_default_settlements()
	roads = DistrictData.get_default_roads()
	pois = DistrictData.get_default_pois()
	recalculate_totals()

func recalculate_totals() -> void:
	var total_pop: int = 0
	var total_trust: float = 0.0
	var count_settlements: int = 0
	for key in settlements:
		var s = settlements[key]
		total_pop += s.get("population", 0)
		if s.get("population", 0) > 0:
			total_trust += s.get("trust", 50)
			count_settlements += 1
	if total_pop > 0:
		population = total_pop
	if count_settlements > 0:
		people_trust = int(round(total_trust / float(count_settlements)))

func get_season() -> String:
	match month:
		12, 1, 2:
			return "winter"
		3, 4, 5:
			return "spring"
		6, 7, 8:
			return "summer"
		9, 10, 11:
			return "autumn"
	return "any"

func get_season_name() -> String:
	match get_season():
		"winter": return "Зима (Морозы / Сугробы)"
		"spring": return "Весна (Паводок / Ледоход)"
		"summer": return "Лето (Сушь / Лесозаготовки)"
		"autumn": return "Осень (Распутица / Дожди)"
	return "Межсезонье"

func apply_effects(effects: Dictionary) -> void:
	if effects.has("loyality"):
		loyality = clamp(loyality + effects["loyality"], 0, 100)
	if effects.has("people_trust"):
		people_trust = clamp(people_trust + effects["people_trust"], 0, 100)
	if effects.has("population"):
		population = max(0, population + effects["population"])
	if effects.has("budget"):
		budget += effects["budget"]
	
	# Если эффект привязан к поселению
	if effects.has("settlement_id") and settlements.has(effects["settlement_id"]):
		var s = settlements[effects["settlement_id"]]
		if effects.has("settlement_trust"):
			s["trust"] = clamp(s["trust"] + effects["settlement_trust"], 0, 100)
		if effects.has("settlement_pop"):
			s["population"] = max(0, s["population"] + effects["settlement_pop"])
	
	recalculate_totals()
	district_updated.emit()

func advance_month() -> Array[String]:
	return TurnManager.advance_month()

# Действия на карте
func repair_road(road_id: String) -> bool:
	for r in roads:
		if r["id"] == road_id:
			var cost = 70000
			if budget < cost:
				return false
			budget -= cost
			r["condition"] = min(1.0, r["condition"] + 0.35)
			r["is_blocked"] = false
			district_updated.emit()
			return true
	return false

func supply_settlement_fuel(settlement_id: String) -> bool:
	if not settlements.has(settlement_id):
		return false
	var cost = 50000
	if budget < cost:
		return false
	budget -= cost
	var s = settlements[settlement_id]
	s["heat_fuel"] = min(100, s.get("heat_fuel", 50) + 30)
	s["trust"] = min(100, s.get("trust", 50) + 4)
	district_updated.emit()
	return true

func send_grader_to_road(road_id: String) -> bool:
	var grader = equipment["grader"]
	if grader["assigned_to"] != "":
		return false
	if budget < grader["fuel_cost"]:
		return false
	budget -= grader["fuel_cost"]
	grader["assigned_to"] = road_id
	for r in roads:
		if r["id"] == road_id:
			r["condition"] = min(1.0, r["condition"] + 0.3)
			r["is_blocked"] = false
			break
	district_updated.emit()
	return true
