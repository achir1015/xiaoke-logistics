class_name Hud
extends CanvasLayer
## 全部介面（繁體中文）：標題、頂列、委託、工具列、提示、對話框、說明、更新紀錄。

const BG := Color(0.11, 0.14, 0.2, 0.92)
const BG2 := Color(0.17, 0.21, 0.29, 0.96)
const ACC := Color(1.0, 0.72, 0.22)
const TXT := Color(0.95, 0.95, 0.97)
const DIM := Color(0.68, 0.72, 0.8)
const GOOD := Color(0.45, 0.88, 0.55)
const WARN := Color(1.0, 0.8, 0.3)
const BAD := Color(1.0, 0.45, 0.4)

var main
var root: Control
var title_box: Control
var game_box: Control
var money_lbl: Label
var money_sub: Label
var clock_lbl: Label
var speed_btns: Array = []
var stars_lbl: Label
var cap_lbl: Label
var tab_offers: Button
var tab_booked: Button
var list_box: VBoxContainer
var showing_offers := true
var list_scroll: ScrollContainer
var side_panel: Control
var toolbar: Control
var hint_bar: PanelContainer
var hint_lbl: Label
var toast_box: VBoxContainer
var info_panel: PanelContainer
var info_lbl: RichTextLabel
var info_target = null
var modal: Control
var update_bar: PanelContainer
var _refresh_t := 0.0
var _list_t := 0
var portrait_hint: PanelContainer
var price_btns: Array = []
var market_panel: PanelContainer
var g_oil: Gauge
var g_cpi: Gauge
var wx_lbl: Label
var wx_panel: PanelContainer
var cine := false
var news_bar: PanelContainer
var news_lbl: Label
var doc_panel: PanelContainer
var doc_body: VBoxContainer
var doc_toggle: Button
var doc_open := true
var doc_sel := -1

func _ready() -> void:
	layer = 5
	add_to_group("hud")
	M.init_fonts()
	root = Control.new()
	var th := Theme.new()
	th.default_font = M.font_ui
	th.default_font_size = 16
	th.set_font("bold_font", "RichTextLabel", M.font_bold)
	th.set_font("normal_font", "RichTextLabel", M.font_ui)
	root.theme = th
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_game_ui()
	G.money_changed.connect(_refresh_top)
	G.rating_changed.connect(_refresh_top)
	G.offers_changed.connect(_refresh_list)
	G.contracts_changed.connect(_refresh_list)
	G.toast.connect(add_toast)
	G.undo_offer.connect(_undo_toast)
	G.phone_call.connect(_phone_call)
	G.game_over.connect(_game_over)
	G.property_changed.connect(_refresh_top)
	Updater.update_available.connect(_on_update)
	portrait_hint = _panel(Color(0.08, 0.1, 0.15, 0.96), 14, 18)
	portrait_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	portrait_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	portrait_hint.grow_vertical = Control.GROW_DIRECTION_BOTH
	portrait_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := _lbl("請把手機橫放
畫面會比較好操作", 40, ACC)
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_hint.add_child(ph)
	portrait_hint.visible = false
	root.add_child(portrait_hint)
	get_viewport().size_changed.connect(_check_portrait)
	_check_portrait()

func _check_portrait() -> void:
	var s := get_viewport().get_visible_rect().size
	portrait_hint.visible = s.y > s.x * 1.1
	if portrait_hint.visible:
		root.move_child(portrait_hint, root.get_child_count() - 1)

# ── 小工具 ──
func _sb(c: Color, r := 10, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s

func _panel(c := BG, r := 12, pad := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(c, r, pad))
	return p

func _lbl(t: String, size := 16, c := TXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if size >= 19:
		l.add_theme_font_override("font", M.font_bold)
	return l

func _btn(t: String, cb: Callable, accent := false, size := 16) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var base := ACC if accent else Color(0.26, 0.31, 0.42)
	b.add_theme_stylebox_override("normal", _sb(base, 8, 12))
	b.add_theme_stylebox_override("hover", _sb(base.lightened(0.12), 8, 12))
	b.add_theme_stylebox_override("pressed", _sb(base.darkened(0.15), 8, 12))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.22, 0.24, 0.3), 8, 12))
	b.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12) if accent else TXT)
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.12) if accent else TXT)
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.12) if accent else TXT)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func():
		Snd.play("click", 0.5)
		cb.call())
	return b

func over_ui(p: Vector2) -> bool:
	var h := root.get_viewport().gui_get_hovered_control()
	if h != null and h != root:
		return true
	for c in [side_panel, toolbar, hint_bar, info_panel, update_bar]:
		if c and c.visible and c.get_global_rect().has_point(p):
			return true
	return modal != null

