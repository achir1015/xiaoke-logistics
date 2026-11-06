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
		if args.has("call"):
			G.last_call_min = -99999.0
			G.minute = floor(G.minute / 1440.0) * 1440.0 + 20.0 * 60.0
			G.money = 3000
			G.force_call = true
	if args.has("cam"):
		var p: PackedStringArray = String(args.cam).split(",")
		main.cam.position = Vector3(float(p[0]), 0, float(p[1]))
		main.cam.zoom_target = float(p[2])
		main.cam.zoom = float(p[2])
		main._title_spin = false
	if args.has("help"):
		main.hud.show_help(int(args.help))
	G.phone_call.connect(func(c):
		print("[test] 來電 ", c.client, " n=", c.n)
		if args.has("call"):
			await get_tree().create_timer(1.5).timeout
			main.hud.close_modal()
			G.accept_mystery(c)
			G.set_speed(float(args.get("speed", "1"))))

func _process(delta: float) -> void:
	t += delta
	if args.has("accept") and G.playing and not G.over:
		main.hud.close_modal() if main.hud.modal and not args.has("keepmodal") else null
		for o in G.offers.duplicate():
			if G.free_slots(o.cargo) >= int(o.n):
				G.accept_offer(o)
	if args.has("cop") and G.playing:
		for v in main.world.vehicles:
			if is_instance_valid(v) and v.kind == "van" and v.state == "decide":
				v.is_cop = args.cop == "1"
				print("[test] 廂型車到了 cop=", v.is_cop)
				main.hud.close_modal()
				v.decide(true)
	if _shot_i < shots.size() and t >= float(shots[_shot_i]):
		var out := String(args.get("out", "user://"))
		var img := get_viewport().get_texture().get_image()
		var path := out.path_join("shot_%02d.png" % _shot_i)
		img.save_png(path)
		print("[test] shot ", path, "  第%d天 %s 資金 %s 委託 %d 簽約 %d 托盤 %d 車 %d 評價 %d" % [G.day(), G.clock_text(), G.fmt(G.money), G.offers.size(), G.contracts.size(), main.world.pallets.size(), main.world.vehicles.size(), int(G.rating)])
		_shot_i += 1
	if args.has("quit") and t >= float(args.quit):
		print("[test] done 收入 ", G.stats.earned, " 搬運 ", G.stats.pallets, " 完成委託 ", G.stats.contracts, " over=", G.over)
		get_tree().quit()
