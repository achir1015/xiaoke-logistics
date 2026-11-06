"""產生遊戲說明的語音（台灣華語神經語音，edge-tts）。

用法：python -I tools/gen_voice.py
讀 scripts/texts.gd 的 HELP 與 WELCOME_VOICE，輸出 assets/voice/help_NN.ogg、welcome.ogg。
需要 edge-tts（pip install edge-tts）與 ffmpeg。
"""
import asyncio
import os
import re
import subprocess
import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "voice")
VOICE = "zh-TW-HsiaoChenNeural"

# 文字轉成適合朗讀的句子
REPL = [
    ("WASD／方向鍵", "W A S D 或方向鍵"), ("＋／－", "加號減號鍵"), ("Q／E", "Q 和 E 鍵"),
    ("1／2／3：1×／2×／4× 速度", "數字 1、2、3：切換一倍、兩倍、四倍速度"), ("Esc／右鍵", "Esc 或右鍵"),
    ("R：", "R 鍵："), ("1×", "一倍"), ("2×", "兩倍"), ("4×", "四倍"),
    ("B/L", "B L"), ("AWB", "A W B"), ("00:00", "半夜十二點"),
    ("一般／冷藏／易碎", "一般、冷藏、易碎"), ("Chrome／Edge", "Chrome 或 Edge"), ("開門收貨／交貨", "開門收貨或交貨"),
    ("／", "、"), ("～", "到"), ("→", "，再點"), ("•", ""), ("　", "，"),
]


def clean(t: str) -> str:
    t = t.replace("\\n", "\n")
    for a, b in REPL:
        t = t.replace(a, b)
    t = re.sub(r"\$([\d,]+)", lambda m: m.group(1).replace(",", "") + " 元", t)
    lines = [ln.strip() for ln in t.split("\n")]
    out = []
    for ln in lines:
        if not ln:
            continue
        if not re.search(r"[。！？：；，、]$", ln):
            ln += "。"
        out.append(ln)
    return "".join(out)


def parse():
    src = open(os.path.join(ROOT, "scripts", "texts.gd"), encoding="utf8").read()
    help_block = src[src.index("const HELP"):src.index("const WELCOME_VOICE")]
    pages = re.findall(r'\["([^"]+)", "((?:[^"\\]|\\.)*)"\]', help_block)
    welcome = re.search(r'const WELCOME_VOICE := "((?:[^"\\]|\\.)*)"', src).group(1)
    return pages, welcome


async def speak(text: str, name: str):
    mp3 = os.path.join(OUT, name + ".mp3")
    ogg = os.path.join(OUT, name + ".ogg")
    await edge_tts.Communicate(text, VOICE, rate="+0%").save(mp3)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", mp3, "-ac", "1", "-ar", "24000", "-c:a", "libvorbis", "-q:a", "2", ogg], check=True)
    os.remove(mp3)
    print(name, len(text), "字")


async def main():
    os.makedirs(OUT, exist_ok=True)
    pages, welcome = parse()
    for i, (title, body) in enumerate(pages):
        await speak(title + "。" + clean(body), "help_%02d" % i)
    await speak(clean(welcome), "welcome")


if __name__ == "__main__":
    asyncio.run(main())