# ── 遊戲介面 ──
func _build_game_ui() -> void:
	game_box = Control.new()
	game_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_box.visible = false
	root.add_child(game_box)
	# 左上：資金
	var mp := _panel()
	mp.position = Vector2(12, 10)
	game_box.add_child(mp)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 0)
	mp.add_child(mv)
	money_lbl = _lbl("$0", 26, ACC)
	mv.add_child(money_lbl)
	money_sub = _lbl("", 13, DIM)
	mv.add_child(money_sub)
	# 上方中間：時鐘與速度
	var cp := _panel()
	cp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	cp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cp.position.y = 10
	game_box.add_child(cp)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 6)
	cp.add_child(ch)
	clock_lbl = _lbl("第 1 天 08:00", 20)
	clock_lbl.custom_minimum_size.x = 150
	ch.add_child(clock_lbl)
	wx_panel = PanelContainer.new()
	wx_panel.add_theme_stylebox_override("panel", _sb(Color(0.25, 0.45, 0.7), 8, 8))
	wx_lbl = _lbl("晴 25°C", 15, Color.WHITE)
	wx_panel.add_child(wx_lbl)
	wx_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	wx_panel.tooltip_text = "天氣"
	ch.add_child(wx_panel)
	for s in [[0.0, "暫停"], [1.0, "1×"], [2.0, "2×"], [4.0, "4×"]]:
		var sp: float = s[0]
		var b := _btn(s[1], func(): G.set_speed(sp); _refresh_speed(), false, 15)
		b.custom_minimum_size = Vector2(48, 36)
		ch.add_child(b)
		speed_btns.append([sp, b])
	# 右上：評價、容量、選單
	var rp := _panel()
	rp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	rp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rp.position = Vector2(-12, 10)
	game_box.add_child(rp)
	var rv := VBoxContainer.new()
	rp.add_child(rv)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 10)
	rv.add_child(rh)
	stars_lbl = _lbl("★★★☆☆", 22, ACC)
	rh.add_child(stars_lbl)
	var mb := _btn("選單", toggle_menu, false, 15)
	mb.custom_minimum_size = Vector2(60, 36)
	rh.add_child(mb)
	cap_lbl = _lbl("", 13, DIM)
	rv.add_child(cap_lbl)
	# 左側：委託清單
	side_panel = _panel(BG, 12, 8)
	side_panel.position = Vector2(12, 92)
	side_panel.custom_minimum_size = Vector2(300, 0)
	side_panel.size = Vector2(300, 0)
	game_box.add_child(side_panel)
	var sv := VBoxContainer.new()
	side_panel.add_child(sv)
	var tabs := HBoxContainer.new()
	sv.add_child(tabs)
	tab_offers = _btn("新委託", func(): showing_offers = true; _refresh_list(), true, 15)
	tab_offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(tab_offers)
	tab_booked = _btn("已簽約", func(): showing_offers = false; _refresh_list(), false, 15)
	tab_booked.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(tab_booked)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(284, 0)
	list_scroll = sc
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 6)
	sc.add_child(list_box)
	# 下方工具列
	toolbar = _panel(BG, 14, 8)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toolbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toolbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toolbar.position.y = -10
	game_box.add_child(toolbar)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 6)
	toolbar.add_child(th)
	for k in ["rack", "cold", "fragile", "inspect"]:
		var kk: String = k
		var tb := _tool_btn("", func(): main.build_start(kk))
		price_btns.append([tb, G.BUILD[k].name, int(G.BUILD[k].price)])
		th.add_child(tb)
	var fb := _tool_btn("", func(): main.build_cancel(); main.buy_forklift())
	price_btns.append([fb, "堆高機", G.FORKLIFT_PRICE])
	th.add_child(fb)
	var db := _tool_btn("", func(): main.build_cancel(); _confirm_door())
	price_btns.append([db, "碼頭門", G.DOOR_PRICE])
	th.add_child(db)
	_refresh_prices()
	G.market_changed.connect(_refresh_prices)
	th.add_child(_tool_btn("拆除\n退一半", func(): main.build_start("demolish")))
	th.add_child(_tool_btn("擴建\n地・鐵路・港口", func(): main.build_cancel(); show_expand(), true))
	# 建造提示
	hint_bar = _panel(BG2, 10, 10)
	hint_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_bar.position.y = -96
	hint_bar.visible = false
	game_box.add_child(hint_bar)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 10)
	hint_bar.add_child(hh)
	hint_lbl = _lbl("", 15)
	hh.add_child(hint_lbl)
	hh.add_child(_btn("旋轉 (R)", func(): main.build_rotate(), false, 14))
	hh.add_child(_btn("完成", func(): main.build_cancel(), true, 14))
	# 提示訊息
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_box.position.y = -150
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 6)
	game_box.add_child(toast_box)
	# 右側資訊
	info_panel = _panel(BG, 12, 12)
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info_panel.position = Vector2(-12, -86)
	info_panel.custom_minimum_size = Vector2(260, 0)
	info_panel.visible = false
	game_box.add_child(info_panel)
	var iv := VBoxContainer.new()
	info_panel.add_child(iv)
	info_lbl = RichTextLabel.new()
	info_lbl.bbcode_enabled = true
	info_lbl.fit_content = true
	info_lbl.custom_minimum_size = Vector2(240, 0)
	info_lbl.add_theme_font_size_override("normal_font_size", 15)
	info_lbl.add_theme_font_size_override("bold_font_size", 17)
	iv.add_child(info_lbl)
	iv.add_child(_btn("關閉", hide_info, false, 14))
	# 右側：通關文件
	doc_panel = _panel(BG, 12, 10)
	doc_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	doc_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	doc_panel.position = Vector2(-12, 92)
	doc_panel.custom_minimum_size = Vector2(310, 0)
	doc_panel.visible = false
	game_box.add_child(doc_panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	doc_panel.add_child(dv)
	var dh := HBoxContainer.new()
	dv.add_child(dh)
	var dt := _lbl("通關文件", 17, ACC)
	dt.add_theme_font_override("font", M.font_bold)
	dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dt)
	doc_toggle = _btn("收起", func(): doc_open = not doc_open; _refresh_docs(), false, 13)
	doc_toggle.custom_minimum_size = Vector2(56, 30)
	dh.add_child(doc_toggle)
	var dsc := ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dsc.custom_minimum_size = Vector2(296, 0)
	dv.add_child(dsc)
	doc_body = VBoxContainer.new()
	doc_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doc_body.add_theme_constant_override("separation", 4)
	dsc.add_child(doc_body)
	G.contracts_changed.connect(_refresh_docs)
	G.property_changed.connect(_refresh_docs)
	# 左下角：市場行情（油價、物價）
	market_panel = _panel(BG, 12, 6)
	market_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	market_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	market_panel.position = Vector2(12, -10)
	market_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	market_panel.tooltip_text = "點一下看油價與物價走勢"
	game_box.add_child(market_panel)
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 2)
	mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	market_panel.add_child(mh)
	g_oil = Gauge.new()
	g_oil.title = "國際油價"
	g_oil.vmin = 40.0
	g_oil.vmax = 140.0
	mh.add_child(g_oil)
	g_cpi = Gauge.new()
	g_cpi.title = "物價指數"
	g_cpi.vmin = 90.0
	g_cpi.vmax = 140.0
	mh.add_child(g_cpi)
	market_panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Snd.play("click", 0.5)
			show_market())
	G.market_changed.connect(_refresh_market)
	G.weather_changed.connect(_refresh_weather)
	# 新聞快報
	news_bar = _panel(Color(0.08, 0.08, 0.1, 0.95), 6, 8)
	news_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	news_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	news_bar.position.y = 74
	news_bar.visible = false
	news_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(news_bar)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	news_bar.add_child(nh)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", _sb(Color(0.85, 0.12, 0.15), 4, 8))
	tag.add_child(_lbl("新聞快報", 16, Color.WHITE))
	nh.add_child(tag)
	news_lbl = _lbl("", 17, Color.WHITE)
	nh.add_child(news_lbl)
	# 更新提示
	update_bar = _panel(Color(0.2, 0.45, 0.3, 0.95), 10, 10)
	update_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	update_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	update_bar.position.y = 66
	update_bar.visible = false
	root.add_child(update_bar)

func _refresh_prices() -> void:
	for it in price_btns:
		(it[0] as Button).text = "%s\n%s" % [it[1], G.fmt(G.price(int(it[2])))]

func _tool_btn(t: String, cb: Callable, accent := false) -> Button:
	var b := _btn(t, cb, accent, 14)
	b.custom_minimum_size = Vector2(84, 58)
	return b

func show_game() -> void:
	if title_box:
		title_box.queue_free()
		title_box = null
	game_box.visible = true
	_refresh_top()
	_refresh_list()
	_refresh_speed()
	_refresh_docs()
	_refresh_market()
	_refresh_weather()

