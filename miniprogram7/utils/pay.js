/**
 * 拉起微信支付（订单续付）
 *
 * 抽出来是因为订单列表和订单详情都要用。之前只有列表页有这段逻辑，
 * 详情页压根没有支付入口 —— 所以列表才不得不拦截「待支付」的点击、
 * 直接拉支付，导致这类订单进不去详情页。
 *
 * 微信支付商户平台要配「订单页面路径」（用于支付完成后跳回订单查看），
 * 那个路径必须真能打开对应订单，所以详情页必须可达，不能被列表拦掉。
 */
const { api } = require('./request.js')

/**
 * @param {String|Number} orderId
 * @param {Function} onPaid 支付成功后的回调（一般用来刷新页面数据）
 * @param {Object} [deps]   仅供单测注入 api，业务代码不要传
 */
function payOrder(orderId, onPaid, deps) {
  if (!orderId) return
  var _api = (deps && deps.api) || api
  wx.showLoading({ title: '发起支付', mask: true })
  _api.prepayOrder(orderId).then((res) => {
    wx.hideLoading()
    // mock 模式（未配支付凭证时后端返 mock:true）直接当成功，方便开发联调
    if (res && res.mock) {
      wx.showToast({ title: '支付成功', icon: 'success' })
      onPaid && onPaid()
      return
    }
    const p = (res && (res.data || res)) || {}
    if (!p.paySign) {
      wx.showToast({ title: '暂不可支付，请稍后重试', icon: 'none' })
      return
    }
    wx.requestPayment({
      timeStamp: String(p.timeStamp),
      nonceStr: p.nonceStr,
      package: p.package,
      signType: p.signType || 'RSA',
      paySign: p.paySign,
      success: () => {
        wx.showToast({ title: '支付成功', icon: 'success' })
        onPaid && onPaid()
      },
      // 用户主动取消和签名失败在这里是同一个回调，
      // 文案只说「已取消」，真出错时看控制台
      fail: (err) => {
        console.warn('[pay] requestPayment fail', err)
        wx.showToast({ title: '已取消支付', icon: 'none' })
      }
    })
  }).catch((err) => {
    wx.hideLoading()
    wx.showToast({ title: (err && err.msg) || '支付失败', icon: 'none' })
  })
}

module.exports = { payOrder: payOrder }
