/**
 * 组合券包（COMBO）搭配明细的解析 —— 会员端详情页与商家端预览共用。
 *
 * 单独成模块而不放在 Page 里：放 Page 方法无法单测，
 * 而这里的解析得容下历史脏 JSON（字符串/数组/非法文本三种形态），
 * 正是最需要边界测试的部分。
 */

/**
 * 解析组合券包（COMBO）的搭配明细。
 *
 * 明细存在 biz_product_ext.combo_items_json（商家端
 * pages/merchant/product/combo 就是往这里写的），ProductMapper.xml
 * 已经 left join 并以 ext.comboItemsJson 下发，只是会员端从来没读。
 *
 * 为什么不信赖 subitemType 直接展：里面存的是 GROUPON / VOUCHER
 * 这种码，直接给顾客看就是又一个枚举码外泄。文案与商家端
 * SUBITEM_TYPE_LABELS 保持一致，否则商家选的是「代金券」、顾客看到另一个词。
 *
 * JSON 解析失败不能抛：历史脏数据不应该把整个商品详情页搞成白屏。
 */
function parseComboItems(p) {
  const json = (p && p.ext && p.ext.comboItemsJson) || (p && p.comboItemsJson) || '';
  if (!json) return [];
  let arr;
  try {
    arr = typeof json === 'string' ? JSON.parse(json) : json;
  } catch (e) {
    console.error('[goods/detail] comboItemsJson 解析失败', json, e);
    return [];
  }
  if (!Array.isArray(arr)) return [];
  const TYPE_TEXT = {
    GROUPON: '团购套餐',
    VOUCHER: '代金券',
    MANJIAN: '满减券',
    ZHEKOU: '折扣券'
  };
  return arr.map((c) => {
    const qty = Number(c && c.pickQuantity) || 1;
    const price = Number(c && c.price) || 0;
    return {
      name: (c && c.name) || '',
      typeText: TYPE_TEXT[c && c.subitemType] || (c && c.subitemType) || '',
      quantity: qty,
      price: price.toFixed(2),
      // 小计：同一行买 N 份时顾客关心的是这 N 份值多少，
      // 而不是单份价 —— 商家端算总价值用的也是 pickQuantity * price。
      subtotal: (qty * price).toFixed(2)
    };
  }).filter((c) => !!c.name);
}

module.exports = { parseComboItems: parseComboItems }
