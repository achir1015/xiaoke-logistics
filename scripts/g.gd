extends Node
## 全域遊戲狀態：時間、資金、評價、委託、存檔。

signal money_changed
signal offers_changed
signal contracts_changed
signal rating_changed
signal toast(text: String, kind: String)
signal undo_offer(text: String, refund: int, cb: Callable)
signal phone_call(c: Dictionary)
signal game_over(title: String, body: String)
signal day_started(day: int, report: String)
signal property_changed
signal weather_changed
signal market_changed
signal quake(mag: float)
signal incident(kind: String, data: Dictionary)

const APP_VERSION := "1.2.0"
const SAVE_PATH := "user://save.json"
const MIN_PER_SEC := 5.0          # 1× 時，每現實秒 = 5 遊戲分鐘
const START_MONEY := 20000

# ── 建造項目 ──
const BUILD := {
	"rack": {"name": "一般貨架", "price": 900, "upkeep": 10, "slots": 6, "cols": 2, "levels": 3, "cargo": ["general", "mystery"],
		"desc": "6 個托盤位。放一般貨物（也能藏不明貨箱）。"},
	"cold": {"name": "冷藏櫃", "price": 2800, "upkeep": 40, "slots": 4, "cols": 2, "levels": 2, "cargo": ["cold"],
		"desc": "4 個托盤位，插電保冷。生鮮、乳品、藥品專用。"},
	"fragile": {"name": "易碎品籠架", "price": 1600, "upkeep": 15, "slots": 4, "cols": 2, "levels": 2, "cargo": ["fragile"],
		"desc": "4 個托盤位，加墊防撞。玻璃、陶瓷、精密儀器專用。"},
	"inspect": {"name": "海關查驗台", "price": 3000, "upkeep": 20, "slots": 2, "cols": 2, "levels": 1, "cargo": [],
		"desc": "國際貨被抽中「C3 貨物查驗」時，抽驗的托盤要搬到這裡讓海關人員開箱檢查。"},
}
const FORKLIFT_PRICE := 3500
const FORKLIFT_WAGE := 60
const DOOR_PRICE := 4000
const PLOT_PRICES := [0, 23500, 48000, 90000]
const PLOT_RENT := 120
const RAIL_PRICE := 20000
const RAIL_DAILY := 140
const HARBOUR_PRICE := 45000
const HARBOUR_DAILY := 300
const AIRPORT_PRICE := 60000
const AIRPORT_DAILY := 400
const CAP := {"truck": 6, "van": 4, "rail": 12, "ship": 20, "air": 8}

const CARGO := {
	"general": {"name": "一般", "rate": 60, "color": Color(0.80, 0.60, 0.38)},
	"cold": {"name": "冷藏", "rate": 115, "color": Color(0.86, 0.93, 0.98)},
	"fragile": {"name": "易碎", "rate": 90, "color": Color(0.96, 0.78, 0.82)},
	"mystery": {"name": "不明貨箱", "rate": 0, "color": Color(0.20, 0.24, 0.22)},
}
const TRANSPORT := {"truck": "卡車", "rail": "火車", "ship": "貨輪", "van": "廂型車", "air": "貨機"}