func _process(delta: float) -> void:
	if _voice_btn and is_instance_valid(_voice_btn) and _help_page >= 0:
		var want := _voice_label()
		if _voice_btn.text != want:
			_voice_btn.text = want
	if not game_box.visible:
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.25
		clock_lbl.text = "第 %d 天  %s" % [G.day(), G.clock_text()]
		_refresh_weather()
		_refresh_speed()
		_refresh_cap()
		if info_panel.visible:
			_refresh_info()
		_list_t -= 1
		if _list_t <= 0:
			_list_t = 4
			if not showing_offers:
				_refresh_list()
			_refresh_docs()

func _refresh_speed() -> void:
	for s in speed_btns:
		var b: Button = s[1]
		var on: bool = is_equal_approx(float(s[0]), G.speed)
		b.add_theme_stylebox_override("normal", _sb(ACC if on else Color(0.26, 0.31, 0.42), 8, 12))
		b.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12) if on else TXT)

func _refresh_top() -> void:
	money_lbl.text = G.fmt(G.money)
	money_lbl.add_theme_color_override("font_color", ACC if G.money >= 0 else BAD)
	money_sub.text = "昨日 %s ・ 每日支出 %s" % [G.fmt(G.yesterday), G.fmt(G.daily_cost())]
	var s := G.stars()
	stars_lbl.text = "★".repeat(s) + "☆".repeat(5 - s)
	stars_lbl.tooltip_text = "評價 %d / 100" % int(G.rating)

func _refresh_cap() -> void:
	if main == null or main.world == null:
		return
	var tot: Dictionary = main.world.total_capacity()
	var fr: Dictionary = main.world.free_capacity()
	var parts: Array = []
	for k in ["general", "cold", "fragile"]:
		if int(tot[k]) > 0:
			parts.append("%s %d/%d" % [G.CARGO[k].name, int(tot[k]) - int(fr[k]), int(tot[k])])
	parts.append("堆高機 %d" % main.world.forklifts.size())
	cap_lbl.text = "　".join(parts)

# ── 委託清單 ──
func _refresh_list() -> void:
	tab_offers.text = "新委託 %d" % G.offers.size()
	tab_booked.text = "已簽約 %d" % G.contracts.size()
	tab_offers.add_theme_stylebox_override("normal", _sb(ACC if showing_offers else Color(0.26, 0.31, 0.42), 8, 12))
	tab_offers.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12) if showing_offers else TXT)
	tab_booked.add_theme_stylebox_override("normal", _sb(ACC if not showing_offers else Color(0.26, 0.31, 0.42), 8, 12))
	tab_booked.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12) if not showing_offers else TXT)
	var keep_scroll := list_scroll.scroll_vertical
	for ch in list_box.get_children():
		list_box.remove_child(ch)
		ch.queue_free()
	list_scroll.set_deferred("scroll_vertical", keep_scroll)
	var arr: Array = G.offers if showing_offers else G.contracts
	if arr.is_empty():
		var l := _lbl("目前沒有新委託，稍等一下客戶就會打來。" if showing_offers else "還沒有簽約的委託。到「新委託」挑幾張吧！", 14, DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 270
		list_box.add_child(l)
		list_scroll.custom_minimum_size.y = 60
		side_panel.size.y = 0
		return
	var sorted := arr.duplicate()
	if not showing_offers:
		sorted.sort_custom(func(a, b): return _next_time(a) < _next_time(b))
	for c in sorted:
		list_box.add_child(_card(c))
	var vp_h := root.get_viewport_rect().size.y
	list_scroll.custom_minimum_size.y = minf(sorted.size() * 84.0, vp_h - 92 - 60 - 150)
	side_panel.size.y = 0

func _next_time(c: Dictionary) -> float:
	if c.state in ["offer", "booked"]:
		return float(c.arrive)
	if c.state == "stored":
		return float(c.pickup)
	return 0.0

func _card(c: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.95, 0.93, 0.88) if not c.mystery else Color(0.3, 0.3, 0.32), 8, 8))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var dark := Color(0.12, 0.13, 0.17) if not c.mystery else TXT
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var nm := _lbl(c.client, 15, dark)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	h.add_child(_lbl(G.fmt(int(c.pay)), 15, Color(0.15, 0.5, 0.25) if not c.mystery else ACC))
	var kind_txt := "轉運" if c.cross else ("存 %d 天" % int(c.days))
	var how := G.intl_label(c) if c.get("intl", "") != "" else G.leg_text(c)
	v.add_child(_lbl("%s・%s %d 板・%s" % [how, G.CARGO[c.cargo].name, int(c.n), kind_txt], 13, dark.lerp(Color(0.5, 0.5, 0.5), 0.3)))
	var line3 := ""
	var tag := []
	match c.state:
		"offer":
			line3 = "抵達 %s" % G.when_text(float(c.arrive))
			tag = G.fit_text(c)
		"booked":
			line3 = "等待抵達 %s" % G.when_text(float(c.arrive))
		"inbound":
			line3 = "收貨中 %d/%d" % [int(c.unloaded), int(c.n)]
		"stored":
			line3 = "存放中，%s 取貨" % G.when_text(float(c.pickup))
		"outbound":
			line3 = "出貨中 %d/%d" % [int(c.loaded), int(c.unloaded)]
			if int(c.late_pen) > 0:
				line3 += "（遲交扣 %s）" % G.fmt(int(c.late_pen))
	if c.state != "offer" and not c.get("customs", {}).is_empty():
		var ct := G.customs_text(c)
		var ck := "good" if c.customs.stage == "released" else ("warn" if G.missing_docs(c) > 0 or c.customs.stage == "inspect_move" else "info")
		tag = [ct, ck]
	var h3 := HBoxContainer.new()
	h3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h3)
	var l3 := _lbl(line3, 13, dark)
	l3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h3.add_child(l3)
	if not tag.is_empty():
		var col: Color = GOOD.darkened(0.3) if tag[1] == "good" else (Color(0.75, 0.5, 0.0) if tag[1] == "warn" else (Color(0.2, 0.4, 0.75) if tag[1] == "info" else Color(0.8, 0.2, 0.15)))
		h3.add_child(_lbl(tag[0], 13, col))
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Snd.play("click", 0.5)
			if c.state == "offer":
				_offer_dialog(c)
			else:
				if not c.get("customs", {}).is_empty():
					doc_sel = int(c.id)
					doc_open = true
					_refresh_docs()
				_focus_contract(c))
	return p

func _focus_contract(c: Dictionary) -> void:
	for v in main.world.vehicles:
		if is_instance_valid(v) and v.cid == int(c.id):
			main.cam.focus(v.global_position)
			show_vehicle_info(v)
			return
	for p in main.world.pallets:
		if p.cid == int(c.id) and is_instance_valid(p.node):
			main.cam.focus(p.node.global_position)
			return

