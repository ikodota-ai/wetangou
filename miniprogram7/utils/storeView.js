/**
 * 门店 → 视图字段（名称 / 营业时间 / 距离 / 星级）
 *
 * 抽出来的动机：这套口径原先只内联在 pages/home/index.js 的
 * _compatStoreView 里。商品详情页也要展同一家门店的距离+星级，
 * 若在详情页再算一遍，两边让人改一次就会漂移
 * （首页显示 1.2km、详情页显示 1200m 之类）。
 *
 * 两个已踩过的坑（首页注释里已写明，这里再固定住）：
 *   1) 不能写 formatDistance(km) || ‘计算中…’—— 未授权定位时
 *      km 恒为 null、formatDistance 恒返 ‘’，于是永久停在“计算中…”。
 *      此处只给 hasDistance=false，由页面决定显示“查看距离”入口。
 *   2) 后端 s.distance 单位是米，而 formatDistance 收的是公里，必须 /1000。
 */
var util = require('./util.js')
var rating = require('./rating.js')

/**
 * @param {Object} store 后端门店对象（biz_store）
 * @param {Object|null} location {lat,lng}，通常是 app.globalData.location
 * @returns {Object} 原字段 + {name,hours,distanceText,hasDistance,distanceKm,hasRating,ratingText,ratingStars}
 */
function toStoreView(store, location) {
  if (!store) return {}
  var km = null
  if (store.distance != null && store.distance !== '') {
    // 后端字段约定单位为米（storeNearest 返回值）
    var d = Number(store.distance)
    if (isFinite(d)) km = d / 1000
  } else if (location && location.lat != null && location.lng != null
             && store.latitude != null && store.longitude != null) {
    km = util.haversineKm(location.lat, location.lng, store.latitude, store.longitude)
  }
  var text = util.formatDistance(km)
  var r = rating.toRatingView(store.rating)
  var view = {
    name: store.storeName || store.name || '',
    hours: store.businessHours || store.hours || '',
    distanceKm: km,
    distanceText: text,
    // 页面用它决定是显示“距您 x km”还是“查看距离”按钮
    hasDistance: !!text
  }
  var out = {}
  var k
  for (k in store) { if (Object.prototype.hasOwnProperty.call(store, k)) out[k] = store[k] }
  for (k in r) { if (Object.prototype.hasOwnProperty.call(r, k)) out[k] = r[k] }
  for (k in view) { if (Object.prototype.hasOwnProperty.call(view, k)) out[k] = view[k] }
  return out
}

module.exports = { toStoreView: toStoreView }