const CLIENTS := [
	["晨光食品", ["general", "cold"]], ["海風進口", ["general"]], ["阿福五金", ["general"]],
	["綠野農產", ["cold", "general"]], ["星河電子", ["fragile", "general"]], ["大同紡織", ["general"]],
	["山海家具", ["general", "fragile"]], ["北港水產", ["cold"]], ["和平藥品", ["cold"]],
	["晶亮玻璃", ["fragile"]], ["小巷咖啡", ["general", "cold"]], ["雲端書店", ["general"]],
	["福氣陶瓷", ["fragile"]], ["鮮奶工坊", ["cold"]], ["東昇玩具", ["general", "fragile"]],
	["老街茶行", ["general"]], ["好日子烘焙", ["cold", "general"]], ["光點照明", ["fragile"]],
]
const RAIL_CLIENTS := ["鐵道聯運", "南北快線貨運", "穀倉合作社", "鋼鐵大道"]
const SHIP_CLIENTS := ["遠洋貿易", "藍鯨航運", "港都國際", "七海進出口"]
const AIR_CLIENTS := ["雲翔航空貨運", "飛鳥快遞", "晶片之星科技", "極光生技", "環球精品"]
const WEATHER_NAMES := {"sunny": "晴", "cloudy": "多雲", "rain": "雨天", "typhoon": "颱風"}
const CONTRABAND := [
	["毒品", "藏在貨箱夾層裡的毒品"], ["違禁品", "申報不實的管制違禁品"], ["非法槍枝", "拆解藏在零件裡的非法槍枝與彈藥"],
]
const OIL_NEWS_UP := ["中東局勢緊張，國際油價大漲", "產油國宣布減產，油價走高", "煉油廠意外停工，油價上揚", "寒流來襲需求增加，油價上漲"]
const OIL_NEWS_DOWN := ["主要產油國增產，油價下跌", "全球需求放緩，油價走跌", "庫存增加超乎預期，油價回落", "減產協議破局，油價重挫"]
const STAGE_NAMES := {"docs": "等待文件", "declared": "報關申報中", "review": "C2 書面審核中", "inspect_move": "C3 抽驗：搬到查驗台",
	"inspecting": "C3 海關查驗中", "inspect_return": "C3 查驗完成：搬回貨架", "released": "已放行", "seized": "查獲違禁品"}
const MOB_NAMES := ["老周", "阿彪", "龍哥", "黑皮"]

# ── 狀態 ──
var money: int = START_MONEY
var minute: float = 480.0            # 從第 1 天 00:00 起算的遊戲分鐘
var speed: float = 1.0
var speed_before_pause: float = 1.0
var rating: float = 50.0
var offers: Array = []
var contracts: Array = []            # 已簽約（含進行中）
var next_id: int = 1
var plots: int = 1
var doors: Array = [0, 1]           # 已開啟的前門索引（每塊地 3 個）
var rail: bool = false
var harbour: bool = false
var airport: bool = false
var heat: float = 0.0
var mob_deals: int = 0
var yesterday: int = 0
var today_income: int = 0
var last_call_min: float = -9999.0
var playing: bool = false
var over: bool = false
var stats := {"pallets": 0, "contracts": 0, "earned": 0}
var tutorial_done: bool = false
var rng := RandomNumberGenerator.new()
var _offer_timer: float = 0.0
var _last_day: int = 1
var _autosave_min: float = 0.0
var _neg_days: int = 0
var world_snapshot: Dictionary = {}   # 由 World 填寫，存檔用
var force_call := false               # 測試用
var force_cls := ""                   # 測試用：C1／C2／C3
var force_contraband := false         # 測試用
# 天氣、地震
var weather := {"kind": "sunny", "until": 720.0}
var typhoon_eta := -1.0
var last_typhoon := -99999.0
var last_quake := -99999.0
# 市場：國際油價（美元／桶）與物價指數
var oil := 78.0
var cpi := 100.0
var oil_hist: Array = []
var cpi_hist: Array = []

func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS

# ── 時間 ──
func day() -> int:
	return int(minute / 1440.0) + 1

func clock_text(m: float = -1.0) -> String:
	if m < 0.0:
		m = minute
	var mm := int(m) % 1440
	return "%02d:%02d" % [mm / 60, (mm % 60) / 10 * 10]

func when_text(m: float) -> String:
	var d := int(m / 1440.0) + 1
	var dd := d - day()
	var pre := "今天"
	if dd == 1:
		pre = "明天"
	elif dd == 2:
		pre = "後天"
	elif dd > 2:
		pre = "第 %d 天" % d
	elif dd < 0:
		pre = "已過"
	return "%s %s" % [pre, clock_text(m)]

func hour() -> float:
	return fmod(minute, 1440.0) / 60.0

func set_speed(s: float) -> void:
	if s > 0.0:
		speed_before_pause = s
	speed = s

func toggle_pause() -> void:
	if speed > 0.0:
		set_speed(0.0)
	else:
		set_speed(speed_before_pause)