func _offer_dialog(c: Dictionary) -> void:
	var fit: Array = G.fit_text(c)
	var kind_txt := "轉運（約 %d 小時後由另一台車取走）" % int(round((float(c.pickup) - float(c.arrive)) / 60.0)) if c.cross else "存放 %d 天" % int(c.days)
	var body := "[b]%s[/b]\n\n運輸：%s\n貨物：%s × %d 板\n抵達：%s\n取貨：%s\n方式：%s\n\n報酬：[color=#7fe08a][b]%s[/b][/color]（出貨完成時入帳）\n空位：%s（%s 空位 %d）" % [
		c.client, G.TRANSPORT[c.transport], G.CARGO[c.cargo].name, int(c.n), G.when_text(float(c.arrive)), G.when_text(float(c.pickup)),
		kind_txt, G.fmt(int(c.pay)), fit[0], G.CARGO[c.cargo].name, maxi(G.free_slots(c.cargo), 0)]
	if c.get("tin", "truck") != c.get("tout", "truck"):
		var trips_in := ceili(float(c.n) / float(G.CAP[c.tin]))
		var trips_out := ceili(float(c.n) / float(G.CAP[c.tout]))
		body += "\n進出：%s 送來（%d 趟）、%s 載走（%d 趟）" % [G.TRANSPORT[c.tin], trips_in, G.TRANSPORT[c.tout], trips_out]
	if c.get("intl", "") != "":
		var names: Array = []
		for d in c.customs.docs:
			names.append(d.name)
		body += "\n\n[b]國際貨（%s）[/b]：要辦海關手續。\n需要文件：%s，再由我們製作%s報關單。\n%s後申報；海關可能抽中 [b]C2 書面審核[/b] 或 [b]C3 貨物查驗[/b]（要有海關查驗台）。放行後才能出貨。" % [
			G.intl_label(c), "、".join(names), "進口" if c.intl == "import" else "出口", "貨到" if c.intl == "import" else "貨全部進倉"]
		if not main.world.has_table():
			body += "\n[color=#ffcc66]提醒：你還沒有海關查驗台。[/color]"
	if c.cargo == "cold" and main.world.total_capacity().cold == 0:
		body += "\n\n[color=#ff8a80]你還沒有冷藏櫃！[/color]"
	elif c.cargo == "fragile" and main.world.total_capacity().fragile == 0:
		body += "\n\n[color=#ff8a80]你還沒有易碎品籠架！[/color]"
	show_dialog("委託內容", body, [["簽約", func(): G.accept_offer(c), true], ["婉拒", func(): G.decline_offer(c), false], ["再想想", func(): pass, false]])

func _refresh_market() -> void:
	if g_oil == null:
		return
	g_oil.set_data(G.oil, G.oil_change(), "$%.1f" % G.oil)
	g_cpi.set_data(G.cpi, G.cpi_change(), "%.1f" % G.cpi)

func _refresh_weather() -> void:
	if wx_lbl == null:
		return
	var k := G.weather_kind()
	var col := {"sunny": Color(0.85, 0.55, 0.1), "cloudy": Color(0.45, 0.52, 0.6), "rain": Color(0.25, 0.4, 0.65), "typhoon": Color(0.75, 0.15, 0.2)}[k] as Color
	var t := G.weather_text()
	if G.typhoon_eta > 0.0:
		t += "｜颱風警報 %d 小時後" % maxi(1, int((G.typhoon_eta - G.minute) / 60.0))
		col = Color(0.8, 0.35, 0.1)
	wx_lbl.text = t
	wx_panel.add_theme_stylebox_override("panel", _sb(col, 8, 8))
	var tip := "天氣：%s" % G.WEATHER_NAMES[k]
	match k:
		"rain": tip += "\n卡車開慢一點（-20%）"
		"typhoon": tip += "\n港口封港、機場停飛、火車停駛；卡車很慢；延誤不扣錢"
	wx_panel.tooltip_text = tip

func show_market() -> void:
	var v := show_dialog("市場行情", "", [["關閉", func(): pass, true]], 560)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	v.add_child(grid)
	v.move_child(grid, 1)
	for it in [["國際油價（美元／桶）", G.oil_hist, Color(1.0, 0.6, 0.25), "%.0f"], ["物價指數（開業時 = 100）", G.cpi_hist, Color(0.45, 0.8, 1.0), "%.1f"]]:
		var col := VBoxContainer.new()
		col.add_child(_lbl(it[0], 14, DIM))
		var ch := LineChart.new()
		ch.set_data(it[1], it[2], it[3])
		col.add_child(ch)
		grid.add_child(col)
	var fx := RichTextLabel.new()
	fx.bbcode_enabled = true
	fx.fit_content = true
	fx.custom_minimum_size = Vector2(520, 0)
	var mult := G.cpi / 100.0
	var sur := (G.oil - 80.0) / 80.0 * 20.0
	fx.text = "目前油價 [b]$%.1f[/b]（%s%.1f%%），物價指數 [b]%.1f[/b]（%s%.2f%%）\n\n對你的影響：\n• 堆高機燃料費：每日 [b]%s[/b]（油價 × 0.5 × 台數）\n• 建造、地租、薪水、維護費 × [b]%.2f[/b]\n• 新委託報酬 × %.2f，燃油附加費 %s%.0f%%\n\n油價會受國際局勢、颱風影響；油價越高，物價也漲得越快。" % [
		G.oil, "+" if G.oil_change() >= 0 else "", G.oil_change(), G.cpi, "+" if G.cpi_change() >= 0 else "", G.cpi_change(),
		G.fmt(G.fuel_daily()), mult, mult, "+" if sur >= 0 else "", sur]
	v.add_child(fx)
	v.move_child(fx, 2)

func cinematic(on: bool) -> void:
	cine = on
	for c in [side_panel, doc_panel, toolbar, market_panel, info_panel, hint_bar]:
		if c:
			c.visible = not on
	if not on:
		info_panel.visible = false
		hint_bar.visible = false
		_refresh_docs()

func show_news(t: String) -> void:
	news_lbl.text = t
	news_bar.visible = true
	news_bar.size.x = 0

func hide_news() -> void:
	news_bar.visible = false

