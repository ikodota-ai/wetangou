/**
 * 解析订单页的入参，判断拿到的是数据库主键还是商户订单号
 *
 * 微信支付「商品订单详情path」只能填一条，形式是
 *   pages/order/detail/index?id=${商品订单号}
 * 那个占位符由微信替换成下单时传的 out_trade_no，也就是
 * biz_order.order_no（形如 D1787398679265359）。
 *
 * 注意它塞进来的参数名就是我们自己写的 id —— 和站内跳转用的
 * ?id=999451 撞在同一个键上。所以不能按参数名分流，只能看值的形态：
 * 纯数字当主键，含字母的当订单号。
 * 按参数名分流的写法在这里是错的，会把订单号当主键去打
 * /api/order/D178... → @PathVariable Long 转换失败 500。
 */
function parseOrderParam(opts) {
  var o = opts || {}
  // 几种可能的键都收一遍：微信文档示例用 id，但也见过直接给 orderNo 的
  var raw = o.id || o.orderNo || o.order_no || o.outTradeNo || o.out_trade_no || ''
  raw = String(raw).trim()
  if (!raw) return { id: null, orderNo: '' }
  // 纯数字 → 主键。order_no 是 D/P 前缀 + 时间戳，一定含字母。
  // 用正则而非 isNaN：isNaN(' 12 ') 是 false，容易误判带空格的脏值。
  if (/^\d+$/.test(raw)) return { id: raw, orderNo: '' }
  return { id: null, orderNo: raw }
}

module.exports = { parseOrderParam: parseOrderParam }
