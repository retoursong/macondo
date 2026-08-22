#!/usr/bin/env python3
"""把《百年孤独》epub 的一章切成场景序列。

原文一个字都不改，只做三件事：滤译注、接断句、切场景。

场景用【锚句】定位，不用下标——下标会随清理逻辑漂移，锚句不会。
每个场景从自己的锚句所在段开始，到下一个锚句所在段的前一段为止，
因此天然做到全覆盖、无重叠（脚本会自检）。
"""
import re, json, sys, zipfile

FOOTNOTE = re.compile(r'^[①②③④⑤⑥⑦⑧⑨⑩]')
# 句末：终止标点之后可以跟收尾引号；单独一个引号（如“哲学之卵”）不算句末
SENT_END = re.compile(r'[。！？…]["”」』）]*$')


def load_paragraphs(epub_path, part):
    with zipfile.ZipFile(epub_path) as z:
        raw = z.read(f'text/{part}').decode('utf-8', 'ignore')
    t = re.sub(r'<(script|style)[^>]*>.*?</\1>', '', raw, flags=re.S)
    t = re.sub(r'<[^>]+>', '\n', t)
    t = re.sub(r'&[a-z]+;', ' ', t)
    return [re.sub(r'\s+', '', p) for p in t.split('\n') if len(re.sub(r'\s+', '', p)) > 40]


def clean(paras):
    """滤译注，并把被译注截断的半句接回去。返回 (正文段, 每段对应的原始下标)。"""
    kept = [(i, p) for i, p in enumerate(paras) if not FOOTNOTE.match(p)]
    body, src = [], []
    for i, p in kept:
        if body and not SENT_END.search(body[-1]):
            body[-1] += p
            src[-1].append(i)
        else:
            body.append(p)
            src.append([i])
    return body, src


# (锚句, 类型, 标题, 地点, 在场角色)   type: scene=可对话 / inter=过场
# 锚句必须是该场景第一段开头的一段独一无二的原文。
SCENES_CH01 = [
    ("多年以后，面对行刑队", "scene", "磁铁", "马孔多·村中",
     ["何塞·阿尔卡蒂奥·布恩迪亚", "梅尔基亚德斯"]),
    ("三月里，吉卜赛人又来了", "scene", "地球是圆的", "马孔多·小屋",
     ["何塞·阿尔卡蒂奥·布恩迪亚", "乌尔苏拉", "梅尔基亚德斯"]),
    ("那一时期，梅尔基亚德斯在以惊人的速度衰老", "scene", "梅尔基亚德斯的秘密", "马孔多·实验室",
     ["何塞·阿尔卡蒂奥·布恩迪亚", "梅尔基亚德斯", "乌尔苏拉"]),
    ("那间简陋的实验室", "scene", "熔掉的金子", "马孔多·实验室",
     ["何塞·阿尔卡蒂奥·布恩迪亚", "乌尔苏拉"]),
    ("当吉卜赛人再来的时候", "scene", "返老还童", "马孔多·集市",
     ["何塞·阿尔卡蒂奥·布恩迪亚", "梅尔基亚德斯"]),
    ("当初何塞·阿尔卡蒂奥·布恩迪亚是那种年轻的族长式人物", "inter", "马孔多的黄金岁月", "马孔多", []),
    ("何塞·阿尔卡蒂奥·布恩迪亚当初建功立业的雄心", "scene", "远征的决心", "马孔多·家中",
     ["何塞·阿尔卡蒂奥·布恩迪亚"]),
    ("最初几日，没有遇到什么值得一提的阻碍", "inter", "大帆船与大海", "沼泽·丛林深处", []),
    ("很长时间内，马孔多处在一个半岛上", "scene", "乌尔苏拉的拒绝", "马孔多·家中",
     ["何塞·阿尔卡蒂奥·布恩迪亚", "乌尔苏拉"]),
    ("大儿子何塞·阿尔卡蒂奥已经十四岁", "scene", "两个儿子", "马孔多·家中",
     ["何塞·阿尔卡蒂奥·布恩迪亚", "乌尔苏拉", "何塞·阿尔卡蒂奥", "奥雷里亚诺"]),
    ("然而自从那个下午叫孩子们帮忙取出实验器具", "scene", "冰块", "集市·冰的帐篷",
     ["何塞·阿尔卡蒂奥·布恩迪亚", "何塞·阿尔卡蒂奥", "奥雷里亚诺"]),
]


def locate(body, anchor):
    hits = [i for i, p in enumerate(body) if p.startswith(anchor)]
    if len(hits) != 1:
        raise SystemExit(f"锚句定位失败（命中 {len(hits)} 次）：{anchor!r}")
    return hits[0]


def build(body, src, table, chapter):
    starts = [locate(body, a[0]) for a in table]
    if starts != sorted(starts):
        raise SystemExit(f"锚句顺序与原文不符：{starts}")
    if starts[0] != 0:
        raise SystemExit(f"第一个锚句不在开头（在第 {starts[0]} 段）")

    scenes = []
    for n, ((anchor, kind, title, place, cast), a) in enumerate(zip(table, starts), 1):
        b = starts[n] - 1 if n < len(starts) else len(body) - 1
        scenes.append({
            "id": f"ch{chapter:02d}_s{n:02d}",
            "chapter": chapter,
            "type": kind,
            "title": title,
            "place": place,
            "cast": cast,
            "narration": body[a:b + 1],
            "source": {"anchor": anchor, "body_paras": [a, b],
                       "raw_paras": sorted(sum(src[a:b + 1], []))},
        })
    return scenes


def main():
    epub = sys.argv[1]
    paras = load_paragraphs(epub, 'part0003.html')
    body, src = clean(paras)
    scenes = build(body, src, SCENES_CH01, 1)

    # 自检：必须全覆盖、无重叠
    covered = []
    for s in scenes:
        a, b = s["source"]["body_paras"]
        covered += list(range(a, b + 1))
    assert covered == list(range(len(body))), f"覆盖不完整或有重叠: {covered}"

    out = {"book": "百年孤独", "translator": "范晔", "chapter": 1,
           "source_file": epub.split("/")[-1], "scenes": scenes}
    with open('data/scenes_ch01.json', 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    talk = sum(1 for s in scenes if s["type"] == "scene")
    total = sum(len(''.join(s["narration"])) for s in scenes)
    print(f"原文 {len(paras)} 段 → 滤译注接断句 {len(body)} 段 → {len(scenes)} 个单元", file=sys.stderr)
    print(f"✓ 全覆盖无重叠 | {talk} 可对话 + {len(scenes)-talk} 过场 | 正文 {total} 字\n", file=sys.stderr)
    for s in scenes:
        mark = "💬" if s["type"] == "scene" else "▸ "
        cast = "、".join(c.split("·")[0] for c in s["cast"]) or "—"
        print(f"{mark} {s['id']}  {s['title']:<10}{len(''.join(s['narration'])):>5}字  "
              f"{s['place']:<14} {cast}", file=sys.stderr)


main()
