# 小柯機器人物流大亨

小柯機器人系列遊戲。一款舒適的倉庫經營模擬：從一棟小倉庫和 $20,000 起家，接客戶委託、收貨上架、準時出貨，賺錢蓋貨架、買堆高機、買地擴建，最後讓卡車、火車、貨輪都把生意送到門口。缺錢時會有人打電話來請你「保管」不明貨箱——但每一台廂型車都可能是臥底警察開的。

**線上版：** https://achir1015.github.io/xiaoke-logistics/

## 特色

- 等角 3D 倉庫，放大看小柯機器人開著堆高機忙進忙出
- 一般貨架、冷藏櫃、易碎品籠架；收貨、存放、轉運、出貨
- 擴建：加開碼頭門、買隔壁的地、鋪鐵路支線、蓋港口（高架輸送帶）
- 不明貨箱與臥底警察：可觀察司機找破綻，被抓就失去一切
- 日夜變化、三首原創輕音樂、自動存檔
- 全繁體中文、內建遊戲說明、版本更新提示；電腦與手機（觸控）都能玩

## 開發

- 引擎：Godot 4.7.2（GL Compatibility），GDScript
- 建置線上版：`bash tools/build_web.sh` → `../build/logistics-web/`、`../build/xiaoke-logistics-web.zip`
- 語法檢查：`godot --headless --path . res://tools/check.tscn`
- 自動測試與截圖：`godot --path . -- --test --mode=new --speed=4 --accept --shots=5,30 --out=DIR --quit=32`
- 音樂與音效：`python -I tools/gen_audio.py`（程序合成，原創）

## 發佈新版本

1. 改 `scripts/g.gd` 的 `APP_VERSION`、`project.godot` 的 `config/version`、`docs/version.json`，並在 `scripts/texts.gd` 加更新紀錄
2. `bash tools/build_web.sh`，建立 Release 並上傳 `xiaoke-logistics-web.zip`
3. 推送 main（或手動執行「部署線上版到 GitHub Pages」）。玩家的遊戲會在 3 秒內偵測到新版並提示重新載入

## 素材與授權

- 程式：MIT（見 LICENSE）
- 卡車、廂型車、警車、樹木模型：[Kenney](https://kenney.nl) Car Kit／Nature Kit（CC0）
- 字型：Noto Sans TC（SIL OFL 1.1）
- 音樂與音效：原創程序合成
- 倉庫、貨架、堆高機、火車、貨輪：程式產生的原創低多邊形模型

開發者：吳玉柱 先生與 Claude AI Opus 5.5
