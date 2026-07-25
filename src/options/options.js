// 設定頁邏輯：讀寫 chrome.storage.sync。
const DEFAULTS = { enabled: true, mode: 'conservative' };

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
  $('enabled').addEventListener('change', save);
  document.querySelectorAll('input[name=mode]').forEach((el) => el.addEventListener('change', save));
});
