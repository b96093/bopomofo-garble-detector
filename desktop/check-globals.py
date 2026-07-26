# AHK 常見陷阱檢查：函式裡只要對變數有「指派」，該變數就會被當成區域變數，
# 除非明確寫 global 宣告。漏寫的話語法檢查不會報錯，要到執行時才爆。
# 用法：python desktop/check-globals.py
import io, re, sys, pathlib

FILES = ["app.ahk", "engine.ahk"]
base = pathlib.Path(__file__).parent

problems = []
for fname in FILES:
    path = base / fname
    if not path.exists():
        continue
    text = io.open(path, encoding="utf-8").read().lstrip("﻿")
    lines = text.split("\n")

    top_globals = set()
    for ln in lines:
        m = re.match(r"^global\s+(.+)", ln)
        if m:
            for part in m.group(1).split(","):
                name = part.split(":=")[0].strip()
                if re.match(r"^[A-Za-z_]\w*$", name):
                    top_globals.add(name)

    func_start = re.compile(r"^([A-Za-z_]\w*)\(.*\)\s*\{")
    i = 0
    while i < len(lines):
        m = func_start.match(lines[i])
        if not m:
            i += 1
            continue
        name, depth, body, j = m.group(1), 0, [], i
        while j < len(lines):
            depth += lines[j].count("{") - lines[j].count("}")
            body.append(lines[j])
            j += 1
            if depth <= 0 and j > i:
                break
        body_text = "\n".join(body)
        declared = set()
        for d in re.findall(r"^\s*global\s+([^\n;]+)", body_text, re.M):
            declared.update(v.split(":=")[0].strip() for v in d.split(","))
        for assigned in re.findall(r"^\s*([A-Za-z_]\w*)\s*(?::=|\.=|\+=|-=)", body_text, re.M):
            if assigned in top_globals and assigned not in declared:
                problems.append("%s: %s() 指派了全域 %s 但未宣告 global" % (fname, name, assigned))
        i = j

if problems:
    print("發現問題：")
    for p in dict.fromkeys(problems):
        print("  " + p)
    sys.exit(1)
print("OK：所有對全域變數的指派都有 global 宣告")
