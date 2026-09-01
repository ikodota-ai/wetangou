/**
 * 门店评分 → 视图字段
 *
 * 后台「门店管理」里手工维护 biz_store.rating（0.0~5.0，留空表示未评分）。
 * 抽成纯函数的理由和 utils/storePick.js / utils/broadcast.js 一样：
 * 首页那批「后台配了却不显示」的问题反复复发，而逻辑内联在页面里
 * 单测引用不到，只能复制一份来测 —— 复制品会把 bug 当预期行为断言。
 *
 * 两个容易写错的点：
 *   1) 判空必须用 == null / === ''，不能用 !rating ——
 *      后者会把合法的 0 分当成「未评分」（0 分和未评分是两回事）
 *   2) rating 从 JSON 过来可能是字符串 '4.8'（MyBatis decimal 映射），
 *      不能直接 toFixed，要先 Number()
 */

/**
 * @param {Number|String|null} rating 门店 rating 原值
 * @returns {{hasRating:Boolean, ratingText:String, ratingStars:Number}}
 */
function toRatingView(rating) {
  if (rating === null || rating === undefined || rating === '') {
    return { hasRating: false, ratingText: '', ratingStars: 0 }
  }
  var n = Number(rating)
  // NaN（后台存了脏数据）当成未评分，而不是显示 "NaN"
  if (!isFinite(n)) {
    return { hasRating: false, ratingText: '', ratingStars: 0 }
  }
  // 越界值夹到 0~5：后台 el-input-number 限了 0-5，但接口/存量数据可能超范围，
  // 6 分会点亮 6 颗星把布局撑坏
  if (n < 0) n = 0
  if (n > 5) n = 5
  return {
    hasRating: true,
    // 统一一位小数：4.8 → "4.8"，5 → "5.0"（避免 4.8 和 5 混排）
    ratingText: n.toFixed(1),
    // 4.8 点亮 5 颗，3.2 点亮 3 颗
    ratingStars: Math.round(n)
  }
}

module.exports = { toRatingView: toRatingView }
