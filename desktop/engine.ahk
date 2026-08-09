#Requires AutoHotkey v2.0
; 注音亂碼引擎（由 Chrome 版 src/engine 移植，行為需與 JS 版一致）
; 對照來源：layout.js / convert.js / detect.js
#Include english.ahk

; ---------- 大千鍵盤佈局 ----------
global LAYOUT := Map(
    "1","ㄅ", "q","ㄆ", "a","ㄇ", "z","ㄈ",
    "2","ㄉ", "w","ㄊ", "s","ㄋ", "x","ㄌ",
    "e","ㄍ", "d","ㄎ", "c","ㄏ",
    "r","ㄐ", "f","ㄑ", "v","ㄒ",
    "5","ㄓ", "t","ㄔ", "g","ㄕ", "b","ㄖ",
    "y","ㄗ", "h","ㄘ", "n","ㄙ",
    "u","ㄧ", "j","ㄨ", "m","ㄩ",
    "8","ㄚ", "i","ㄛ", "k","ㄜ", ",","ㄝ",
    "9","ㄞ", "o","ㄟ", "l","ㄠ", ".","ㄡ",
    "0","ㄢ", "p","ㄣ", ";","ㄤ", "/","ㄥ",
    "-","ㄦ")
global TONE_KEYS  := Map(" ",1, "6",2, "3",3, "4",4, "7",5)
global TONE_MARKS := Map(1,"", 2,"ˊ", 3,"ˇ", 4,"ˋ", 5,"˙")
; 使用者自己打的標點（非大千鍵）：原樣保留不轉換
global PUNCT := "?!:" . Chr(34) . "'()、，。？！；：「」『』（）〈〉《》【】…—～·"

; ---------- 詞庫 ----------
LoadDict(path) {
    dict := Map()
    raw := FileRead(path, "UTF-8")
    Loop Parse raw, "`n", "`r"
    {
        if (A_LoopField == "")
            continue
        p := InStr(A_LoopField, "`t")
        if (p)
            dict[SubStr(A_LoopField, 1, p - 1)] := SubStr(A_LoopField, p + 1)
    }
    return dict
}

global ENTRY_CACHE := Map()
; 取某讀音的候選：[[詞, 詞頻], ...]，查無回 ""
DictEntry(dict, key) {
    if ENTRY_CACHE.Has(key)
        return ENTRY_CACHE[key]
    if !dict.Has(key) {
        ENTRY_CACHE[key] := ""
        return ""
    }
    parts := StrSplit(dict[key], " ")
    out := []
    i := 1
    while (i < parts.Length) {
        out.Push([parts[i], Integer(parts[i + 1])])
        i += 2
    }
    ENTRY_CACHE[key] := out
    return out
}

; ---------- 鍵位 → token ----------
; token：{t:"syl", v:音節} 或 {t:"lit", v:原樣字元}，另含來源範圍 start/end
; 聲調鍵（空白/3/4/6/7）前面若無待標調注音，視為使用者要打的數字或空格
KeysToTokens(input, forced := "") {
    tokens := []
    lower := StrLower(input)
    current := "", start := 1
    n := StrLen(lower)
    Loop Parse lower
    {
        i := A_Index, ch := A_LoopField
        isForced := (forced != "" && forced.Has(i))
        if (!isForced && TONE_KEYS.Has(ch)) {
            if (current != "") {
                tokens.Push({t:"syl", v: current . TONE_MARKS[TONE_KEYS[ch]], start: start, end: i + 1})
                current := ""
            } else {
                tokens.Push({t:"lit", v: SubStr(input, i, 1), start: i, end: i + 1})
            }
            continue
        }
        if (!isForced && LAYOUT.Has(ch)) {
            if (current == "")
                start := i
            current .= LAYOUT[ch]
            continue
        }
        if (current != "") {
            tokens.Push({t:"syl", v: current, start: start, end: i})
            current := ""
        }
        tokens.Push({t:"lit", v: SubStr(input, i, 1), start: i, end: i + 1})
    }
    if (current != "")
        tokens.Push({t:"syl", v: current, start: start, end: n + 1})
    return tokens
}

KeysToZhuyin(input) {
    out := []
    for tk in KeysToTokens(input)
        if (tk.t == "syl")
            out.Push(tk.v)
    return out
}