func stars() -> int:
	return clampi(int(rating / 20.0) + 1, 1, 5)

func fmt(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if neg else "$") + s + out

# ── 物價與油價 ──
func price(base: int) -> int:
	return int(round(base * cpi / 100.0 / 10.0) * 10)

func fuel_daily() -> int:
	return int(round(int(world_snapshot.get("forklifts", 1)) * oil * 0.5))

func oil_change() -> float:
	if oil_hist.size() < 2:
		return 0.0
	return (oil / float(oil_hist[oil_hist.size() - 2]) - 1.0) * 100.0

func cpi_change() -> float:
	if cpi_hist.size() < 2:
		return 0.0
	return (cpi / float(cpi_hist[cpi_hist.size() - 2]) - 1.0) * 100.0

func _market_day() -> void:
	var rnd := rng.randfn(0.0, 0.025)
	oil = oil * exp(rnd) + (80.0 - oil) * 0.05
	if weather.kind == "typhoon":
		oil *= 1.02
	if rng.randf() < 0.1:
		var up := rng.randf() < 0.5
		var shock := rng.randf_range(0.07, 0.18)
		oil *= (1.0 + shock) if up else (1.0 - shock)
		var news: Array = OIL_NEWS_UP if up else OIL_NEWS_DOWN
		toast.emit("【財經】%s（%s%.1f%%）" % [news[rng.randi() % news.size()], "+" if up else "-", shock * 100.0], "bad" if up else "good")
	oil = clampf(oil, 35.0, 150.0)
	cpi *= 1.0 + 0.0006 + (oil - 80.0) / 80.0 * 0.0025 + rng.randfn(0.0, 0.0012)
	cpi = clampf(cpi, 90.0, 200.0)
	oil_hist.append(snappedf(oil, 0.1))
	cpi_hist.append(snappedf(cpi, 0.01))
	while oil_hist.size() > 30:
		oil_hist.pop_front()
	while cpi_hist.size() > 30:
		cpi_hist.pop_front()
	market_changed.emit()

# ── 天氣 ──
func weather_kind() -> String:
	return weather.kind

func weather_text() -> String:
	var t: String = WEATHER_NAMES[weather.kind]
	return "%s %d°C" % [t, temperature()]

func temperature() -> int:
	var h := hour()
	var base := 25.0 + 5.0 * sin((h - 9.0) / 24.0 * TAU)
	match weather.kind:
		"cloudy": base -= 1.5
		"rain": base -= 3.0
		"typhoon": base -= 2.5
	return int(round(base))

func transport_ok(kind: String) -> bool:
	if weather.kind == "typhoon":
		return not (kind in ["ship", "air", "rail"])
	return true

func road_factor() -> float:
	match weather.kind:
		"rain": return 0.8
		"typhoon": return 0.55
	return 1.0

func storm_exempt() -> bool:
	return weather.kind == "typhoon"

func _weather_tick() -> void:
	if typhoon_eta > 0.0 and minute >= typhoon_eta:
		typhoon_eta = -1.0
		last_typhoon = minute
		weather = {"kind": "typhoon", "until": minute + rng.randf_range(720.0, 1200.0)}
		toast.emit("颱風登陸！港口封港、機場停飛、火車停駛，延誤不會扣錢。卡車行駛變慢。", "bad")
		weather_changed.emit()
		return
	if minute < float(weather.until):
		return
	var was: String = weather.kind
	var r := rng.randf()
	var k := "sunny" if r < 0.5 else ("cloudy" if r < 0.78 else "rain")
	if was == "typhoon":
		k = "cloudy"
		toast.emit("颱風遠離，港口、機場和鐵路恢復作業。", "good")
	weather = {"kind": k, "until": minute + rng.randf_range(360.0, 1080.0)}
	# 颱風警報（至少相隔 4 天）
	if typhoon_eta < 0.0 and k != "typhoon" and day() >= 3 and minute - last_typhoon > 4 * 1440.0 and rng.randf() < 0.12:
		typhoon_eta = minute + rng.randf_range(600.0, 900.0)
		toast.emit("【颱風警報】颱風預計 %s 登陸，請提前安排船班和班機！" % when_text(typhoon_eta), "bad")
		Snd.play("alarm")
	if k != was:
		weather_changed.emit()