# ── 通關文件面板 ──
func _refresh_docs() -> void:
	if doc_panel == null or main == null or cine:
		return
	var intl: Array = []
	for c in G.contracts:
		if not c.get("customs", {}).is_empty():
			intl.append(c)
	doc_panel.visible = game_box.visible and (not intl.is_empty() or G.harbour or G.airport)
	if not doc_panel.visible:
		return
	doc_toggle.text = "收起" if doc_open else "展開"
	for ch in doc_body.get_children():
		doc_body.remove_child(ch)
		ch.queue_free()
	if not doc_open:
		var l0 := _lbl("國際貨物 %d 筆" % intl.size(), 13, DIM)
		doc_body.add_child(l0)
		doc_panel.size.y = 0
		return
	if intl.is_empty():
		var l := _lbl("目前沒有國際貨物。\n接下貨輪或貨機的委託後，這裡會列出提單、發票等文件和海關通關進度。", 13, DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 290
		doc_body.add_child(l)
		doc_panel.size.y = 0
		return
	var found := false
	for c in intl:
		if int(c.id) == doc_sel:
			found = true
	if not found:
		doc_sel = int(intl[0].id)
	for c in intl:
		var sel := int(c.id) == doc_sel
		var row := _btn("%s　%s" % [c.client, G.customs_text(c)], func(): doc_sel = int(c.id); _refresh_docs(), sel, 13)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(290, 32)
		doc_body.add_child(row)
		if sel:
			doc_body.add_child(_doc_detail(c))
	var vp_h := root.get_viewport_rect().size.y
	(doc_body.get_parent() as ScrollContainer).custom_minimum_size.y = minf(doc_body.get_combined_minimum_size().y, vp_h - 92 - 120 - 60)
	doc_panel.size.y = 0

func _doc_detail(c: Dictionary) -> Control:
	var cu: Dictionary = c.customs
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.96, 0.95, 0.9), 8, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var ink := Color(0.12, 0.13, 0.17)
	var green := Color(0.15, 0.5, 0.25)
	var amber := Color(0.75, 0.45, 0.0)
	v.add_child(_lbl("%s・%s %d 板" % [G.intl_label(c), G.CARGO[c.cargo].name, int(c.n)], 14, ink))
	# 進度
	var order := ["docs", "declared", "check", "released"]
	var names := {"docs": "文件齊全", "declared": "海關申報", "check": "審核／查驗", "released": "放行"}
	var st: String = cu.stage
	var cur := 0
	match st:
		"docs": cur = 0
		"declared": cur = 1
		"review", "inspect_move", "inspecting", "inspect_return": cur = 2
		"released": cur = 4
	var prog := ""
	for i in order.size():
		var mark := "■" if i < cur else ("▶" if i == cur else "□")
		prog += "%s%s　" % [mark, names[order[i]]]
	var pl := _lbl(prog, 12, ink)
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pl.custom_minimum_size.x = 270
	v.add_child(pl)
	var stl := _lbl("目前：%s%s" % [G.STAGE_NAMES.get(st, st), ("（%s）" % cu.cls) if cu.cls != "" and st != "released" else ""], 13, green if st == "released" else Color(0.2, 0.35, 0.7))
	v.add_child(stl)
	if st in ["review", "inspecting", "declared"]:
		v.add_child(_lbl("預計 %s 完成" % G.when_text(float(cu.t)), 12, ink.lerp(Color.GRAY, 0.4)))
	if st == "inspect_move" and not main.world.has_table():
		var w := _lbl("需要蓋「海關查驗台」！", 13, Color(0.8, 0.2, 0.15))
		v.add_child(w)
	var sep := HSeparator.new()
	v.add_child(sep)
	# 文件清單
	for i in cu.docs.size():
		var d: Dictionary = cu.docs[i]
		var h := HBoxContainer.new()
		v.add_child(h)
		var nl := _lbl(("■ " if d.ok else "□ ") + d.name, 13, ink)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		if d.ok:
			h.add_child(_lbl("已收到", 12, green))
		else:
			h.add_child(_lbl("待補 %s" % G.clock_text(float(d.eta)) if bool(d.chased) else "待補", 12, amber))
			if not bool(d.chased):
				var ii: int = i
				var b := _btn("催件", func(): G.chase_doc(c, ii); _refresh_docs(), true, 12)
				b.custom_minimum_size = Vector2(48, 26)
				h.add_child(b)
	var decl := "進口報關單" if c.intl == "import" else "出口報關單"
	var dh := HBoxContainer.new()
	v.add_child(dh)
	var dl := _lbl(("■ " if st != "docs" else "□ ") + decl + "（我方製作）", 13, ink)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dl)
	var ds := "等文件齊全" if st == "docs" else ("已送出" if st == "declared" else ("已核准" if st == "released" else "審核中"))
	dh.add_child(_lbl(ds, 12, green if st == "released" else amber))
	var when := "取貨" if c.intl == "import" else "裝船／裝機"
	v.add_child(_lbl("%s：%s" % [when, G.when_text(float(c.pickup))], 12, ink.lerp(Color.GRAY, 0.4)))
	if int(c.late_pen) > 0:
		v.add_child(_lbl("延誤扣款 %s" % G.fmt(int(c.late_pen)), 12, Color(0.8, 0.2, 0.15)))
	return p

# ── 提示訊息 ──
func add_toast(text: String, kind: String = "info") -> void:
	if not game_box.visible:
		return
	var col := BG2
	if kind == "good":
		col = Color(0.17, 0.36, 0.25, 0.95)
	elif kind == "bad":
		col = Color(0.45, 0.17, 0.16, 0.95)
	var p := _panel(col, 10, 10)
	var l := _lbl(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	while toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := p.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)