; ---------- 斷詞與候選 ----------
Segment(syls, dict) {
    segs := [], i := 1, n := syls.Length
    while (i <= n) {
        matched := false
        len := Min(4, n - i + 1)
        while (len >= 1) {
            key := ""
            Loop len
                key .= (A_Index > 1 ? " " : "") . syls[i + A_Index - 1]
            entry := DictEntry(dict, key)
            if (entry != "" && entry.Length) {
                segs.Push(entry)
                i += len
                matched := true
                break
            }
            len--
        }
        if (!matched) {
            segs.Push([[syls[i], 0]])
            i++
        }
    }
    return segs
}

ConvertCandidates(syls, dict, n := 3) {
    segs := Segment(syls, dict)
    best := ""
    for s in segs
        best .= s[1][1]

    swaps := []
    for idx, s in segs {
        if (s.Length >= 2) {
            gap := s[1][2] - s[2][2]
            variant := ""
            for j, t in segs
                variant .= (j == idx ? t[2][1] : t[1][1])
            swaps.Push([gap, variant])
        }
    }
    ; 依詞頻差距升冪（插入排序，資料量小）
    k := 2
    while (k <= swaps.Length) {
        cur := swaps[k], j := k - 1
        while (j >= 1 && swaps[j][1] > cur[1]) {
            swaps[j + 1] := swaps[j]
            j--
        }
        swaps[j + 1] := cur
        k++
    }

    result := [best]
    for sw in swaps {
        if (result.Length >= n)
            break
        dup := false
        for r in result
            if (r == sw[2]) {
                dup := true
                break
            }
        if (!dup)
            result.Push(sw[2])
    }
    return result
}

; ---------- 三道關卡 ----------
IsDigitChar(ch) {
    c := Ord(ch)
    return c >= 0x30 && c <= 0x39
}

IsRunChar(ch) {
    if (InStr(PUNCT, ch, true))
        return true
    c := Ord(ch)
    if (c >= 0x61 && c <= 0x7A)      ; a-z
        return true
    if (c >= 0x41 && c <= 0x5A)      ; A-Z
        return true
    if (c >= 0x30 && c <= 0x39)      ; 0-9
        return true
    ; 註：分號必須緊接在引號後，否則 AHK 會把「空格+分號」當成註解開頭
    return InStr(";/.,- ", ch, true) > 0
}

; 瀏覽器在 contenteditable（FB 留言框、Gmail 編輯區等）裡會把空白存成不斷行空白
; U+00A0，否則 HTML 會把尾端空白折疊掉；複製出來的純文字也是 U+00A0。
; 但使用者按的就是空白鍵 —— 大千佈局裡那是一聲的聲調鍵，不是斷詞用的空格。
; 讀進來時先還原，IsRunChar 才不會把它當成邊界。打字路徑收到的是真實按鍵，不受影響。
NormalizeTyped(s) {
    return StrReplace(s, Chr(0xA0), " ")
}

HanRatio(s) {
    if (s == "")
        return 0
    total := 0, han := 0
    Loop Parse s
    {
        total++
        c := Ord(A_LoopField)
        if ((c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF))
            han++
    }
    return han / total
}

; 注音音節的固定結構：聲母 → 介音 → 韻母 → 聲調，每類最多一個
global INITIALS := "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ"
global MEDIALS := "ㄧㄨㄩ"
global FINALS := "ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ"
global TONE_CHARS := "ˊˇˋ˙"

; 把打亂順序的注音依結構歸位（ㄐㄣㄧ → ㄐㄧㄣ），這正是注音輸入法本身的行為。
; 每類出現兩個（如兩個聲母）就不可能是打反，回 "" 不硬湊。
CanonSyllable(syl) {
    i := "", m := "", f := "", t := ""
    Loop Parse syl
    {
        ch := A_LoopField
        if (InStr(INITIALS, ch, true)) {
            if (i != "")
                return ""
            i := ch
        } else if (InStr(MEDIALS, ch, true)) {
            if (m != "")
                return ""
            m := ch
        } else if (InStr(FINALS, ch, true)) {
            if (f != "")
                return ""
            f := ch
        } else if (InStr(TONE_CHARS, ch, true)) {
            if (t != "")
                return ""
            t := ch
        } else {
            return ""
        }
    }
    out := i . m . f . t
    return (out == syl) ? "" : out      ; 順序本來就對就不必重試
}

