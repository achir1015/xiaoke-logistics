extends Node
## 開發用自動測試：godot --path . -- --test --mode=new --speed=4 --accept --shots=3,20 --out=DIR --quit=30
## 選項：--money=N  --buy=rail,harbour,plot,door,forklift,rack  --cam=x,z,zoom  --call（強制來電）  --cop=0/1

var main
var args := {}
var shots: Array = []
var t := 0.0
var _shot_i := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	for s in String(args.get("shots", "")).split(",", false):
		shots.append(float(s))
	await get_tree().process_frame
	await get_tree().process_frame
	if args.get("mode", "title") != "title":
		if args.has("money"):
			G.money = int(args.money)
		for b in String(args.get("buy", "")).split(",", false):
			match b:
				"rail": main.buy_rail()
				"harbour": main.buy_harbour()
				"airport": main.buy_airport()
				"inspect":
					if main.world.can_place(Vector2i(4, 4), 0):
						main.world.place_rack("inspect", Vector2i(4, 4), 0)
				"plot": main.buy_plot()
				"door": main.buy_door()
				"forklift": main.buy_forklift()
				"rack":
					for i in 3:
						var c := Vector2i(5 + (i % 2) * 3, 1 + i * 2)
						if main.world.can_place(c, 1):
							main.world.place_rack(["rack", "cold", "fragile"][i], c, 1)
		main.world.refresh_capacity()
		G.set_speed(float(args.get("speed", "1")))
		if args.has("weather"):
			G.weather = {"kind": String(args.weather), "until": G.minute + 3000.0}
			G.weather_changed.emit()
		if args.has("contraband"):
			G.force_contraband = true
		if args.has("quake"):
			get_tree().create_timer(float(args.get("quakeat", "4"))).timeout.connect(func(): G.quake.emit(float(args.quake)))
		if args.has("cls"):
			G.force_cls = String(args.cls)
		if args.has("intl"):
			# 強制產生國際委託
			for i in int(args.intl):
				for k in 40:
					var o: Dictionary = G._make_offer()
					if o.intl != "" and (not args.has("ikind") or (o.transport == args.ikind and o.intl == "import")):
						o.arrive = G.minute + 30.0 + i * 60.0
						o.pickup = o.arrive + 300.0
						o.cross = true
						G.offers.append(o)
						break
		if args.has("call"):
			G.last_call_min = -99999.0
			G.minute = floor(G.minute / 1440.0) * 1440.0 + 20.0 * 60.0
			G.money = 3000
			G.force_call = true
	if args.has("cam"):
		await get_tree().create_timer(1.0).timeout
		if main.cam.focus_tween:
			main.cam.focus_tween.kill()
		var p: PackedStringArray = String(args.cam).split(",")
		main.cam.position = Vector3(float(p[0]), 0, float(p[1]))
		main.cam.zoom_target = float(p[2])
		main.cam.zoom = float(p[2])
		if p.size() > 3:
			main.cam.yaw_target = deg_to_rad(float(p[3]))
			main.cam.yaw = main.cam.yaw_target
		main._title_spin = false
	if args.has("help"):
		main.hud.show_help(int(args.help))
	if args.has("open"):
		await get_tree().create_timer(1.2).timeout
		match String(args.open):
			"changelog": main.hud.show_changelog()
			"market": main.hud.show_market()
			"expand": main.hud.show_expand()
			"settings": main.hud.show_settings()
			"menu": main.hud.toggle_menu()
	G.phone_call.connect(func(c):
		print("[test] 來電 ", c.client, " n=", c.n)
		if args.has("call"):
			await get_tree().create_timer(1.5).timeout
			main.hud.close_modal()
			if args.has("report"):
				c["reported"] = true
				c["advance"] = 0
			G.accept_mystery(c)
			G.set_speed(float(args.get("speed", "1")))
		if args.has("weather"):
			G.weather = {"kind": String(args.weather), "until": G.minute + 3000.0}
			G.weather_changed.emit()
		if args.has("contraband"):
			G.force_contraband = true
		if args.has("quake"):
			get_tree().create_timer(float(args.get("quakeat", "4"))).timeout.connect(func(): G.quake.emit(float(args.quake)))
		if args.has("cls"):
			G.force_cls = String(args.cls)
		if args.has("intl"):
			# 強制產生國際委託
			for i in int(args.intl):
				for k in 40:
					var o: Dictionary = G._make_offer()
					if o.intl != "" and (not args.has("ikind") or (o.transport == args.ikind and o.intl == "import")):
						o.arrive = G.minute + 30.0 + i * 60.0
						o.pickup = o.arrive + 300.0
						o.cross = true
						G.offers.append(o)
						break)

func _process(delta: float) -> void:
	t += delta
	if args.has("accept") and G.playing and not G.over:
		main.hud.close_modal() if main.hud.modal and not args.has("keepmodal") else null
		for o in G.offers.duplicate():
			if G.free_slots(o.cargo) >= int(o.n) or (args.has("force") and o.intl != ""):
				G.accept_offer(o)
	if args.has("cop") and G.playing:
		for v in main.world.vehicles:
			if is_instance_valid(v) and v.kind == "van" and v.state == "decide":
				v.is_cop = args.cop == "1"
				print("[test] 廂型車到了 cop=", v.is_cop)
				main.hud.close_modal()
				if args.has("report"):
					v.report_police()
				else:
					v.decide(true)
	if _shot_i < shots.size() and t >= float(shots[_shot_i]):
		var out := String(args.get("out", "user://"))
		var img := get_viewport().get_texture().get_image()
		var path := out.path_join("shot_%02d.png" % _shot_i)
		img.save_png(path)
		print("[test] shot ", path, "  第%d天 %s 資金 %s 委託 %d 簽約 %d 托盤 %d 車 %d 評價 %d" % [G.day(), G.clock_text(), G.fmt(G.money), G.offers.size(), G.contracts.size(), main.world.pallets.size(), main.world.vehicles.size(), int(G.rating)])
		_shot_i += 1
		if args.has("debug"):
			for f in main.world.forklifts:
				print("  fork ", f.cell(), " phase=", f.phase, " job=", not f.job.is_empty())
			for v in main.world.vehicles:
				if is_instance_valid(v):
					print("  veh ", v.kind, " ", v.mode, " st=", v.state, " left=", v.left, " tgt=", v.target, " got=", v.got, " stall=", int(v.stall), " cid=", v.cid)
			for d in main.world.docks:
				var pads := []
				for q in d.pad:
					pads.append(q.state + ":" + str(q.cid) if q else "-")
				print("  dock ", d.kind, d.cell, " pads=", pads, " res=", d.pad_res, " veh=", d.vehicle != null)
				for q in d.pad:
					if q:
						var fc: Vector2i = main.world.forklifts[0].cell()
						print("    find_slot from ", fc, " -> ", main.world._find_slot(q.cargo, fc), " claimed=", q.claimed)
			for r in main.world.racks:
				print("  rack ", r.kind, r.cell, " rot=", r.rot, " slots=", r.slots.map(func(x): return 0 if x == null else 1), " res=", r.reserved)
			for c in G.contracts:
				print("  c ", c.id, " ", c.client, " ", c.state, " n=", c.n, " un=", c.unloaded, " lo=", c.loaded, " ", c.get("tin"), "->", c.get("tout"), " cu=", c.customs.get("stage", "") if not c.customs.is_empty() else "")
	if args.has("quit") and t >= float(args.quit):
		print("[test] done 收入 ", G.stats.earned, " 搬運 ", G.stats.pallets, " 完成委託 ", G.stats.contracts, " over=", G.over)
		get_tree().quit()
