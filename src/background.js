// 只做一件事：第一次安裝時打開使用說明。
// 沒有這個，使用者載入擴充後畫面上不會有任何變化 ——
// 既不知道裝好了沒，也不知道該怎麼用。
chrome.runtime.onInstalled.addListener(({ reason }) => {
  if (reason === 'install') {
    chrome.tabs.create({ url: chrome.runtime.getURL('src/welcome/welcome.html') });
  }
});
