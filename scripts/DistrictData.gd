extends Node
class_name DistrictData

# Данные населенных пунктов округа (Вологодский северный край)
static func get_default_settlements() -> Dictionary:
	return {
		"center": {
			"id": "center",
			"name": "с. Спасское",
			"type": "Райцентр",
			"pos": Vector2(500, 420),
			"population": 2150,
			"trust": 58,
			"heat_status": "В норме (Котельная №1)",
			"heat_fuel": 85, # процент запаса дров/мазута
			"road_status": "Асфальт",
			"description": "Административный центр округа. Здесь расположены: здание администрации, районная больница (ЦРБ), средняя школа, РОВД, редакция газеты 'Северный луч' и гараж ДРСУ.",
			"facilities": ["Администрация", "ЦРБ", "Средняя школа", "Гараж ДРСУ", "Центральная котельная"],
			"problems": [],
			"status_tag": "Штатно"
		},
		"yurmanga": {
			"id": "yurmanga",
			"name": "пос. Юрманга",
			"type": "Лесной посёлок",
			"pos": Vector2(880, 240),
			"population": 640,
			"trust": 44,
			"heat_status": "Критическое (старые котлы)",
			"heat_fuel": 40,
			"road_status": "Грейдер разбит лесовозами",
			"description": "Посёлок при старом леспромхозе. Вокруг глухая тайга. Деревянные двухэтажные бараки, высокая безработица, частые перебои со связью и выпивка.",
			"facilities": ["Пилорама 'Север-Лес'", "Клуб (в аварийном состоянии)", "Котельная на опилках"],
			"problems": ["Разбита дорога", "Угроза остановки котельной"],
			"status_tag": "Тревожно"
		},
		"kokshenga": {
			"id": "kokshenga",
			"name": "д. Кокшеньга",
			"type": "Деревня",
			"pos": Vector2(260, 680),
			"population": 280,
			"trust": 62,
			"heat_status": "Печное отопление",
			"heat_fuel": 90,
			"road_status": "Грунтовка, ветхий мост",
			"description": "Старинная северная деревня на высоком берегу реки. Живут в основном пенсионеры и дачники. Действует фельдшерско-акушерский пункт (ФАП) и магазин РайПО.",
			"facilities": ["ФАП", "Магазин РайПО", "Памятник участникам ВОВ"],
			"problems": ["Ветхий деревянный мост"],
			"status_tag": "Штатно"
		},
		"lesnoy": {
			"id": "lesnoy",
			"name": "пос. Лесной Бор",
			"type": "Таёжный посёлок",
			"pos": Vector2(1080, 600),
			"population": 190,
			"trust": 48,
			"heat_status": "Печное отопление",
			"heat_fuel": 55,
			"road_status": "Лесная колея / Зимник",
			"description": "Глухой посёлок в глубине сосновых боров. Зимой сюда накатывают автозимник, весной и осенью посёлок практически отрезан от большой земли. Электричество подается по старой ЛЭП через болота.",
			"facilities": ["Дизель-генераторная", "Лесничество"],
			"problems": ["Сезонная изоляция", "Обрывы ЛЭП"],
			"status_tag": "Угроза изоляции"
		},
		"zarechye": {
			"id": "zarechye",
			"name": "д. Заречье",
			"type": "Заречная деревня",
			"pos": Vector2(210, 310),
			"population": 85,
			"trust": 50,
			"heat_status": "Печное отопление",
			"heat_fuel": 70,
			"road_status": "Только паром / лодки",
			"description": "Деревня за широкой рекой Леденьга. Капитального моста никогда не было. Летом ходят на лодках, зимой переходят по льду, в паводок отрезанность 100%.",
			"facilities": ["Паромный причал", "Таксофон Ростелеком"],
			"problems": ["Отрезана в паводок"],
			"status_tag": "Отрезана"
		},
		"pogost": {
			"id": "pogost",
			"name": "Урочище Старый Погост",
			"type": "Заброшенное урочище",
			"pos": Vector2(620, 780),
			"population": 0,
			"trust": 0,
			"heat_status": "Нет",
			"heat_fuel": 0,
			"road_status": "Заросшая просека",
			"description": "Покинутое в 1970-х годах село. Сохранилась полуразрушенная каменная церковь Воскресения Христова с покосившимся куполом. Любимое место черных копателей, грибников и медведей.",
			"facilities": ["Руины каменного храма XVIII века"],
			"problems": [],
			"status_tag": "Заброшено"
		}
	}

