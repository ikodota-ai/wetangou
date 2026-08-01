// utils/util.js 通用方法
function formatMoney(n) {
  const v = Number(n) || 0;
  return v.toFixed(2);
}

function formatDate(d, fmt = 'YYYY-MM-DD HH:mm') {
  if (!d) return '';
  const date = (d instanceof Date) ? d : new Date(d);
  if (isNaN(date.getTime())) return String(d);
  const pad = (n) => n < 10 ? '0' + n : n;
  return fmt
    .replace('YYYY', date.getFullYear())
    .replace('MM', pad(date.getMonth() + 1))
    .replace('DD', pad(date.getDate()))
    .replace('HH', pad(date.getHours()))
    .replace('mm', pad(date.getMinutes()))
    .replace('ss', pad(date.getSeconds()));
}

function formatMonthDay(d) {
  const date = (d instanceof Date) ? d : new Date(d);
  if (isNaN(date.getTime())) return String(d);
  return (date.getMonth() + 1).toString().padStart(2, '0') + '-' + date.getDate().toString().padStart(2, '0');
}

function getNextDays(n = 7, from = new Date()) {
  const arr = [];
  const base = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  for (let i = 0; i < n; i++) {
    const d = new Date(base);
    d.setDate(base.getDate() + i);
    arr.push(d);
  }
  return arr;
}

function debounce(fn, wait = 300) {
  let t = null;
  return function (...args) {
    if (t) clearTimeout(t);
    t = setTimeout(() => fn.apply(this, args), wait);
  };
}

module.exports = {
  formatMoney,
  formatDate,
  formatMonthDay,
  getNextDays,
  debounce
};
