/**
 * 下单页的代金券挑选逻辑
 *
 * 背景：后端 placeOrder 一直支持 memberVoucherId 抵扣（校验归属、
 * 校验门槛、封顶到订单金额、支付成功后冻结券），但小程序下单页压根没有
 * 选券入口，createOrder 也没传这个参数 —— 所以「领了券不能抵扣」不是
 * 抵扣算错，是这张券从来没被带进下单请求。
 *
 * 这里只做前端筛选和试算，最终金额以后端为准（前端算的只用于展示，
 * 后端会重新校验一遍，避免改前端绕过门槛）。
 */

// 与后端保持一致：status '0' 未使用 / '1' 已使用 / '2' 已过期
var STATUS_UNUSED = '0'

function toNum(v) {
  var n = parseFloat(v)
  return isFinite(n) ? n : 0
}

/**
 * 券是否可用于这笔订单
 * @param {Object} v      biz_member_voucher 一行
 * @param {Number} amount 订单商品总价
 * @param {Number} nowTs  当前时间戳（传入便于测试）
 */
function isUsable(v, amount, nowTs) {
  if (!v || v.status !== STATUS_UNUSED) return false
  // 过期判断放前端也做一次：status 要靠定时任务刷，
  // 已过期但任务还没跑到的券 status 仍是 '0'，光看 status 会把它当可用，
  // 用户选了再被后端打回「代金券不可用」，体验很差。
  if (v.expireTime) {
    var exp = parseTime(v.expireTime)
    if (exp && exp < (nowTs || Date.now())) return false
  }
  // 门槛：订单总价必须 >= threshold。后端是 totalAmount < threshold 就报错，
  // 这里同样用总价比，不能用实付比（实付减完券再比会互相依赖）
  if (toNum(v.threshold) > toNum(amount)) return false
  return true
}

// 后端返回的时间形如 "2026-09-30 23:59:59"，iOS 上 new Date() 解析不了
// 带横杠的格式，必须换成斜杠 —— 这个坑踩过不止一次
function parseTime(s) {
  if (!s) return 0
  if (typeof s === 'number') return s
  var t = String(s).replace(/-/g, '/')
  var d = new Date(t)
  var ts = d.getTime()
  return isFinite(ts) ? ts : 0
}

/**
 * 从券列表里挑出可用的，按抵扣金额从大到小排
 */
function usableList(list, amount, nowTs) {
  var arr = Array.isArray(list) ? list : []
  var out = []
  for (var i = 0; i < arr.length; i++) {
    if (isUsable(arr[i], amount, nowTs)) out.push(arr[i])
  }
  out.sort(function (a, b) {
    var d = toNum(b.faceValue) - toNum(a.faceValue)
    // 面值相同的，先用快过期的，避免用户手里的券白白过期
    if (d !== 0) return d
    return parseTime(a.expireTime) - parseTime(b.expireTime)
  })
  return out
}

/**
 * 计算这张券实际能抵多少：不能超过订单金额（后端同样封顶）
 */
function discountOf(v, amount) {
  if (!v) return 0
  var face = toNum(v.faceValue)
  var amt = toNum(amount)
  return face > amt ? amt : face
}

/**
 * 试算实付。返回两位小数字符串，直接给界面用。
 * 不做四舍五入误差处理是因为金额都是分位，face/threshold 都是 decimal(10,2)
 */
function payAmountOf(amount, v) {
  var pay = toNum(amount) - discountOf(v, amount)
  if (pay < 0) pay = 0
  return pay.toFixed(2)
}

module.exports = {
  isUsable: isUsable,
  usableList: usableList,
  discountOf: discountOf,
  payAmountOf: payAmountOf,
  parseTime: parseTime
}
