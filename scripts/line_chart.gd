class_name LineChart
extends Control
## 簡單折線圖（市場行情走勢）。

var data: Array = []
var color := Color(1.0, 0.72, 0.22)
var fmt := "%.1f"

func _init() -> void:
	custom_minimum_size = Vector2(240, 120)

func set_data(d: Array, c: Color, f: String) -> void:
	data = d
	color = c
	fmt = f
	queue_redraw()

func _draw() -> void:
	var f: Font = M.font_ui if M.font_ui else get_theme_default_font()
	var r := Rect2(Vector2(40, 8), size - Vector2(48, 28))
	draw_rect(r, Color(1, 1, 1, 0.05))
	if data.size() < 2:
		return
	var lo := 1e9
	var hi := -1e9
	for v in data:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	if hi - lo < 0.001:
		hi += 1.0
		lo -= 1.0
	var pad := (hi - lo) * 0.1
	lo -= pad
	hi += pad
	for k in 3:
		var y := r.position.y + r.size.y * k / 2.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.1), 1.0)
		var val := hi - (hi - lo) * k / 2.0
		draw_string(f, Vector2(0, y + 5), fmt % val, HORIZONTAL_ALIGNMENT_RIGHT, 36, 11, Color(0.7, 0.75, 0.82))
	var pts := PackedVector2Array()
	for i in data.size():
		var x := r.position.x + r.size.x * i / float(data.size() - 1)
		var y2 := r.end.y - (float(data[i]) - lo) / (hi - lo) * r.size.y
		pts.append(Vector2(x, y2))
	var fill := pts.duplicate()
	fill.append(Vector2(r.end.x, r.end.y))
	fill.append(Vector2(r.position.x, r.end.y))
	draw_colored_polygon(fill, Color(color.r, color.g, color.b, 0.15))
	draw_polyline(pts, color, 2.0, true)
	draw_circle(pts[pts.size() - 1], 3.5, color)
	draw_string(f, Vector2(r.position.x, size.y - 4), "%d 天前" % (data.size() - 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.65, 0.72))
	draw_string(f, Vector2(r.end.x - 30, size.y - 4), "今天", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.65, 0.72))
