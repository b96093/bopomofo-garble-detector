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
        # AHK 變數名不分大小寫：st 就是 ST，比對時必須忽略大小寫
        lower_globals = {g.lower(): g for g in top_globals}
        lower_declared = {d.lower() for d in declared}
        for assigned in re.findall(r"^\s*([A-Za-z_]\w*)\s*(?::=|\.=|\+=|-=)", body_text, re.M):
            g = lower_globals.get(assigned.lower())
            if not g:
                continue
            if assigned != g:
                # 大小寫不同卻是同一個變數 —— 幾乎都是誤以為兩者無關而寫錯
                problems.append("%s: %s() 寫了 %s，但那其實就是全域 %s（AHK 不分大小寫）"
                                % (fname, name, assigned, g))
            elif assigned.lower() not in lower_declared:
                problems.append("%s: %s() 指派了全域 %s 但未宣告 global" % (fname, name, assigned))
        # 函式參數同樣會建立區域變數，撞名一樣會遮蔽全域
        params = re.match(r"^[A-Za-z_]\w*\(([^)]*)\)", body_text)
        if params:
            for prm in params.group(1).split(","):
                pname = prm.split(":=")[0].replace("&", "").strip()
                g = lower_globals.get(pname.lower())
                if g:
                    problems.append("%s: %s() 的參數 %s 會遮蔽全域 %s" % (fname, name, pname, g))
        # ByRef 輸出變數（&name）同樣會建立區域變數；AHK 變數名不分大小寫，
        # 所以 &sT 這種寫法會撞到全域的 ST，且語法檢查抓不到。
        # (?<!&)&(?!&) 排除 && 邏輯運算子，只抓真正的 ByRef 輸出變數
        for out in re.findall(r"(?<![&\w])&(?!&)\s*([A-Za-z_]\w*)", body_text):
            for g in top_globals:
                if out.lower() == g.lower() and g not in declared:
                    problems.append("%s: %s() 用 &%s 當輸出變數，會撞到全域 %s（AHK 不分大小寫）"
                                    % (fname, name, out, g))
        i = j

if problems:
    print("發現問題：")
    for p in dict.fromkeys(problems):
        print("  " + p)
    sys.exit(1)
print("OK：所有對全域變數的指派都有 global 宣告")
