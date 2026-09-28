#Requires AutoHotkey v2.0
; 2026-09-28 實測：第 29 個字開始觸頂，故 SINGLE_MAX = 28。
; 改動 draw.ahk 的 LY 或寬度上限後請重跑這支。
;
; 量出候選窗在不被裁切的前提下放得下幾個中文字。
; BuildLayout 把寬度上限寫死在 DPX(700)，超過就會被裁掉 ——
; 使用者看到的是半句話，而且完全沒有提示。
;   用法（PowerShell）：
;     & "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" desktop\measure-candmax.ahk

global DPIF := 1   ; 只看邏輯像素（分子分母同乘 DPIF，觸頂的字數與 DPIF 無關)
global TRAYCOLS := 0

#Include draw.ahk

GdipInit()
OUT := "字數`t候選窗寬度`t是否觸頂`r`n"
capped := 0
Loop 50 {
    n := A_Index
    s := ""
    Loop n
        s .= "字"
    view := {cands: [s], sel: 1, ci: 1, zone: "sent", draft: StrSplit(s), draftText: s}
    lay := BuildLayout(view, (*) => [])
    hit := (lay.w >= DPX(700) + DPX(LY.pad) * 2)
    if (hit && capped == 0)
        capped := n
    OUT .= n . "`t" . lay.w . "`t" . (hit ? "是" : "否") . "`r`n"
}
OUT .= "`r`n第一個觸頂的字數：" . capped . "`r`n"
OUT .= "建議 SINGLE_MAX = " . (capped - 1) . "`r`n"
p := A_Temp . "/candmax.txt"
try FileDelete(p)
FileAppend(OUT, p, "UTF-8")
ExitApp()
