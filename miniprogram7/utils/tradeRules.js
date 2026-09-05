/**
 * 交易规则的文案口径（会员端详情页 + 商家端预览 共用）。
 *
 * 为什么抽出来：这几个字段 PC 建品页都能填、库里也真有值
 * （本地 biz_product.mutex_with_store_promotion 390 条全为 1，
 *  collect_method 全为 HEAD），但会员端详情页一个都没露出过。
 * “不与店内优惠同享”是最容易到店吵架的一条：顾客以为可以叠，
 * 收银台说不行，而商家其实已经在后台勾选过了。
 *
 * 放在 utils 而不是写在页面里：一是这些翻译表必须跟 PC
 * views/biz/product/create.vue 的选项文案逐字对齐，得能被单测锁住；
 * 二是商家端预览走的是同一张详情页，口径只能有一份。
 */

// 每日可用时段。库里存 HH:mm:ss，顾客只关心到分钟。
function hhmm(t) {
  if (!t) return '';
  const m = String(t).match(/^(\d{1,2}):(\d{2})/);
  return m ? (m[1].length === 1 ? '0' + m[1] : m[1]) + ':' + m[2] : String(t);
}

function dailyTimeText(ext) {
  const e = ext || {};
  const a = hhmm(e.dailyTimeStart), b = hhmm(e.dailyTimeEnd);
  if (a && b) return a + ' 至 ' + b;
  if (a) return a + ' 起可用';
  if (b) return b + ' 前可用';
  return '';
}

// 不可消费日期。ext.exclude_dates 存的是 [["2026-01-01","2026-01-03"], ...]，
// PC 表单目前只用第一段，但详情页得把存进去的全部段列出来，
// 否则商家往里存了三段顾客只看到一段，跟没写一样危险。
function excludeDatesText(ext) {
  const raw = (ext || {}).excludeDates;
  if (!raw) return '';
  let arr;
  try { arr = JSON.parse(raw); } catch (e) { return ''; }
  if (!Array.isArray(arr)) return '';
  const segs = [];
  arr.forEach((seg) => {
    if (Array.isArray(seg)) {
      const a = seg[0] || '', b = seg[1] || '';
      if (a && b) segs.push(a === b ? a : a + '～' + b);
      else if (a) segs.push(a);
    } else if (seg) {
      segs.push(String(seg));
    }
  });
  return segs.join('、');
}

// 代金券适用规则（逗号分隔的码值）。
// 翻译表必须跟 PC create.vue 的 checkbox 文案一致，否则两边各叫一个名字。
const VOUCHER_RULE_TEXT = {
  ALL_CATEGORY: '全部品类适用',
  ALL_BRAND: '全部品牌适用'
};

function voucherRulesText(ext) {
  const raw = (ext || {}).voucherRules;
  if (!raw) return '';
  return String(raw).split(',')
    .map((c) => c.trim()).filter((c) => !!c)
    .map((c) => VOUCHER_RULE_TEXT[c] || c)
    .join('、');
}

// 收款方式。注意 biz_product.collect_method 的 comment 历史上写错过
// （把券码类型的语义写进了 PLATFORM），取值以 HEAD/STORE 为准；
// 券码类型看 ext.code_type。
function collectMethodText(v) {
  if (!v) return '';
  return v === 'STORE' ? '门店独立收款' : v === 'HEAD' ? '总部统一收款' : '';
}

// 券码类型。顾客关心的是“到店找谁核”，而不是枚举名。
function codeTypeText(ext) {
  const v = (ext || {}).codeType;
  if (!v) return '';
  return v === 'PLATFORM' ? '平台券（平台统一发码）'
       : v === 'MERCHANT' ? '商家券（门店自行核销）' : '';
}

// 与店内优惠是否互斥。库里是 0/1，但可能以字符串 '0'/'1' 下发，
// 而 null / undefined 意为“商家没填”，此时一个字也不能编。
function mutexText(v) {
  if (v === null || v === undefined || v === '') return '';
  const n = Number(v);
  if (n === 1) return '不与店内优惠同享';
  if (n === 0) return '可与店内优惠同享';
  return '';
}

// 富文本“是不是真的有字”。富文本编辑器清空后不是空串，而是留下
// <p><br></p> / &nbsp; 这类底湣；直接拿它当真会让详情页多出一张只有标题的空卡。
// 注意 <img> 也算“有内容”：图文详情很常见是纯长图、一个字也没。
function hasRichContent(html) {
  if (!html) return false;
  const s = String(html);
  if (/<(img|video|table)\b/i.test(s)) return true;
  const text = s.replace(/<[^>]*>/g, '').replace(/&nbsp;/gi, '').replace(/\s/g, '');
  return !!text;
}

// 券类型 / 适用范围（ext.voucher_scope_type）。
//
// 这一列在 PC 建品页是两个不同控件共用的（create.vue:949）：
//   代金券（VOUCHER）→ form.scopeType，选项 ALL/CATEGORY/STORE，标题「适用范围」
//   其他类型     → form.voucherType，选项 GENERAL/CATEGORY，标题「券类型」
// 两边共一列但不会同屏出现，所以翻译必须拿 typeCode 分流 ——
// 否则 CATEGORY 这个值两边都有，会把「单品类券」误写成「按品类」。
//
// 为什么要露出：“全场通用”还是“只能买指定品类”直接决定顾客到店能不能用这张券，
// 商家在后台选了、库里也存了，但详情页一直没读。
const VOUCHER_SCOPE_TEXT = {
  ALL: '全场通用',
  CATEGORY: '按品类适用',
  STORE: '按门店适用'
};
const VOUCHER_TYPE_TEXT = {
  GENERAL: '通兑券',
  CATEGORY: '单品类券'
};
function voucherScopeText(ext, typeCode) {
  const v = (ext || {}).voucherScopeType;
  if (!v) return { label: '', text: '' };
  if (typeCode === 'VOUCHER') {
    return { label: '适用范围', text: VOUCHER_SCOPE_TEXT[v] || '' };
  }
  return { label: '券类型', text: VOUCHER_TYPE_TEXT[v] || '' };
}

// 「适用门店 N 家」的 N。
//
// 优先用真实列出的门店行数，而不是 store_ids 里的 id 个数：
// 后端组 applicableStores 时会跳过已删除 / 查不到的门店，两个数不一定相等。
// 表头写着「3家」而下面只列出 2 行时，顾客会以为页面没加载完、
// 还有一家没显出来，于是一直等 —— 这比直接少写一家更让人困惑。
// 拿不到列表时才回落到 store_ids 的个数（卡片那时走兜底分支，只画主门店）。
function storeCountLabel(stores, product) {
  const n = (stores && stores.length) ? stores.length
    : ((product && product.storeCount) || 0);
  return n ? n + '家' : '';
}

module.exports = {
  hhmm: hhmm,
  dailyTimeText: dailyTimeText,
  excludeDatesText: excludeDatesText,
  voucherRulesText: voucherRulesText,
  collectMethodText: collectMethodText,
  codeTypeText: codeTypeText,
  mutexText: mutexText,
  hasRichContent: hasRichContent,
  storeCountLabel: storeCountLabel,
  voucherScopeText: voucherScopeText,
  VOUCHER_SCOPE_TEXT: VOUCHER_SCOPE_TEXT,
  VOUCHER_TYPE_TEXT: VOUCHER_TYPE_TEXT,
  VOUCHER_RULE_TEXT: VOUCHER_RULE_TEXT
};
