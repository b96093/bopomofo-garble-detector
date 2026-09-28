#Requires AutoHotkey v2.0
; 量出 DetectBlock 在多長的段落開始有感延遲，用來訂 BLOCK_MAX。
;
; 2026-09-28 實測（兩次，同一台機器）：
;   行數  字元數  耗時(ms)
;      1      37    0 /  0
;      2      75    0 / 15
;      5     189   16 /  0
;     10     379    0 /  0
;     20     759    0 /  0
;     40    1519   15 / 16
;     80    3039   32 / 31
;    160    6079   78 / 63
; 到 160 行（6079 字元）仍然只要 60～80ms，完全沒有接近 300ms 的可接受上限
;（線性外推要到兩萬多字元才會超過）。也就是說 DetectBlock 不是瓶頸，
; BLOCK_MAX 不必為效能而訂。仍然保留 4000 字元，理由是保護而非效能：
; 那是「轉這一段筆記」的合理上界，可以擋住誤按 Ctrl+A 選到整份文件之後
; 被整份覆蓋掉的情況（整段路徑按 Enter 就直接替換，不開候選窗）。
;
;   用法（PowerShell）：
;     & "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" desktop\measure-blockmax.ahk
#Include engine.ahk

DICT := LoadDict(A_ScriptDir . "\dict.txt")
LINE := "au/6wu0 yl3g;392u03d9 cjo31j4ul t62l4"     ; 37 字元／一行

OUT := "行數`t字元數`t耗時(ms)`r`n"
for n in [1, 2, 5, 10, 20, 40, 80, 160] {
    block := ""
    Loop n
        block .= (A_Index > 1 ? "`n" : "") . LINE
    t := A_TickCount
    DetectBlock(block, DICT)
    OUT .= n . "`t" . StrLen(block) . "`t" . (A_TickCount - t) . "`r`n"
}
p := A_Temp . "/blockmax.txt"
try FileDelete(p)
FileAppend(OUT, p, "UTF-8")
ExitApp()
