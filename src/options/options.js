// 設定頁邏輯：讀寫 chrome.storage.sync。
const DEFAULTS = { enabled: true, mode: 'conservative' };

// 贊助連結：填入後，設定頁底部才會出現「支持開發」。
// 留空＝完全不顯示，避免發布時出現點了沒反應的死連結。
const SUPPORT_URL = '';

function $(id) { return document.getElementById(id); }

function load() {
  chrome.storage.sync.get(DEFAULTS, (s) => {
    $('enabled').checked = s.enabled;
    const radio = document.querySelector(`input[name=mode][value="${s.mode}"]`);
    if (radio) radio.checked = true;
  });
}

function save() {
  const mode = document.querySelector('input[name=mode]:checked');
  chrome.storage.sync.set({
    enabled: $('enabled').checked,
    mode: mode ? mode.value : 'conservative',
  }, () => {
    $('status').textContent = '已儲存';
    setTimeout(() => { $('status').textContent = ''; }, 1500);
  });
}

document.addEventListener('DOMContentLoaded', () => {
  load();
  if (SUPPORT_URL) {
    $('support-link').href = SUPPORT_URL;
    $('support').style.display = 'block';
  }
  $('enabled').addEventListener('change', save);
  document.querySelectorAll('input[name=mode]').forEach((el) => el.addEventListener('change', save));
});
