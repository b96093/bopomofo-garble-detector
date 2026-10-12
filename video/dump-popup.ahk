#Requires AutoHotkey v2.0
; 執行產品的 BuildLayout，把聊天場景候選窗的繪圖指令輸出成 video\popup.js。
; 影片照著畫 —— 版面、文字、顏色都是產品真的會畫出來的樣子，不是目測。
;   用法（PowerShell）：
;     & "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" video\dump-popup.ahk "ji3u3ru/ 2l4x.6vu84xk7" | Out-String
; 以縮放 100%（DPIF = 1）輸出邏輯像素，影片端再統一放大。
global DPIF := 1, TRAYCOLS := 0
#Include ..\desktop\engine.ahk
#Include ..\desktop\draw.ahk

Say(s) => FileAppend(s . "`n", "*", "UTF-8-RAW")
OnError(Fatal)
Fatal(e, mode) {
    Say("ERROR: " . e.Message . " / " . e.Extra)
    ExitApp(1)
}

dict := LoadDict(A_ScriptDir . "\..\desktop\dict.txt")
hit := DetectTail(A_Args[1], dict, 0.6, 1)          ; 打字偵測路徑，靈敏度 4（預設）
if (hit == "") {
    Say("偵測不到：" . A_Args[1])
    ExitApp(1)
}
res := hit.res
; 候選窗剛開啟時的狀態：選在第一個整句候選
view := {zone: "sent", cands: res.candidates, sel: 1, draft: StrSplit(res.candidates[1]),
         draftText: res.candidates[1], ci: 1, hi: 0}
lay := BuildLayout(view, (k) => ["x"])               ; 每個中文字都有同音字可換，格子畫成可編輯

J(v) {
    if IsObject(v) {
        s := ""
        if (v is Array) {
            for x in v
                s .= (s == "" ? "" : ",") . J(x)
            return "[" . s . "]"
        }
        for k, x in v.OwnProps()
            s .= (s == "" ? "" : ",") . '"' . k . '":' . J(x)
        return "{" . s . "}"
    }
    if (v is Number)
        return v . ""
    return '"' . StrReplace(StrReplace(v, "\", "\\"), '"', '\"') . '"'
}
out := A_ScriptDir . "\popup.js"
try FileDelete(out)
FileAppend("// 由 dump-popup.ahk 從產品的 BuildLayout 產生，請勿手改`n"
         . "window.POPUP = {`"w`":" . lay.w . ",`"h`":" . lay.h . ",`"ops`":" . J(lay.ops) . "};`n",
           out, "UTF-8-RAW")
Say("popup.js：" . lay.w . "x" . lay.h . "，" . lay.ops.Length . " 個繪圖指令")
ExitApp(0)
