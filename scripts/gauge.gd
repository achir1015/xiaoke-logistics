class_name Gauge
extends Control
## 半圓指針儀表（油價、物價指數）。

var title := ""
var value := 0.0
var vmin := 0.0
var vmax := 100.0
var change := 0.0
var text := ""

const A0 := PI * 0.85      # 左端
const A1 := PI * 2.15      # 右端（順時針）

func _init() -> void:
	custom_minimum_size = Vector2(102, 86)
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_data(v: float, ch: float, t: String) -> void:
	value = v
	change = ch
	text = t
	queue_redraw()

func _draw() -> void:
	var f: Font = M.font_ui if M.font_ui else get_theme_default_font()
	var fb: Font = M.font_bold if M.font_bold else f
	var w := size.x
	var c := Vector2(w / 2.0, 54.0)
	var r := 36.0
	# 色帶：綠 → 黃 → 紅
	var segs := 24
	for i in segs:
		var a := lerpf(A0, A1, float(i) / segs)
		var b := lerpf(A0, A1, float(i + 1) / segs)
		var t := float(i) / (segs - 1)
		var col := Color(0.3, 0.8, 0.45).lerp(Color(1.0, 0.8, 0.25), clampf(t * 2.0, 0.0, 1.0)).lerp(Color(0.95, 0.3, 0.25), clampf(t * 2.0 - 1.0, 0.0, 1.0))
		draw_arc(c, r, a, b + 0.01, 4, col, 7.0, true)
	# 刻度
	for i in 6:
		var a := lerpf(A0, A1, i / 5.0)
		draw_line(c + Vector2(cos(a), sin(a)) * (r - 9), c + Vector2(cos(a), sin(a)) * (r - 4), Color(1, 1, 1, 0.5), 1.5)
	# 指針
	var tt := clampf((value - vmin) / (vmax - vmin), 0.0, 1.0)
	var ang := lerpf(A0, A1, tt)
	var tip := c + Vector2(cos(ang), sin(ang)) * (r - 6)
	draw_line(c, tip, Color(1, 1, 1), 2.5, true)
	draw_circle(c, 4.5, Color(0.95, 0.95, 0.95))
	draw_circle(c, 2.0, Color(0.2, 0.22, 0.28))
	# 文字
	draw_string(f, Vector2(0, 12), title, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.75, 0.8, 0.88))
	draw_string(fb, Vector2(0, 74), text, HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(1, 1, 1))
	var up := change >= 0.0
	var ct := "%s %.1f%%" % ["▲" if up else "▼", absf(change)]
	draw_string(f, Vector2(0, 86), ct, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(1.0, 0.5, 0.45) if up else Color(0.45, 0.9, 0.55))