func _quake_tick(dm: float) -> void:
	if day() < 2 or minute - last_quake < 1440.0 * 1.5:
		return
	if rng.randf() > 0.00012 * dm:
		return
	last_quake = minute
	var mag := snappedf(3.8 + pow(rng.randf(), 1.8) * 3.0, 0.1)
	quake.emit(mag)

# ── 金錢 ──
func can_afford(p: int) -> bool:
	return money >= p

func spend(p: int) -> bool:
	if money < p:
		toast.emit("資金不足（需要 %s）" % fmt(p), "bad")
		Snd.play("error")
		return false
	money -= p
	money_changed.emit()
	return true

func earn(p: int, why: String = "") -> void:
	money += p
	today_income += p
	if p > 0:
		stats.earned += p
	money_changed.emit()
	if why != "":
		toast.emit("%s　%s" % [why, fmt(p)], "good" if p >= 0 else "bad")

func add_rating(d: float) -> void:
	var before := stars()
	rating = clampf(rating + d, 0.0, 100.0)
	rating_changed.emit()
	if stars() > before:
		toast.emit("評價提升到 %d 星！客戶開出的價碼會更好。" % stars(), "good")
		Snd.play("fanfare")
	elif stars() < before:
		toast.emit("評價降到 %d 星……" % stars(), "bad")

func daily_cost() -> int:
	return int(round(_base_daily() * cpi / 100.0)) + fuel_daily()

func _base_daily() -> int:
	var c := PLOT_RENT * plots
	if rail:
		c += RAIL_DAILY
	if harbour:
		c += HARBOUR_DAILY
	if airport:
		c += AIRPORT_DAILY
	for k in world_snapshot.get("upkeep_items", []):
		c += int(BUILD[k].upkeep)
	c += FORKLIFT_WAGE * int(world_snapshot.get("forklifts", 1))
	return c

# ── 每幀推進 ──
func _process(delta: float) -> void:
	if not playing or over:
		return
	var dm := delta * MIN_PER_SEC * speed
	if dm <= 0.0:
		return
	minute += dm
	var d := day()
	if d != _last_day:
		_last_day = d
		_new_day()
	# 委託產生
	_offer_timer -= dm
	if _offer_timer <= 0.0:
		_offer_timer = rng.randf_range(70.0, 150.0) / (0.8 + stars() * 0.12)
		if offers.size() < 3 + stars():
			offers.append(_make_offer())
			offers_changed.emit()
			Snd.play("ding")
	# 過期委託
	var changed := false
	for i in range(offers.size() - 1, -1, -1):
		if minute > float(offers[i].expires):
			offers.remove_at(i)
			changed = true
	if changed:
		offers_changed.emit()
	# 神秘來電
	_maybe_call(dm)
	_weather_tick()
	_quake_tick(dm)
	# 自動存檔（每 3 遊戲小時）
	_autosave_min += dm
	if _autosave_min > 180.0:
		_autosave_min = 0.0
		save_game()

func _new_day() -> void:
	_market_day()
	var cost := daily_cost()
	money -= cost
	yesterday = today_income - cost
	today_income = 0
	heat = maxf(0.0, heat - 0.15)
	money_changed.emit()
	var rep := "第 %d 天開始。昨日收支 %s（固定支出 %s）" % [day(), fmt(yesterday), fmt(cost)]
	day_started.emit(day(), rep)
	toast.emit(rep, "info")
	if money < 0:
		_neg_days += 1
		if _neg_days >= 3:
			trigger_game_over("破產了", "連續三天資金為負，銀行收回了倉庫。\n\n下次記得先確定放得下再簽約，固定支出別擴張太快。")
			return
		toast.emit("資金為負！連續 3 天就會破產（目前 %d 天）" % _neg_days, "bad")
	else:
		_neg_days = 0
	save_game()

