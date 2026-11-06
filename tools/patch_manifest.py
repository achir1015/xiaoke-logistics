"""建置後補強 PWA manifest：加 192 圖示、短名稱、id（Chrome 安裝條件）。"""
import json, shutil, sys, os
out = sys.argv[1]
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
shutil.copy(os.path.join(root, "platform", "icon_192.png"), os.path.join(out, "index.192x192.png"))
p = os.path.join(out, "index.manifest.json")
m = json.load(open(p, encoding="utf8"))
m["short_name"] = "小柯物流大亨"
m["id"] = "./"
m["scope"] = "./"
m["lang"] = "zh-Hant-TW"
m["theme_color"] = "#161c29"
m["description"] = "小柯機器人系列：舒適的倉庫經營模擬，從小倉庫做到物流帝國。"
icons = [i for i in m["icons"] if i["sizes"] != "192x192"]
icons.append({"sizes": "192x192", "src": "index.192x192.png", "type": "image/png"})
for i in icons:
    i["purpose"] = "any"
m["icons"] = sorted(icons, key=lambda i: int(i["sizes"].split("x")[0]))
json.dump(m, open(p, "w", encoding="utf8"), ensure_ascii=False)
print("manifest ok", [i["sizes"] for i in m["icons"]])
