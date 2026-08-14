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


/**
 * 计算两点球面距离（km），用 Haversine 公式
 * 入参：lat1/lng1 起点（用户），lat2/lng2 终点（门店）
 * 入参支持数字或可转 number 的字符串；返回 km（Number），失败返回 null
 */
function haversineKm(lat1, lng1, lat2, lng2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const aLat = Number(lat1), aLng = Number(lng1);
  const bLat = Number(lat2), bLng = Number(lng2);
  if (![aLat, aLng, bLat, bLng].every((v) => Number.isFinite(v))) return null;
  if (aLat === bLat && aLng === bLng) return 0;
  const R = 6371; // 地球半径 km
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const s = Math.sin(dLat / 2) ** 2
          + Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s));
  return R * c;
}

/**
 * 把 km 距离格式化成展示文案
 *  - < 1 km：按米算（整数 + 'm'）
 *  - < 10 km：保留 1 位小数（'1.2km'）
 *  - >= 10 km：整数（'12km'）
 * 入参 null/0/undefined → 返回 ''
 */
function formatDistance(km) {
  if (km == null || !Number.isFinite(Number(km))) return '';
  const v = Number(km);
  if (v < 1) {
    return Math.max(1, Math.round(v * 1000)) + 'm';
  }
  if (v < 10) return v.toFixed(1) + 'km';
  return Math.round(v) + 'km';
}
module.exports = {
  formatMoney,
  formatDate,
  formatMonthDay,
  getNextDays,
  debounce,
  haversineKm,
  formatDistance
};