# ── 委託 ──
func _round_time(m: float) -> float:
	return floor(m / 10.0) * 10.0

func _make_offer() -> Dictionary:
	var kinds := ["truck", "truck", "truck"]
	if rail:
		kinds.append("rail")
	if harbour:
		kinds.append("ship")
	if airport:
		kinds.append("air")
	var tr: String = kinds[rng.randi() % kinds.size()]
	var client := ""
	var cargo := "general"
	var n := 0
	var intl := ""
	var tin := tr
	var tout := tr
	var tot: Dictionary = world_snapshot.get("total", {})
	match tr:
		"rail":
			client = RAIL_CLIENTS[rng.randi() % RAIL_CLIENTS.size()]
			cargo = "general"
			n = rng.randi_range(8, 12)
			tout = "truck"
		"ship", "air":
			intl = "import" if rng.randf() < 0.6 else "export"
			if tr == "ship":
				client = SHIP_CLIENTS[rng.randi() % SHIP_CLIENTS.size()]
				cargo = ["general", "general", "cold", "fragile"][rng.randi() % 4]
				n = rng.randi_range(10, 16)
			else:
				client = AIR_CLIENTS[rng.randi() % AIR_CLIENTS.size()]
				cargo = ["fragile", "cold", "general"][rng.randi() % 3]
				n = rng.randi_range(4, 8)
			if cargo != "general" and int(tot.get(cargo, 0)) == 0 and rng.randf() < 0.6:
				cargo = "general"
			if intl == "import":
				tin = tr
				tout = "truck"
			else:
				tin = "truck"
				tout = tr
		_:
			var cl: Array = CLIENTS[rng.randi() % CLIENTS.size()]
			client = cl[0]
			var prefs: Array = cl[1]
			cargo = prefs[rng.randi() % prefs.size()]
			# 玩家還沒有這種貨架時，多半改找一般貨的客戶
			if cargo != "general" and int(tot.get(cargo, 0)) == 0 and rng.randf() < 0.75:
				for k in 20:
					var cl2: Array = CLIENTS[rng.randi() % CLIENTS.size()]
					if "general" in cl2[1]:
						client = cl2[0]
						break
				cargo = "general"
			var cap := maxi(int(tot.get(cargo, 0)), 6)
			n = rng.randi_range(2, clampi(cap / 3 + 1, 3, mini(CAP.truck, 4 + plots * 2 + stars() / 2)))
	var cross := rng.randf() < (0.4 if tr == "air" else 0.3)
	var arrive := _round_time(minute + rng.randf_range(90.0, 900.0))
	var stay := 0.0
	var days := 0
	if cross:
		stay = rng.randf_range(240.0, 480.0) if intl != "" else rng.randf_range(180.0, 420.0)
	else:
		days = rng.randi_range(1, 3)
		stay = days * 1440.0 + rng.randf_range(-240.0, 240.0)
	var pickup := _round_time(arrive + stay)
	var rate: float = CARGO[cargo].rate
	var pay := 0.0
	if cross:
		pay = n * (90.0 + rate * 0.6)
	else:
		pay = n * (90.0 + rate * days)
	pay *= (0.8 + stars() * 0.1) * rng.randf_range(0.88, 1.18)
	if tr != "truck":
		pay *= 1.15
	if intl != "":
		pay *= 1.3 if tr == "ship" else 1.6     # 報關服務費；空運貨價值高
	pay *= cpi / 100.0 * (1.0 + (oil - 80.0) / 80.0 * 0.2)   # 物價與燃油附加費
	var c := {
		"id": next_id, "client": client, "transport": tr, "tin": tin, "tout": tout, "intl": intl,
		"cargo": cargo, "n": n, "arrive": arrive, "pickup": pickup, "cross": cross, "days": days,
		"pay": int(round(pay / 10.0) * 10), "expires": minute + rng.randf_range(180.0, 360.0),
		"state": "offer", "unloaded": 0, "loaded": 0, "spawned_in": false, "spawned_out": false,
		"mystery": false, "late_pen": 0, "customs": {},
	}
	if intl != "":
		c.customs = _make_customs(c)
		# 少數國際貨夾帶違禁物（只有被查驗才會發現）
		if rng.randf() < 0.07 or force_contraband:
			c["contraband"] = rng.randi() % CONTRABAND.size()
	next_id += 1
	return c