# Дорожная сеть
static func get_default_roads() -> Array[Dictionary]:
	return [
		{
			"id": "vologda_highway",
			"from": Vector2(40, 420),
			"to": Vector2(500, 420),
			"name": "Областная трасса (на Вологду)",
			"type": "highway", # асфальт
			"condition": 0.85, # 85%
			"is_blocked": false
		},
		{
			"id": "yurmanga_tract",
			"from": Vector2(500, 420),
			"to": Vector2(880, 240),
			"name": "Юрмангский тракт",
			"type": "gravel", # грейдер
			"condition": 0.40, # сильно разбит
			"is_blocked": false
		},
		{
			"id": "kokshenga_road",
			"from": Vector2(500, 420),
			"to": Vector2(260, 680),
			"name": "Кокшеньгский просёлок",
			"type": "dirt", # грунтовка
			"condition": 0.60,
			"is_blocked": false
		},
		{
			"id": "lesnoy_winter_road",
			"from": Vector2(880, 240),
			"to": Vector2(1080, 600),
			"name": "Таёжная просека на Лесной Бор",
			"type": "winter", # лесовозная колея / зимник
			"condition": 0.35,
			"is_blocked": false
		},
		{
			"id": "pogost_trail",
			"from": Vector2(260, 680),
			"to": Vector2(620, 780),
			"name": "Старая земская дорога на Погост",
			"type": "dirt",
			"condition": 0.20,
			"is_blocked": false
		}
	]

# Дополнительные ключевые объекты (POI)
static func get_default_pois() -> Array[Dictionary]:
	return [
		{
			"id": "bridge_ledenga",
			"name": "Деревянный мост через р. Леденьга",
			"pos": Vector2(360, 560),
			"type": "bridge",
			"description": "Ветхий деревянный мост на сваях. Опоры подмывает весенним паводком. Тяжелым лесовозам проезд запрещен, но они всё равно ездят по ночам.",
			"condition": 0.45,
			"repair_cost": 350000
		},
		{
			"id": "sawmill_north",
			"name": "Пилорама 'Север-Лес'",
			"pos": Vector2(790, 310),
			"type": "industry",
			"description": "Главный работодатель района после бюджетной сферы. Принадлежит местному депутату. Дает рабочие места, но перегруженные сортиментовозы разбивают гравийное покрытие дороги.",
			"condition": 0.90
		},
		{
			"id": "landfill",
			"name": "Муниципальный полигон ТБО",
			"pos": Vector2(640, 350),
			"type": "landfill",
			"description": "Районная свалка, открытая еще в 1980-х. Заполнена на 95%. Роспотребнадзор грозит штрафами за отсутствие мусоросортировки.",
			"condition": 0.25
		},
		{
			"id": "drsu_base",
			"name": "База ДРСУ (Дорожный участок)",
			"pos": Vector2(530, 480),
			"type": "drsu",
			"description": "Гараж дорожного хозяйства. В парке: 1 старый автогрейдер ГС-14, 1 трактор МТЗ-82 'Беларус' с отвалом и КДМ-ка на базе КамАЗа.",
			"condition": 0.70
		},
		{
			"id": "ferry_zarechye",
			"name": "Паромная переправа 'Заречье'",
			"pos": Vector2(250, 350),
			"type": "ferry",
			"description": "Самодельный канатный паром для переправы жителей и легких телег через реку Леденьга. Работает только при открытой воде без сильного течения.",
			"condition": 0.50
		}
	]

# География: изгибы рек для плавной отрисовки
static func get_river_ledenga_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(120, -50),
		Vector2(170, 80),
		Vector2(200, 200),
		Vector2(250, 350), # у Заречья
		Vector2(320, 470),
		Vector2(360, 560), # у деревянного моста
		Vector2(300, 660),
		Vector2(260, 750), # у Кокшеньги
		Vector2(310, 890),
		Vector2(340, 1050)
	])

static func get_river_yurmanga_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(1150, 80),
		Vector2(1020, 150),
		Vector2(890, 220), # у пос. Юрманга
		Vector2(750, 280),
		Vector2(620, 360),
		Vector2(450, 410),
		Vector2(320, 470) # впадение в Леденьгу
	])

# Контуры таежных массивов (многоугольники леса)
static func get_forest_polygons() -> Array[PackedVector2Array]:
	return [
		# Северная глухая тайга
		PackedVector2Array([
			Vector2(400, 40), Vector2(650, 60), Vector2(850, 110), Vector2(760, 240),
			Vector2(600, 250), Vector2(450, 200), Vector2(350, 120)
		]),
		# Восточный таёжный массив (вокруг Лесного Бора)
		PackedVector2Array([
			Vector2(850, 330), Vector2(1040, 260), Vector2(1180, 400), Vector2(1150, 720),
			Vector2(990, 680), Vector2(910, 520), Vector2(820, 440)
		]),
		# Южные сосновые боры (у Погоста)
		PackedVector2Array([
			Vector2(420, 640), Vector2(680, 600), Vector2(800, 720), Vector2(750, 920),
			Vector2(550, 960), Vector2(440, 820)
		])
	]

# Болота (схематичные области)
static func get_swamp_polygons() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([
			Vector2(680, 430), Vector2(800, 420), Vector2(820, 520), Vector2(700, 540)
		]),
		PackedVector2Array([
			Vector2(950, 660), Vector2(1100, 680), Vector2(1080, 850), Vector2(920, 800)
		])
	]