func _undo_toast(text: String, refund: int, cb: Callable) -> void:
	var p := _panel(BG2, 10, 8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var l := _lbl("%s（10 秒內可全額退回）" % text, 15)
	h.add_child(l)
	var b := _btn("撤銷", func(): pass, true, 14)
	h.add_child(b)
	b.pressed.connect(func():
		if cb.call():
			G.toast.emit("已撤銷，退回 %s" % G.fmt(refund), "info")
		else:
			G.toast.emit("已經在使用中，無法撤銷", "bad")
		p.queue_free())
	toast_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(10.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)

# ── 建造提示 ──
func show_build_hint(kind: String) -> void:
	hint_bar.visible = true
	if kind == "demolish":
		hint_lbl.text = "拆除模式：點空的貨架拆掉，退回一半價錢"
	else:
		var d: Dictionary = G.BUILD[kind]
		hint_lbl.text = "擺放%s %s・%s" % [d.name, G.fmt(G.price(int(d.price))), d.desc]

func hide_build_hint() -> void:
	hint_bar.visible = false

# ── 資訊面板 ──
func show_vehicle_info(v) -> void:
	info_target = v
	info_panel.visible = true
	_refresh_info()

func show_rack_info(r) -> void:
	info_target = r
	info_panel.visible = true
	_refresh_info()

func hide_info() -> void:
	info_target = null
	info_panel.visible = false

func _refresh_info() -> void:
	var t = info_target
	if t == null:
		hide_info()
		return
	if t is Vehicle:
		if not is_instance_valid(t):
			hide_info()
			return
		var c := G.contract_by_id(t.cid)
		var nm := {"truck": "卡車", "van": "沒有標記的廂型車", "rail": "貨運列車", "ship": "貨輪", "air": "貨機"}
		var s := "[b]%s[/b]\n" % nm.get(t.kind, "車輛")
		if c.is_empty():
			s += "任務完成，正在離開。"
		else:
			s += "客戶：%s\n貨物：%s\n" % [c.client, G.CARGO[c.cargo].name]
			if t.mode == "in":
				s += "送貨進來：已卸 %d / %d 板\n" % [int(c.unloaded), int(c.n)]
			else:
				s += "來取貨：已裝 %d / %d 板\n" % [int(c.loaded), int(c.unloaded)]
			var st := {"approach": "正在開往碼頭", "queue": "碼頭都滿了，排隊中", "docked": "靠在碼頭作業中", "decide": "等你決定", "leaving": "離開中", "raid": "……"}
			s += "狀態：%s" % st.get(t.state, t.state)
			if t.state == "docked" and t.mode == "in" and t.stall > 30.0:
				s += "\n[color=#ffcc66]卸不下來了！貨架滿了或堆高機不夠。[/color]"
		info_lbl.text = s
	else:
		var r = t
		if not (r in main.world.racks):
			hide_info()
			return
		var d: Dictionary = G.BUILD[r.kind]
		var s2 := "[b]%s[/b]\n%s\n\n使用中 %d / %d 格\n每日維護 %s" % [d.name, d.desc, r.used(), r.slots.size(), G.fmt(int(d.upkeep))]
		var owners := {}
		for p in r.slots:
			if p != null:
				var c2 := G.contract_by_id(p.cid)
				var key: String = c2.client if not c2.is_empty() else "（無主）"
				owners[key] = int(owners.get(key, 0)) + 1
		for k in owners:
			s2 += "\n・%s %d 板" % [k, owners[k]]
		info_lbl.text = s2

# ── 對話框 ──
func show_dialog(title: String, body: String, buttons: Array, width := 460, pause := false) -> Control:
	close_modal()
	var was := G.speed
	if pause:
		G.set_speed(0.0)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(cc)
	var p := _panel(BG2, 16, 20)
	p.custom_minimum_size.x = width
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_lbl(title, 22, ACC))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.text = body
	rt.custom_minimum_size = Vector2(width - 40, 0)
	rt.add_theme_font_size_override("normal_font_size", 16)
	rt.add_theme_font_size_override("bold_font_size", 18)
	v.add_child(rt)
	var h := HFlowContainer.new()
	h.alignment = FlowContainer.ALIGNMENT_END
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 8)
	v.add_child(h)
	var m := modal
	for b in buttons:
		var cb: Callable = b[1]
		h.add_child(_btn(b[0], func():
			if modal == m:
				close_modal()
			if pause and G.speed == 0.0 and not G.over:
				G.set_speed(was if was > 0.0 else G.speed_before_pause)
			cb.call(), bool(b[2])))
	return v

func close_modal() -> void:
	if _help_page >= 0 or Snd.voice_playing():
		Snd.stop_voice()
	_voice_btn = null
	if modal:
		modal.queue_free()
		modal = null

func _confirm_door() -> void:
	var gi: int = main.next_door()
	if gi < 0:
		show_dialog("碼頭門", "這塊地的門都開好了。到「擴建」買隔壁的地，就能再開門。", [["知道了", func(): pass, true]])
		return
	show_dialog("加開碼頭門？", "開啟 %d 號門，可以同時多停一台卡車。\n\n費用 [b]%s[/b]，沒有每日支出。" % [gi + 1, G.fmt(G.price(G.DOOR_PRICE))],
		[["開門", func(): main.buy_door(), true], ["取消", func(): pass, false]])