# ── 海關 ──
func _make_customs(c: Dictionary) -> Dictionary:
	var names: Array = []
	var by: String = c.transport
	if c.intl == "import":
		names = ["海運提單（B/L）" if by == "ship" else "空運提單（AWB）", "商業發票", "裝箱單"]
		if c.cargo == "cold":
			names.append("輸入檢疫證明")
	else:
		names = ["裝貨單（S/O）" if by == "ship" else "航空託運單", "商業發票", "裝箱單"]
		if c.cargo == "cold":
			names.append("輸出檢疫證明")
	if c.cargo == "fragile":
		names.append("貨物保險單")
	var docs: Array = []
	for nm in names:
		var missing := rng.randf() < 0.2
		docs.append({"name": nm, "ok": not missing, "eta": float(c.arrive) + rng.randf_range(60.0, 540.0) if missing else 0.0, "chased": false})
	return {"stage": "docs", "cls": "", "t": 0.0, "docs": docs, "inspect_n": 0, "warned": false}

func intl_label(c: Dictionary) -> String:
	if c.get("intl", "") == "import":
		return "%s進口" % TRANSPORT[c.transport]
	if c.get("intl", "") == "export":
		return "%s出口" % TRANSPORT[c.transport]
	return TRANSPORT[c.get("transport", "truck")]

func leg_text(c: Dictionary) -> String:
	var tin: String = c.get("tin", c.transport)
	var tout: String = c.get("tout", c.transport)
	if tin == tout:
		return TRANSPORT[tin]
	return "%s進・%s出" % [TRANSPORT[tin], TRANSPORT[tout]]

func customs_text(c: Dictionary) -> String:
	var cu: Dictionary = c.get("customs", {})
	if cu.is_empty():
		return ""
	var st: String = cu.stage
	var t: String = STAGE_NAMES.get(st, st)
	if st == "docs":
		var miss := 0
		for d in cu.docs:
			if not d.ok:
				miss += 1
		if miss > 0:
			t = "缺 %d 份文件" % miss
	return t

func missing_docs(c: Dictionary) -> int:
	var miss := 0
	for d in c.get("customs", {}).get("docs", []):
		if not d.ok:
			miss += 1
	return miss

func chase_doc(c: Dictionary, i: int) -> void:
	var d: Dictionary = c.customs.docs[i]
	if d.ok or d.chased:
		return
	d.chased = true
	var soon := maxf(minute, float(c.arrive) - 60.0) + rng.randf_range(30.0, 90.0)
	d.eta = minf(float(d.eta), soon)
	toast.emit("已向 %s 催補「%s」" % [c.client, d.name], "info")
	contracts_changed.emit()

func customs_released(c: Dictionary) -> bool:
	var cu: Dictionary = c.get("customs", {})
	return cu.is_empty() or cu.stage == "released"

func free_slots(cargo: String) -> int:
	var cap: Dictionary = world_snapshot.get("free", {})
	var free: int = int(cap.get(cargo, 0))
	if cargo == "mystery":
		free = int(cap.get("general", 0))
	# 扣除已簽但還沒進來的
	for c in contracts:
		var cg: String = c.cargo
		if cg == "mystery":
			cg = "general"
		var want := cargo if cargo != "mystery" else "general"
		if cg == want and c.state in ["booked", "inbound"]:
			free -= int(c.n) - int(c.unloaded)
	return free

func fit_text(c: Dictionary) -> Array:
	var f := free_slots(c.cargo)
	if f >= int(c.n) + 2:
		return ["放得下", "good"]
	if f >= int(c.n):
		return ["空間吃緊", "warn"]
	return ["空間不足（剩 %d）" % maxi(f, 0), "bad"]

