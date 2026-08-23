# -*- coding: utf-8 -*-
"""校验 data/game.json 里每一句正文都逐字出现在原书里。有一句对不上就非零退出。"""
import json, sys, zipfile, re, pathlib

EPUB = pathlib.Path.home() / "Downloads" / "百年孤独 (根据马尔克斯指定版本翻译,未做任何增删) (加西亚•马尔克斯, 范晔) (z-lib.org).epub"

def book_text():
    z = zipfile.ZipFile(EPUB)
    out = []
    for n in sorted(z.namelist()):
        if not n.endswith((".html", ".xhtml")):
            continue
        t = z.read(n).decode("utf-8", "ignore")
        t = re.sub(r"<(script|style)[^>]*>.*?</\1>", "", t, flags=re.S)
        t = re.sub(r"<[^>]+>", "\n", t)
        t = re.sub(r"&[a-z]+;", " ", t)
        out.append(re.sub(r"\s+", "", t))
    return "".join(out)

def walk(node, path="", hits=None):
    hits = hits if hits is not None else []
    if isinstance(node, dict):
        for k, v in node.items():
            if k in ("text", "quote") and isinstance(v, str) and v.strip():
                hits.append((path + "." + k, v))
            else:
                walk(v, path + "." + str(k), hits)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, path + "[%d]" % i, hits)
    return hits

raw = book_text()
data = json.loads(pathlib.Path("data/game.json").read_text(encoding="utf-8"))
bad = [(p, s) for p, s in walk(data) if s not in raw]
for p, s in bad:
    print("✗ 不是原文", p, "→", s)
n = len(walk(data))
print("✓ %d 句正文全部逐字来自原书" % n if not bad else "✗ %d/%d 句对不上" % (len(bad), n))
sys.exit(1 if bad else 0)