func show_expand() -> void:
	close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(cc)
	var p := _panel(BG2, 16, 20)
	p.custom_minimum_size.x = 560
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(_lbl("擴建", 22, ACC))
	var items: Array = []
	if G.plots < G.PLOT_PRICES.size():
		var price: int = G.price(G.PLOT_PRICES[G.plots])
		items.append(["買下隔壁的地（第 %d 塊）" % (G.plots + 1), "倉庫向右延伸 10 格，多 3 個碼頭門位（送一扇門）。每日地租 +%s。" % G.fmt(G.PLOT_RENT), price, func(): main.buy_plot()])
	else:
		items.append(["地都買齊了", "整條街都是你的倉庫了！", 0, Callable()])
	if not G.rail:
		items.append(["鋪設鐵路支線", "把後面那條廢棄的鐵道接回來，後牆開一扇鐵路門。火車一次運 8～12 板一般貨，報酬加成。每日 %s。" % G.fmt(G.RAIL_DAILY), G.price(G.RAIL_PRICE), func(): main.buy_rail()])
	else:
		items.append(["鐵路支線", "已啟用。", 0, Callable()])
	if not G.harbour:
		items.append(["興建港口", "海邊蓋碼頭、起重機和高架輸送帶，貨輪一次 12～18 板。每日 %s。" % G.fmt(G.HARBOUR_DAILY), G.price(G.HARBOUR_PRICE), func(): main.buy_harbour()])
	else:
		items.append(["港口", "已啟用。", 0, Callable()])
	if not G.airport:
		items.append(["興建航空貨運站", "倉庫左邊蓋跑道、停機坪、塔台和機庫，左牆開一扇空運門。貨機一次 4～8 板高價值國際貨（電子、生技、精品），報酬最高，但都要辦海關手續。每日 %s。" % G.fmt(G.AIRPORT_DAILY), G.price(G.AIRPORT_PRICE), func(): main.buy_airport()])
	else:
		items.append(["航空貨運站", "已啟用。", 0, Callable()])
	for it in items:
		var row := _panel(Color(0.22, 0.27, 0.36), 10, 10)
		v.add_child(row)
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 12)
		row.add_child(rh)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(tv)
		tv.add_child(_lbl(it[0], 17))
		var dl := _lbl(it[1], 13, DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 360
		tv.add_child(dl)
		if int(it[2]) > 0:
			var cb: Callable = it[3]
			var price2: int = it[2]
			var b := _btn("購買 %s" % G.fmt(price2), func(): close_modal(); cb.call(), true, 15)
			b.disabled = G.money < price2
			rh.add_child(b)
	var close := _btn("關閉", close_modal, false, 15)
	v.add_child(close)

# ── 神秘來電 ──
func _phone_call(c: Dictionary) -> void:
	var body := "[i]電話那頭的聲音壓得很低：[/i]\n\n「頭家，我是%s啦。聽說你最近手頭有點緊？我這邊有 [b]%d 箱貨[/b]，想寄放在你那 %d 天。不用問裡面是什麼。」\n\n「訂金 [b]%s[/b] 現在就給你，來拿的時候再付 [color=#ffcc66][b]%s[/b][/color] 現金。」\n\n「車子 %s 到。」\n\n[color=#ff8a80]注意：每一台來的車都可能是臥底警察。被抓到就失去一切。[/color]" % [
		c.client, int(c.n), int(c.days), G.fmt(int(c.advance)), G.fmt(int(c.pay)), G.when_text(float(c.arrive))]
	show_dialog("一通陌生來電", body, [
		["答應", func(): G.accept_mystery(c); G.set_speed(G.speed_before_pause), true],
		["假裝答應並報警", func():
			c["reported"] = true
			c["advance"] = 0
			G.accept_mystery(c)
			G.set_speed(G.speed_before_pause)
			G.toast.emit("你偷偷通報了警方。警方會在 %s 車子到的時候埋伏。" % G.when_text(float(c.arrive)), "info"), false],
		["掛掉電話", func(): G.set_speed(G.speed_before_pause); G.toast.emit("你掛掉了電話。", "info"), false]], 520)

func mystery_arrival(v) -> void:
	main.cam.focus(v.global_position, 22.0)
	var c := G.contract_by_id(v.cid)
	var what := "送貨來了" if v.mode == "in" else "來取貨了"
	_mystery_dialog(v, "一台沒有標記的廂型車%s。車燈關著，司機在等你開門。\n\n%s" % [what, "（%s 的 %d 箱）" % [c.get("client", "?"), int(c.get("n", 0))]])

func _mystery_dialog(v, body: String) -> void:
	var btns: Array = [["開門", func(): v.decide(true), true]]
	if not v.observed:
		btns.append(["觀察司機（30 分鐘）", func():
			var clue: String = v.observe()
			_mystery_dialog(v, "你躲在窗後觀察了一會兒……\n\n[i]%s[/i]\n\n要開門嗎？" % clue), false])
	btns.append(["報警", func(): v.report_police(), false])
	btns.append(["拒收", func(): v.decide(false), false])
	show_dialog("深夜的廂型車", body, btns, 480)

# ── 結束 ──
func _game_over(title: String, body: String) -> void:
	close_modal()
	var v := show_dialog(title, body, [["重新開始", func(): main.restart("new"), true], ["回標題", func(): main.restart(""), false]], 480)
	if v:
		v.get_parent().add_theme_stylebox_override("panel", _sb(Color(0.3, 0.12, 0.12, 0.97), 16, 20))

# ── 選單、說明、更新紀錄 ──
func toggle_menu() -> void:
	if modal:
		close_modal()
		return
	show_dialog("選單", "第 %d 天 ・ 完成委託 %d 筆 ・ 搬運托盤 %d 板 ・ 累計收入 %s\n\n目前音樂：%s" % [G.day(), int(G.stats.contracts), int(G.stats.pallets), G.fmt(int(G.stats.earned)), Snd.current_track_name()], [
		["遊戲說明", show_help, false], ["更新紀錄", show_changelog, false], ["設定", show_settings, false], ["建立捷徑", show_install, false], ["市場行情", show_market, false],
		["存檔", func(): G.save_game(); G.toast.emit("已存檔", "good"), false], ["回標題", func(): G.save_game(); main.restart(""), false],
		["繼續", func(): pass, true]], 680, true)

var _help_page := -1
var _voice_btn: Button

func _voice_label() -> String:
	return "■ 停止朗讀" if Snd.voice_playing() else "▶ 播放語音"

func _toggle_voice(page: int) -> void:
	if Snd.voice_playing():
		Snd.stop_voice()
	else:
		Snd.play_voice("help_%02d" % page)
	if _voice_btn:
		_voice_btn.text = _voice_label()

func show_help(page := 0) -> void:
	var was_page := _help_page
	close_modal()
	_help_page = page
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(cc)
	var p := _panel(BG2, 16, 18)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var tt := _lbl("遊戲說明", 22, ACC)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tt)
	_voice_btn = _btn(_voice_label(), func(): _toggle_voice(page), true, 15)
	_voice_btn.custom_minimum_size = Vector2(130, 36)
	top.add_child(_voice_btn)
	var ac := CheckBox.new()
	ac.text = "自動朗讀"
	ac.button_pressed = Snd.auto_voice
	ac.focus_mode = Control.FOCUS_NONE
	ac.add_theme_color_override("font_color", TXT)
	ac.toggled.connect(func(on: bool):
		Snd.auto_voice = on
		Snd.save_settings())
	top.add_child(ac)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	h.add_child(tabs)
	for i in Texts.HELP.size():
		var ii := i
		var b := _btn(Texts.HELP[i][0], func(): show_help(ii), i == page, 14)
		b.custom_minimum_size = Vector2(130, 34)
		tabs.add_child(b)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(520, 430)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(tv)
	tv.add_child(_lbl(Texts.HELP[page][0], 19))
	var body := _lbl(Texts.HELP[page][1], 16)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 500
	tv.add_child(body)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_END
	bh.add_theme_constant_override("separation", 8)
	v.add_child(bh)
	if page > 0:
		bh.add_child(_btn("上一頁", func(): show_help(page - 1), false, 15))
	if page < Texts.HELP.size() - 1:
		bh.add_child(_btn("下一頁", func(): show_help(page + 1), false, 15))
	bh.add_child(_btn("關閉", func(): Snd.stop_voice(); _help_page = -1; close_modal(), true, 15))
	# 換頁就朗讀新的一頁
	if Snd.auto_voice and (was_page != page or not Snd.voice_playing()):
		Snd.play_voice("help_%02d" % page)
	_voice_btn.text = _voice_label()

func show_changelog() -> void:
	var s := "目前版本：[b]v%s[/b]\n" % G.APP_VERSION
	if Updater.latest != "":
		s += "[color=#7fe08a]有新版本 v%s 可以更新！[/color]\n" % Updater.latest
	for e in Texts.CHANGELOG:
		s += "\n[b]v%s[/b]　%s\n%s\n" % [e[0], e[1], e[2]]
	var btns: Array = [["關閉", func(): pass, true]]
	if Updater.latest != "":
		btns.push_front(["立即更新", func(): Updater.apply(), true])
	else:
		btns.push_front(["檢查更新", func(): Updater.check(); G.toast.emit("正在檢查新版本……", "info"); add_title_toast("正在檢查新版本……"), false])
	show_dialog("更新紀錄", s, btns, 520)