func accept_offer(c: Dictionary) -> void:
	if (c.transport == "rail" and not rail) or (c.transport == "ship" and not harbour) or (c.transport == "air" and not airport):
		return
	offers.erase(c)
	c.state = "booked"
	contracts.append(c)
	stats.contracts += 1
	offers_changed.emit()
	contracts_changed.emit()
	Snd.play("sign")
	toast.emit("已簽約：%s，%s 抵達" % [c.client, when_text(c.arrive)], "info")

func decline_offer(c: Dictionary) -> void:
	offers.erase(c)
	offers_changed.emit()

func contract_by_id(id: int) -> Dictionary:
	for c in contracts:
		if int(c.id) == id:
			return c
	return {}

func finish_contract(c: Dictionary) -> void:
	c.state = "done"
	var pay := int(c.pay) - int(c.late_pen)
	var short := int(c.n) - int(c.loaded)
	if short > 0 and int(c.n) > 0:
		pay = int(pay * float(c.loaded) / float(c.n))
	if c.mystery:
		earn(pay, "不明貨箱尾款（現金）")
		mob_deals += 1
		heat += 0.6
	else:
		earn(pay, "%s 結清" % c.client)
		if int(c.late_pen) == 0 and short == 0:
			add_rating(2.5)
		Snd.play("cash")
	contracts.erase(c)
	contracts_changed.emit()

func fail_contract(c: Dictionary, why: String, penalty_rating: float) -> void:
	toast.emit(why, "bad")
	add_rating(-penalty_rating)
	contracts_changed.emit()

# ── 神秘來電 ──
func _maybe_call(dm: float) -> void:
	if minute - last_call_min < 1440.0 * 1.5:
		return
	var h := hour()
	if h < 19.0 or h > 23.0:
		return
	var broke := money < 6000
	if day() < 3 and not broke:
		return
	for c in contracts:
		if c.mystery:
			return
	# 每個晚上（19～23 點）約兩成機率；缺錢時幾乎必來
	var p := 0.001 * dm
	if broke:
		p *= 6.0
	if force_call:
		p = 1.0
		force_call = false
	if rng.randf() > p:
		return
	last_call_min = minute
	var k := rng.randi_range(2, 4)
	var stay_days := rng.randi_range(1, 2)
	var arrive := _round_time(minute + rng.randf_range(120.0, 300.0))
	var c := {
		"id": next_id, "client": MOB_NAMES[rng.randi() % MOB_NAMES.size()], "transport": "van", "tin": "van", "tout": "van", "intl": "", "customs": {}, "cargo": "mystery",
		"n": k, "arrive": arrive, "pickup": _round_time(arrive + stay_days * 1440.0), "cross": false, "days": stay_days,
		"pay": k * rng.randi_range(28, 40) * 100, "advance": k * 500, "expires": minute + 60.0,
		"state": "offer", "unloaded": 0, "loaded": 0, "spawned_in": false, "spawned_out": false,
		"mystery": true, "late_pen": 0,
	}
	next_id += 1
	set_speed(0.0)
	Snd.play("phone")
	phone_call.emit(c)

func accept_mystery(c: Dictionary) -> void:
	c.state = "booked"
	contracts.append(c)
	if int(c.advance) > 0:
		earn(int(c.advance), "收到一筆「訂金」")
	contracts_changed.emit()

func cop_chance() -> float:
	return clampf(0.07 + heat * 0.05 + mob_deals * 0.02, 0.05, 0.45)

func trigger_game_over(title: String, body: String) -> void:
	if over:
		return
	over = true
	set_speed(0.0)
	delete_save()
	game_over.emit(title, body)

