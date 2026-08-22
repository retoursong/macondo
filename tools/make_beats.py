#!/usr/bin/env python3
"""把每个场景的原文改写成极简叙述（beats）。

原文留在 narration 里当事实底稿——喂给 AI、供人核对。
玩家看到的是 beats：一条 15~40 字，一条只说一件事。

跑：python3 tools/make_beats.py   （需要 ARK_API_KEY）
"""
import json, os, sys, time, urllib.request

URL = "https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions"
MODEL = "deepseek-v4-flash"

PROMPT = """下面是《百年孤独》第一章的一段原文。请改写成极简叙述，给一个非常抗拒读长文的玩家看。

要求：
1. 每条 15~40 字，一条只说一件事
2. 平实、具体、有画面。不要文绉绉，不要堆形容词，不要抒情
3. 只保留推动故事的信息：谁、做了什么、结果怎样
4. 绝不添加原文里没有的事实，也不要下结论或作评论
5. 人名照原文写全，第一次出现时用全名
6. 必须正好 {n} 条，一条一行。单条绝对不能超过 40 字——太长就拆成两条
7. 一条里只放一个动作或一个结果，不要用「，」串起好几件事

只输出这 {n} 行，每行一条，不要编号、不要引号、不要任何解释。

原文：
{text}"""


def ask(key, text, n):
    body = json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": PROMPT.format(n=n, text=text)}],
        "max_tokens": 800, "temperature": 0.6,
        "thinking": {"type": "disabled"},
    }).encode()
    req = urllib.request.Request(URL, data=body, headers={
        "Authorization": "Bearer " + key, "Content-Type": "application/json"})
    r = json.load(urllib.request.urlopen(req, timeout=120))
    out = r["choices"][0]["message"]["content"].strip()
    lines = []
    for ln in out.split("\n"):
        t = ln.strip().lstrip("0123456789.、)- ").strip()
        if len(t) >= 6:
            lines.append(t)
    return lines


def ok(lines, n):
    return len(lines) >= max(3, n - 1) and all(len(x) <= 42 for x in lines)


def ask_checked(key, text, n, tries=3):
    """不合格就重试。宁可多花几次，也别放长句进去。"""
    best = []
    for i in range(tries):
        got = ask(key, text, n)
        if ok(got, n):
            return got, i + 1
        if not best or len([x for x in got if len(x) <= 42]) > len([x for x in best if len(x) <= 42]):
            best = got
    return best, tries


def main():
    key = os.environ.get("ARK_API_KEY", "").strip()
    if not key and os.path.exists(".ark_key"):
        key = open(".ark_key").read().strip()
    if not key:
        sys.exit("没有 ARK_API_KEY")

    path = "data/scenes_ch01.json"
    d = json.load(open(path, encoding="utf-8"))
    for sc in d["scenes"]:
        text = "\n".join(sc["narration"])
        # 原文越长，beats 越多，但封顶 6 条
        n = max(3, min(6, len(text) // 200))
        t0 = time.time()
        sc["beats"], tries = ask_checked(key, text, n)
        mx = max((len(x) for x in sc["beats"]), default=0)
        flag = "" if ok(sc["beats"], n) else "  ⚠仍不达标"
        print(f"  {sc['id']} {sc['title']:<10} 原文{len(text):>5}字 → {len(sc['beats'])}条 "
              f"最长{mx}字 试{tries}次 ({time.time()-t0:.1f}s){flag}", file=sys.stderr)
        for b in sc["beats"]:
            print(f"      · {b}", file=sys.stderr)

    json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    total = sum(len("".join(s["beats"])) for s in d["scenes"])
    orig = sum(len("".join(s["narration"])) for s in d["scenes"])
    print(f"\n✓ 全章 {orig} 字 → {total} 字（压到 {total*100//orig}%）", file=sys.stderr)


main()