func show_settings() -> void:
	close_modal()
	var v := show_dialog("設定", "", [["關閉", func(): Snd.save_settings(), true]], 420)
	for it in [["音樂音量", Snd.music_vol, func(x): Snd.set_music(x)], ["音效音量", Snd.sfx_vol, func(x): Snd.set_sfx(x)], ["語音音量", Snd.voice_vol, func(x): Snd.voice_vol = x]]:
		var h := HBoxContainer.new()
		var l := _lbl(it[0], 16)
		l.custom_minimum_size.x = 90
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = it[1]
		s.custom_minimum_size = Vector2(240, 32)
		var cb: Callable = it[2]
		s.value_changed.connect(func(x): cb.call(x))
		h.add_child(s)
		v.add_child(h)
		v.move_child(h, v.get_child_count() - 2)
	var nb := _btn("下一首音樂", func(): Snd.next_track(); G.toast.emit("播放：%s" % Snd.current_track_name(), "info"), false, 15)
	v.add_child(nb)
	v.move_child(nb, v.get_child_count() - 2)

func show_install() -> void:
	var st := Updater.install_state()
	match st:
		"prompt":
			Updater.install_prompt()
			add_toast("請在瀏覽器跳出的視窗按「安裝」，桌面或主畫面就會出現小柯物流大亨的圖示。", "info")
			add_title_toast("請在瀏覽器跳出的視窗按「安裝」")
		"installed":
			show_dialog("建立捷徑", "你現在就是從捷徑開啟的，已經安裝好了！", [["好", func(): pass, true]])
		"ios":
			show_dialog("建立捷徑（iPhone／iPad）", "用 [b]Safari[/b] 開啟這個網頁，然後：\n\n① 點「分享」按鈕（方框加向上箭頭）\n② 往下滑，點「[b]加入主畫面[/b]」\n③ 右上角按「新增」\n\n主畫面就會出現小柯機器人開堆高機的圖示，點它就能全螢幕玩。", [["知道了", func(): pass, true]], 500)
		"android":
			show_dialog("建立捷徑（Android）", "用 [b]Chrome[/b] 開啟這個網頁，然後：\n\n① 點右上角的選單（三個點）\n② 點「[b]加到主畫面[/b]」或「[b]安裝應用程式[/b]」\n③ 按「安裝」\n\n主畫面就會出現小柯物流大亨的圖示。", [["知道了", func(): pass, true]], 500)
		"desktop":
			show_dialog("建立捷徑", "這是電腦版，請從開始選單或安裝資料夾建立捷徑。\n線上版網址：%s" % Updater.SITE, [["開啟網站", func(): OS.shell_open(Updater.SITE), true], ["關閉", func(): pass, false]], 500)
		_:
			show_dialog("建立捷徑（電腦）", "用 [b]Chrome[/b] 或 [b]Edge[/b] 開啟這個網頁，然後：\n\n① 點網址列右邊的「安裝」小圖示\n　或右上角選單 →「投放、儲存與分享」→「[b]安裝網頁為應用程式[/b]」\n② 按「安裝」\n\n桌面和開始選單就會出現小柯物流大亨的捷徑，開起來像獨立程式一樣。", [["知道了", func(): pass, true]], 520)

func show_welcome() -> void:
	G.tutorial_done = true
	if Snd.auto_voice:
		Snd.play_voice("welcome")
	show_dialog("歡迎來到小柯物流！", "你剛租下這棟小倉庫，裡面有 [b]2 座一般貨架[/b] 和 [b]1 台堆高機[/b]（司機是小柯機器人）。\n\n① 左邊「新委託」點一張卡片，看看條件，按「簽約」。\n② 時間到，卡車會開到碼頭，堆高機自動把貨搬上貨架。\n③ 取貨時間到，貨出得去就收錢。\n\n賺到錢就從下方工具列蓋更多貨架、買堆高機，再到「擴建」買地、鋪鐵路、蓋港口。\n\n右上「選單」裡有完整的遊戲說明。祝生意興隆！", [["開始營業", func(): pass, true], ["看完整說明", func(): show_help(), false]], 520, true)

# ── 更新提示 ──
func _on_update(v: String, notes: String) -> void:
	for ch in update_bar.get_children():
		ch.queue_free()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	update_bar.add_child(h)
	h.add_child(_lbl("有新版本 v%s%s" % [v, ("：" + notes) if notes != "" else ""], 15))
	h.add_child(_btn("立即更新", func(): Updater.apply(), true, 14))
	h.add_child(_btn("稍後", func(): update_bar.visible = false, false, 14))
	update_bar.visible = true

func add_title_toast(t: String) -> void:
	if title_box == null:
		return
	var l := _lbl(t, 15, DIM)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.position.y -= 40
	title_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(l.queue_free)

# ── 標題畫面 ──
func show_title() -> void:
	game_box.visible = false
	title_box = Control.new()
	title_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(title_box)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.06, 0.08, 0.13, 0.94))
	g.set_color(1, Color(0.06, 0.08, 0.13, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(0.75, 0.5)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(grad)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(70, -290)
	v.add_theme_constant_override("separation", 10)
	title_box.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var ic := TextureRect.new()
	ic.texture = load("res://icon.svg")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(72, 72)
	top.add_child(ic)
	var sl := _lbl("小柯機器人系列", 18, Color(0.55, 0.85, 1.0))
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(sl)
	var t := _lbl("小柯機器人物流大亨", 52, ACC)
	t.add_theme_constant_override("outline_size", 8)
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	v.add_child(t)
	v.add_child(_lbl("從一間小倉庫，做到卡車、火車、貨輪都排隊上門的物流帝國", 17, DIM))
	var sp := Control.new()
	sp.custom_minimum_size.y = 16
	v.add_child(sp)
	var bw := 260
	if G.has_save():
		var b0 := _btn("繼續遊戲", func(): main.restart("load"), true, 20)
		b0.custom_minimum_size = Vector2(bw, 52)
		v.add_child(b0)
	var b1 := _btn("新遊戲", func():
		if G.has_save():
			show_dialog("開新遊戲？", "目前的存檔會被覆蓋。", [["開新遊戲", func(): G.delete_save(); main.restart("new"), true], ["取消", func(): pass, false]])
		else:
			main.restart("new"), not G.has_save(), 20)
	b1.custom_minimum_size = Vector2(bw, 52)
	v.add_child(b1)
	for it in [["遊戲說明", func(): show_help()], ["更新紀錄", show_changelog], ["設定", show_settings], ["建立捷徑", show_install]]:
		var b := _btn(it[0], it[1], false, 17)
		b.custom_minimum_size = Vector2(bw, 44)
		v.add_child(b)
	var foot := _lbl("v%s　・　開發者：吳玉柱 先生與 Claude AI Opus 5.5" % G.APP_VERSION, 14, DIM)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(24, -36)
	title_box.add_child(foot)
	var credit := _lbl("車輛與樹木模型：Kenney（CC0）　字型：Noto Sans TC（OFL）　音樂與音效：原創合成", 12, Color(0.5, 0.55, 0.62))
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credit.position = Vector2(-credit.get_minimum_size().x - 24, -32)
	title_box.add_child(credit)
	# 首次互動後才能播音樂（瀏覽器限制）
	Snd.start_music()