; 音節查無且含數字時，把數字改判為字面數字後重試（如 2天 → ㄉㄊㄧㄢ 不合法）
TokenizeResolving(input, dict) {
    forced := Map()
    Loop 7 {
        tokens := KeysToTokens(input, forced)
        ; 先把打反順序的音節歸位（相鄰鍵打反是最常見的失誤）
        for tk in tokens {
            if (tk.t == "syl" && !dict.Has(tk.v)) {
                c := CanonSyllable(tk.v)
                if (c != "" && dict.Has(c))
                    tk.v := c
            }
        }
        bad := ""
        for tk in tokens {
            if (tk.t == "syl" && !dict.Has(tk.v)) {
                bad := tk
                break
            }
        }
        if (bad == "")
            return tokens
        adjusted := false
        k := bad.start
        while (k < bad.end) {
            ch := SubStr(input, k, 1)
            if (IsDigitChar(ch) && !forced.Has(k)) {
                forced[k] := true
                adjusted := true
                break
            }
            k++
        }
        if (!adjusted)
            return tokens
    }
    return KeysToTokens(input, forced)
}

; 回傳 {candidates: [...], confidence: n, syllables: [...]} 或 ""（非亂碼）
; syllables 與 candidates[1] 的每個字一一對應；標點／數字為 ""
Detect(input, dict, threshold := 0.8, minSyllables := 2, manual := false) {
    if (input == "")
        return ""
    Loop Parse input
        if !IsRunChar(A_LoopField)
            return ""
    if (!manual && IsCommonEnglish(Trim(StrLower(input))))
        return ""

    ; 電話、日期、金額、證號都是純數字，但數字鍵在注音鍵盤上也有意義
    ;（0=ㄢ、9=ㄞ、5=ㄓ、8=ㄚ…），所以會拼出合法音節而誤判。
    ; 正常打注音幾乎一定會用到字母鍵（聲母都在字母上），故自動偵測要求至少一個字母。
    if (!manual) {
        hasLetter := false
        Loop Parse input {
            c := Ord(A_LoopField)
            if ((c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A)) {
                hasLetter := true
                break
            }
        }
        if (!hasLetter)
            return ""
    }

    tokens := TokenizeResolving(input, dict)
    ; 串成「音節段 / 原樣段」交替
    pieces := []
    for tk in tokens {
        if (tk.t == "lit") {
            pieces.Push({lit: tk.v})
        } else {
            last := pieces.Length ? pieces[pieces.Length] : ""
            if (last != "" && last.HasOwnProp("syls"))
                last.syls.Push(tk.v)
            else
                pieces.Push({syls: [tk.v]})
        }
    }

    sylPieces := []
    for p in pieces
        if p.HasOwnProp("syls")
            sylPieces.Push(p)
    if (!sylPieces.Length)
        return ""

    total := 0
    for p in sylPieces {
        for s in p.syls
            if !dict.Has(s)
                return ""
        total += p.syls.Length
    }
    if (total < minSyllables)
        return ""

    cands := []
    for p in sylPieces
        cands.Push(ConvertCandidates(p.syls, dict, 3))

    converted := ""
    for c in cands
        converted .= c[1]
    ratio := HanRatio(converted)
    if (ratio < threshold)
        return ""

    candidates := [Assemble(pieces, sylPieces, cands, 0, "")]
    i := 1
    while (i <= sylPieces.Length && candidates.Length < 3) {
        if (cands[i].Length >= 2) {
            s := Assemble(pieces, sylPieces, cands, i, cands[i][2])
            dup := false
            for c in candidates
                if (c == s) {
                    dup := true
                    break
                }
            if (!dup)
                candidates.Push(s)
        }
        i++
    }

    syllables := []
    for p in pieces {
        if p.HasOwnProp("lit") {
            Loop Parse p.lit
                syllables.Push("")
        } else {
            for s in p.syls
                syllables.Push(s)
        }
    }
    return {candidates: candidates, confidence: ratio, syllables: syllables}
}

Assemble(pieces, sylPieces, cands, swapAt, text) {
    out := ""
    for p in pieces {
        if p.HasOwnProp("lit") {
            out .= p.lit
            continue
        }
        idx := 0
        for j, sp in sylPieces
            if (sp == p) {
                idx := j
                break
            }
        out .= (idx == swapAt ? text : cands[idx][1])
    }
    return out
}

; 整段判不出來時，逐個丟掉開頭的字串再試，取最長的可辨識尾段
; 回傳 {res: ..., offset: 0-based 位移} 或 ""
DetectTail(input, dict, threshold := 0.8, minSyllables := 2) {
    offset := 0
    Loop 9 {
        text := SubStr(input, offset + 1)
        if (Trim(text) == "")
            return ""
        res := Detect(text, dict, threshold, minSyllables)
        if (res != "")
            return {res: res, offset: offset}
        sp := InStr(text, " ")
        if (!sp)
            return ""
        offset += sp
        while (SubStr(input, offset + 1, 1) == " ")
            offset++
    }
    return ""
}
