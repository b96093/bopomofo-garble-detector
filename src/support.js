// 聯絡頁連結：填入後，設定頁與說明頁才會出現「聯絡開發者」入口。
// 留空＝完全不顯示，避免發布時出現點了沒反應的死連結。
// （變數名沿用 SUPPORT_URL；改名要同步動桌面版，而那會觸發重新編譯與防毒複驗。）
// 桌面版的同名設定在 desktop/app.ahk 的 SUPPORT_URL。
// 指向自家頁面而非收款平台，換收款方式時只要改 docs/support.md，兩個版本都不用重發。
export const SUPPORT_URL = 'https://b96093.github.io/bopomofo-garble-detector/support';