# ── 存檔 ──
func new_game() -> void:
	money = START_MONEY
	minute = 480.0
	speed = 1.0
	speed_before_pause = 1.0
	rating = 50.0
	offers = []
	contracts = []
	next_id = 1
	plots = 1
	doors = [0, 1]
	rail = false
	harbour = false
	airport = false
	weather = {"kind": "sunny", "until": minute + 600.0}
	typhoon_eta = -1.0
	last_typhoon = -99999.0
	last_quake = -99999.0
	oil = 78.0
	cpi = 100.0
	oil_hist = [76.4, 77.1, 76.8, 78.0]
	cpi_hist = [99.7, 99.8, 99.9, 100.0]
	heat = 0.0
	mob_deals = 0
	yesterday = 0
	today_income = 0
	last_call_min = -9999.0
	over = false
	stats = {"pallets": 0, "contracts": 0, "earned": 0}
	world_snapshot = {}
	_offer_timer = 5.0
	_last_day = day()
	_neg_days = 0
	# 開局先給兩張好做的委託
	for i in 2:
		var o := _make_offer()
		o.transport = "truck"
		o.tin = "truck"
		o.tout = "truck"
		o.intl = ""
		o.customs = {}
		o.cargo = "general"
		o.n = 3 + i
		o.arrive = _round_time(minute + 60.0 + i * 120.0)
		o.pickup = o.arrive + 1440.0
		o.cross = false
		o.days = 1
		o.pay = o.n * 150
		o.expires = minute + 600.0
		offers.append(o)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	if over or not playing:
		return
	get_tree().call_group("world", "write_snapshot")
	var data := {
		"v": APP_VERSION, "money": money, "minute": minute, "rating": rating, "offers": offers,
		"contracts": contracts, "next_id": next_id, "plots": plots, "doors": doors, "rail": rail,
		"harbour": harbour, "airport": airport, "heat": heat, "weather": weather, "typhoon_eta": typhoon_eta,
		"last_typhoon": last_typhoon, "last_quake": last_quake, "oil": oil, "cpi": cpi, "oil_hist": oil_hist, "cpi_hist": cpi_hist, "mob_deals": mob_deals, "yesterday": yesterday,
		"today_income": today_income, "last_call_min": last_call_min, "stats": stats,
		"world": world_snapshot, "tutorial_done": tutorial_done, "neg_days": _neg_days,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return false
	money = int(d.money)
	minute = float(d.minute)
	rating = float(d.rating)
	offers = d.offers
	contracts = d.contracts
	for c in offers + contracts:
		_fix_ints(c)
	next_id = int(d.next_id)
	plots = int(d.plots)
	doors = []
	for x in d.doors:
		doors.append(int(x))
	rail = bool(d.rail)
	harbour = bool(d.harbour)
	airport = bool(d.get("airport", false))
	weather = d.get("weather", {"kind": "sunny", "until": minute + 600.0})
	weather.until = float(weather.until)
	typhoon_eta = float(d.get("typhoon_eta", -1.0))
	last_typhoon = float(d.get("last_typhoon", -99999.0))
	last_quake = float(d.get("last_quake", -99999.0))
	oil = float(d.get("oil", 78.0))
	cpi = float(d.get("cpi", 100.0))
	oil_hist = d.get("oil_hist", [oil])
	cpi_hist = d.get("cpi_hist", [cpi])
	heat = float(d.heat)
	mob_deals = int(d.mob_deals)
	yesterday = int(d.yesterday)
	today_income = int(d.today_income)
	last_call_min = float(d.last_call_min)
	stats = {"pallets": int(d.stats.get("pallets", 0)), "contracts": int(d.stats.get("contracts", 0)), "earned": int(d.stats.get("earned", 0))}
	world_snapshot = d.world
	tutorial_done = bool(d.get("tutorial_done", true))
	_neg_days = int(d.get("neg_days", 0))
	speed = 1.0
	speed_before_pause = 1.0
	over = false
	_last_day = day()
	_offer_timer = 10.0
	return true

func _fix_ints(c: Dictionary) -> void:
	if not c.has("tin"):
		c["tin"] = c.get("transport", "truck")
		c["tout"] = c.get("transport", "truck")
	if not c.has("intl"):
		c["intl"] = ""
	if not c.has("customs"):
		c["customs"] = {}
	c.erase("veh_in")
	c.erase("veh_out")
	if c.customs.has("inspect_n"):
		c.customs.inspect_n = int(c.customs.inspect_n)
	for k in ["id", "n", "pay", "unloaded", "loaded", "days", "late_pen", "advance"]:
		if c.has(k):
			c[k] = int(c[k])

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
