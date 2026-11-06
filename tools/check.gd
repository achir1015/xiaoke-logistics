extends Node

# 載入所有腳本檢查語法：godot --headless res://tools/check.tscn

func _scan(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), out)

func _ready() -> void:
	var files: Array = []
	_scan("res://scripts", files)
	var bad := 0
	for f in files:
		var s: GDScript = load(f)
		if s == null or not s.can_instantiate():
			print("FAIL ", f)
			bad += 1
	print("CHECK done, failures=", bad)
	get_tree().quit(bad)
