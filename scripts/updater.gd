extends Node
## 版本更新：讀取網站上的 version.json，有新版就提示（線上版按一下重新載入）。

signal update_available(version: String, notes: String)

const SITE := "https://achir1015.github.io/xiaoke-logistics/"
var latest := ""
var notes := ""
var http: HTTPRequest

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	http = HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(_done)
	if OS.has_feature("editor") or "--no-update" in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(3.0).timeout
	check()
	var t := Timer.new()
	t.wait_time = 1800.0
	t.autostart = true
	t.timeout.connect(check)
	add_child(t)

func _base() -> String:
	if OS.has_feature("web"):
		var href = JavaScriptBridge.eval("location.href.split('?')[0].split('#')[0]", true)
		if typeof(href) == TYPE_STRING and String(href).begins_with("http"):
			var s := String(href)
			return s.substr(0, s.rfind("/") + 1)
	return SITE

func check() -> void:
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url := _base() + "version.json?t=%d" % Time.get_unix_time_from_system()
	http.request(url)

func _done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY or not d.has("version"):
		return
	var v := String(d.version)
	if newer(v, G.APP_VERSION):
		latest = v
		notes = String(d.get("notes", ""))
		update_available.emit(latest, notes)

# ── 建立捷徑（安裝到桌面／主畫面）──
func install_state() -> String:
	if not OS.has_feature("web"):
		return "desktop"
	var r = JavaScriptBridge.eval("(function(){var sa=(window.matchMedia&&window.matchMedia('(display-mode: standalone)').matches)||navigator.standalone===true;if(sa||window.__xkInstalled)return 'installed';if(window.__xkInstall)return 'prompt';var ua=navigator.userAgent;var ios=/iPhone|iPad|iPod/.test(ua)||(/Macintosh/.test(ua)&&'ontouchend' in document);if(ios)return 'ios';if(/Android/.test(ua))return 'android';return 'manual';})()", true)
	return String(r) if typeof(r) == TYPE_STRING else "manual"

func install_prompt() -> void:
	JavaScriptBridge.eval("if(window.__xkInstall){window.__xkInstall.prompt();window.__xkInstall.userChoice.finally(function(){window.__xkInstall=null;});}", true)

static func newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false

func apply() -> void:
	G.save_game()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(async()=>{try{if(navigator.serviceWorker){const rs=await navigator.serviceWorker.getRegistrations();await Promise.all(rs.map(r=>r.unregister()));}if(window.caches){const ks=await caches.keys();await Promise.all(ks.map(k=>caches.delete(k)));}}catch(e){}location.reload();})()", true)
	else:
		OS.shell_open(SITE)
